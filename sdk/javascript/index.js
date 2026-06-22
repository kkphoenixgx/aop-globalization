const net = require('net');
const EventEmitter = require('events');

const child_process = require('child_process');
const path = require('path');
const fs = require('fs');

function findEngineBinary(binName) {
    const platformPkg = `panteao-engine-${process.platform}-${process.arch}`;
    const searchRoots = [
        process.cwd(),
        path.resolve(process.cwd(), 'node_modules'),
        __dirname,
        path.resolve(__dirname, '..'),
        path.resolve(__dirname, '..', '..')
    ];

    const candidates = [];
    for (const root of searchRoots) {
        candidates.push(
            path.join(root, 'node_modules', platformPkg, 'bin', binName),
            path.join(root, 'node_modules', platformPkg, binName),
            path.join(root, platformPkg, 'bin', binName),
            path.join(root, platformPkg, binName),
            path.join(root, 'bin', binName),
            path.join(root, binName)
        );
    }

    for (const candidate of candidates) {
        if (fs.existsSync(candidate)) {
            return candidate;
        }
    }

    try {
        const pkgPath = require.resolve(path.join(platformPkg, 'package.json'));
        const pkgDir = path.dirname(pkgPath);
        for (const candidate of [
            path.join(pkgDir, 'bin', binName),
            path.join(pkgDir, binName)
        ]) {
            if (fs.existsSync(candidate)) {
                return candidate;
            }
        }
    } catch (e) {}

    return null;
}

class Panteao extends EventEmitter {
    constructor(options = {}) {
        super();
        this.host = options.host || '127.0.0.1';
        this.port = options.port || 0; 
        this.project = options.project || null;
        
        const binName = process.platform === 'win32' ? 'panteao-engine.exe' : 'panteao-engine';
        this.binPath = findEngineBinary(binName) || path.join(process.cwd(), 'node_modules', '.bin', binName);
        
        this.autoReconnect = options.autoReconnect ?? (this.project ? false : true);
        this.reconnectInterval = options.reconnectInterval || 2000;
        this.socket = new net.Socket();
        this.buffer = '';
        this.actionHandlers = new Map();
        this.child = null;
        this.setupSocketEvents();
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

    async connect() {
        if (this.project) {
            if (this.port === 0) {
                this.port = await this._getFreePort();
            }
            
            // Spawn the GraalVM native engine
            const spawnArgs = [this.project, '--port', String(this.port)];
            this.child = child_process.spawn(this.binPath, spawnArgs, {
                stdio: ['ignore', 'inherit', 'inherit']
            });

            this.child.on('error', (err) => {
                this.emit('error', new Error(`Failed to start GraalVM engine process: ${err.message}`));
            });

            // Wait brief moment for the engine to initialize its socket server
            await new Promise(resolve => setTimeout(resolve, 800));
        } else if (this.port === 0) {
            this.port = 44444; // Default port if connecting only
        }

        return new Promise((resolve, reject) => {
            const onReady = () => {
                cleanup();
                resolve();
            };
            const onError = (err) => {
                cleanup();
                reject(err);
            };
            const onClose = () => {
                cleanup();
                reject(new Error("Socket closed during handshake"));
            };
            const cleanup = () => {
                this.off('ready', onReady);
                this.socket.off('error', onError);
                this.socket.off('close', onClose);
            };
            this.once('ready', onReady);
            this.socket.once('error', onError);
            this.socket.once('close', onClose);

            this.socket.connect(this.port, this.host, () => {
                this.emit('connect');
            });
        });
    }

    setupSocketEvents() {
        this.socket.on('data', (data) => {
            this.buffer += data.toString('utf8');
            const lines = this.buffer.split('\n');
            this.buffer = lines.pop() || '';
            for (const line of lines) {
                if (line.trim().length === 0) continue;
                this.handleIncomingLine(line);
            }
        });

        this.socket.on('close', () => {
            this.emit('disconnect');
            if (this.autoReconnect) {
                setTimeout(() => {
                    this.connect().catch(() => {});
                }, this.reconnectInterval);
            }
        });

        this.socket.on('error', (err) => {
            this.emit('error', err);
        });
    }

    handleIncomingLine(line) {
        try {
            const msg = JSON.parse(line);
            if (msg.type === 'mas_ready') {
                this.emit('ready');
            } else if (msg.type === 'action') {
                const rawAction = msg.action;
                const { name, args } = this.parseAction(rawAction);
                const handler = this.actionHandlers.get(name);
                if (handler) {
                    const respond = (success) => {
                        this.sendActionResult(msg.id, success);
                    };
                    handler(args, respond);
                } else {
                    this.sendActionResult(msg.id, true);
                }
                this.emit('action', { name, args, agent: msg.agent, id: msg.id });
            } else if (msg.type === 'message') {
                const { performative, sender, receiver, content } = msg;
                this.emit('message', performative, sender, receiver, content);
                this.emit(performative, sender, receiver, content);

                // Compatibility: parse message content as an action
                if (content && typeof content === 'string') {
                    const parsed = this.parseAction(content);
                    if (parsed && parsed.name) {
                        const handler = this.actionHandlers.get(parsed.name);
                        if (handler) {
                            const dummyRespond = () => {};
                            handler(parsed.args, dummyRespond);
                        }
                        this.emit('action', { name: parsed.name, args: parsed.args, agent: sender, id: null });
                    }
                }
            }
        } catch (e) {
            this.emit('error', e);
        }
    }

    parseAction(actionStr) {
        const parenIdx = actionStr.indexOf('(');
        if (parenIdx === -1) {
            return { name: actionStr.trim(), args: [] };
        }
        const name = actionStr.substring(0, parenIdx).trim();
        const argsStr = actionStr.substring(parenIdx + 1, actionStr.lastIndexOf(')'));
        const args = [];
        let current = '';
        let insideQuotes = false;
        let depthBrackets = 0;
        let depthParens = 0;
        for (let i = 0; i < argsStr.length; i++) {
            const char = argsStr[i];
            if (char === '"') {
                insideQuotes = !insideQuotes;
                current += char;
            } else if (!insideQuotes && char === '[') {
                depthBrackets++;
                current += char;
            } else if (!insideQuotes && char === ']') {
                depthBrackets--;
                current += char;
            } else if (!insideQuotes && char === '(') {
                depthParens++;
                current += char;
            } else if (!insideQuotes && char === ')') {
                depthParens--;
                current += char;
            } else if (char === ',' && !insideQuotes && depthBrackets === 0 && depthParens === 0) {
                args.push(this.cleanArg(current));
                current = '';
            } else {
                current += char;
            }
        }
        if (current.trim().length > 0) {
            args.push(this.cleanArg(current));
        }
        return { name, args };
    }

    cleanArg(arg) {
        const s = arg.trim();
        if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
            return s.substring(1, s.length - 1);
        }
        return s;
    }


    registerAction(actionName, callback) {
        this.actionHandlers.set(actionName, callback);
    }

    sendActionResult(id, success) {
        const payload = JSON.stringify({ type: 'action_result', id, success }) + '\n';
        this.socket.write(payload);
    }

    send(json) {
        this.socket.write(JSON.stringify(json) + '\n');
    }

    sendMsg(performative, sender, receiver, content) {
        this.send({
            type: 'message',
            performative: performative,
            sender: sender,
            receiver: receiver,
            content: content
        });
    }

    close() {
        this.autoReconnect = false;
        this.socket.destroy();
        if (this.child) {
            this.child.kill('SIGTERM');
        }
    }
}

const BdiClient = Panteao;
const Panteão = Panteao;
module.exports = { Panteao, BdiClient, Panteão };

