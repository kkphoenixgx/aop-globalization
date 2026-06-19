const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const net = require('net');
const EventEmitter = require('events');

class Panteao extends EventEmitter {
    constructor(options = {}) {
        super();
        this.project = options.project;
        // Default port to 0 (dynamic allocation) if not specified
        this.port = options.port || 0; 
        this.actionTimeout = options.actionTimeout || 5000;
        this.autoRestart = options.autoRestart !== undefined ? options.autoRestart : false;
        
        this.child = null;
        this.socket = null;
        this.connected = false;
        this.buffer = '';
        this.manuallyStopped = false;

        // Determine temporary MAS2J path to clean up
        this.tempMas2jPath = null;
        if (this.project && this.project.endsWith('.jcm')) {
            const parsedPath = path.resolve(this.project);
            const dir = path.dirname(parsedPath);
            const ext = path.extname(parsedPath);
            const base = path.basename(parsedPath, ext);
            this.tempMas2jPath = path.join(dir, `.${base}.mas2j`);
        }

        // Register process exit listener for cleanup
        this._cleanupListener = () => this.cleanup();
        process.on('exit', this._cleanupListener);
        process.on('SIGINT', this._cleanupListener);
        process.on('SIGTERM', this._cleanupListener);
    }

    _getFreePort() {
        return new Promise((resolve, reject) => {
            const srv = net.createServer();
            srv.listen(0, () => {
                const port = srv.address().port;
                srv.close((err) => {
                    if (err) reject(err);
                    else resolve(port);
                });
            });
            srv.on('error', reject);
        });
    }

    async start() {
        this.manuallyStopped = false;
        
        if (!this.project) {
            throw new Error("Project JCM or MAS2J path must be specified.");
        }

        if (this.port === 0) {
            this.port = await this._getFreePort();
            console.log(`[Panteão] Allocated dynamic port: ${this.port}`);
        }

        const nativePathLinux = path.join(__dirname, 'bin/panteao-engine');
        const nativePathWin = path.join(__dirname, 'bin/panteao-engine.exe');
        const nativePath = fs.existsSync(nativePathWin) ? nativePathWin : nativePathLinux;

        const jarPath = path.join(__dirname, 'build/libs/jason-ipc-all.jar');

        let spawnCmd;
        let spawnArgs = [];

        if (fs.existsSync(nativePath)) {
            spawnCmd = nativePath;
            spawnArgs = [this.project, '--port', String(this.port)];
        } else if (fs.existsSync(jarPath)) {
            spawnCmd = 'java';
            spawnArgs = ['-jar', jarPath, this.project, '--port', String(this.port)];
        } else {
            throw new Error("Neither native engine executable nor JAR found. Please compile the project first.");
        }

        // Run the engine
        this.child = spawn(spawnCmd, spawnArgs, {
            stdio: ['ignore', 'inherit', 'inherit'] // Let stdout/stderr inherit to show agent logs
        });

        this.child.on('close', (code) => {
            this.connected = false;
            this.emit('close', code);
            
            if (!this.manuallyStopped && this.autoRestart && code !== 0) {
                console.warn(`[Panteão] Engine crashed with code ${code}. Restarting in 2 seconds...`);
                setTimeout(() => this.start(), 2000);
            } else {
                this.cleanup();
            }
        });

        // Connect to the TCP socket
        setTimeout(() => {
            this.connect();
        }, 1000);
    }

    connect() {
        this.socket = new net.Socket();

        this.socket.connect(this.port, '127.0.0.1', () => {
            this.connected = true;
            this.emit('connect');
        });

        const MAX_BUFFER_SIZE = 10 * 1024 * 1024; // 10MB protection

        this.socket.on('data', (data) => {
            this.buffer += data.toString();
            
            // Overflow protection
            if (this.buffer.length > MAX_BUFFER_SIZE) {
                this.emit('error', new Error('Socket buffer overflow. Dropping connection.'));
                this.socket.destroy();
                this.buffer = '';
                return;
            }

            let boundary = this.buffer.indexOf('\n');
            while (boundary !== -1) {
                const line = this.buffer.substring(0, boundary).trim();
                this.buffer = this.buffer.substring(boundary + 1);
                if (line) {
                    this.handleMessage(line);
                }
                boundary = this.buffer.indexOf('\n');
            }
        });

        this.socket.on('error', (err) => {
            this.emit('error', err);
            // Try to reconnect if not manually stopped
            if (!this.manuallyStopped && this.autoRestart) {
                setTimeout(() => {
                    if (!this.connected && !this.manuallyStopped) {
                        this.connect();
                    }
                }, 1000);
            }
        });

        this.socket.on('close', () => {
            this.connected = false;
            this.emit('disconnect');
        });
    }

    handleMessage(line) {
        try {
            const msg = JSON.parse(line);
            if (msg.type === 'action') {
                const { id, agent, action } = msg;
                
                let responded = false;
                
                // Anti-coma: Action timeout
                const timeoutId = setTimeout(() => {
                    if (!responded) {
                        responded = true;
                        this.send({
                            type: 'action_result',
                            id: id,
                            success: false,
                            error: 'action_timeout'
                        });
                        console.warn(`[Panteão] Action timeout: Agent '${agent}' action '${action}' took too long.`);
                    }
                }, this.actionTimeout);

                this.emit('action', agent, action, (success) => {
                    if (!responded) {
                        responded = true;
                        clearTimeout(timeoutId);
                        this.send({
                            type: 'action_result',
                            id: id,
                            success: success
                        });
                    }
                });
            }
        } catch (e) {
            this.emit('error', new Error(`Failed to parse message: ${e.message}`));
        }
    }

    send(json) {
        if (this.socket && this.connected) {
            this.socket.write(JSON.stringify(json) + '\n');
        } else {
            console.warn(`[Panteão] Cannot send message, socket not connected: ${JSON.stringify(json)}`);
        }
    }

    addPercept(perception) {
        this.send({
            type: 'perception',
            action: 'add',
            perception: perception
        });
    }

    removePercept(perception) {
        this.send({
            type: 'perception',
            action: 'remove',
            perception: perception
        });
    }

    cleanup() {
        if (this.tempMas2jPath && fs.existsSync(this.tempMas2jPath)) {
            try {
                fs.unlinkSync(this.tempMas2jPath);
            } catch (e) {
                // ignore
            }
        }
    }

    stop() {
        this.manuallyStopped = true;
        
        // Remove process listeners to avoid memory leaks
        process.off('exit', this._cleanupListener);
        process.off('SIGINT', this._cleanupListener);
        process.off('SIGTERM', this._cleanupListener);

        if (this.socket) {
            this.socket.destroy();
        }
        if (this.child) {
            this.child.kill('SIGTERM');
        }
        this.cleanup();
    }
}

module.exports = { Panteao };
