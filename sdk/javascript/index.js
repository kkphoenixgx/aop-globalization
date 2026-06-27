const net = require('net');
const EventEmitter = require('events');
const child_process = require('child_process');
const path = require('path');
const fs = require('fs');
const { createRequire } = require('module');

function findEngineBinary(binName) {
    const platformPkg = `panteao-engine-${process.platform}-${process.arch}`;
    const requireFromProject = createRequire(process.cwd() + '/package.json');

    const searchRoots = [
        process.cwd(),
        path.resolve(process.cwd(), 'node_modules'),
        path.resolve(process.cwd(), '..'),
        path.resolve(process.cwd(), '..', '..'),
        path.resolve(process.cwd(), '..', '..', '..')
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

    const envPath =
        process.env.PANTEAO_ENGINE_PATH ||
        process.env.PANTEAO_ENGINE_BIN;

    if (envPath) {
        candidates.push(envPath);
    }

    for (const candidate of candidates) {
        if (fs.existsSync(candidate)) {
            return candidate;
        }
    }

    try {
        const pkgPath = requireFromProject.resolve(
            path.join(platformPkg, 'package.json')
        );

        const pkgDir = path.dirname(pkgPath);

        for (const candidate of [
            path.join(pkgDir, 'bin', binName),
            path.join(pkgDir, binName)
        ]) {
            if (fs.existsSync(candidate)) {
                return candidate;
            }
        }
    } catch (_) {}

    return null;
}

function getFreePort() {
    return new Promise((resolve, reject) => {
        const server = net.createServer();

        server.listen(0, '127.0.0.1', () => {
            const address = server.address();
            const port = typeof address === 'string'
                ? 0
                : address?.port;

            server.close(() => {
                if (port) resolve(port);
                else reject(new Error('Failed to allocate port'));
            });
        });

        server.on('error', reject);
    });
}

/**
 * Panteao BDI Engine Client
 * @class BdiClient
 * @extends EventEmitter
 */
class BdiClient extends EventEmitter {
    /**
     * Creates a new Panteao BDI client instance.
     * @param {Object} [options] Configuration options for the client
     * @param {string} [options.host='127.0.0.1'] Host address to connect to
     * @param {number} [options.port=0] Port to connect to. If 0 and project is provided, it will allocate a free port
     * @param {string} [options.project] Path to the JaCaMo project file (.jcm). If provided, it will spawn the engine locally
     * @param {boolean} [options.autoReconnect] Whether to automatically reconnect on disconnect (defaults to true if project is not provided)
     * @param {number} [options.reconnectInterval=2000] Delay in milliseconds before attempting to reconnect
     * @param {string} [options.binPath] Explicit path to the panteao-engine binary executable
     */
    constructor(options = {}) {
        super();

        this.host = options.host || '127.0.0.1';
        this.port = options.port || 0;
        this.project = options.project;

        this.autoReconnect =
            options.project
                ? false
                : (options.autoReconnect ?? true);

        this.reconnectInterval =
            options.reconnectInterval || 2000;

        this.buffer = '';
        this.actionHandlers = new Map();
        this.process = null;
        this.socket = new net.Socket();

        let binPath = options.binPath;

        if (!binPath) {
            const isWin = process.platform === 'win32';
            const binName = isWin
                ? 'panteao-engine.exe'
                : 'panteao-engine';

            const resolvedPath =
                findEngineBinary(binName);

            if (resolvedPath) {
                binPath = resolvedPath;
            } else {
                binPath = path.join(
                    process.cwd(),
                    'node_modules',
                    '.bin',
                    binName
                );

                if (!fs.existsSync(binPath)) {
                    binPath = binName;
                }
            }
        }

        this.binPath = binPath;
    }

    /**
     * Connects to the BDI engine via TCP socket. If a project was specified in options, 
     * it will spawn the native engine process in the background first.
     * @returns {Promise<void>} Resolves when connection and handshake are successfully established
     * @throws {Error} If the binary is not found or connection fails
     */
    async connect() {
        if (this.project) {
            if (this.port === 0) {
                this.port = await getFreePort();
            }

            if (!fs.existsSync(this.binPath)) {
                const errMsg =
                    `[Panteão] Engine binary not found at resolved path: ${this.binPath}. ` +
                    `Ensure the correct architecture package ` +
                    `(panteao-engine-${process.platform}-${process.arch}) ` +
                    `is installed or provide a valid absolute path via 'binPath'.`;

                this.emit('error', new Error(errMsg));
                throw new Error(errMsg);
            }

            if (process.platform !== 'win32') {
                try {
                    fs.accessSync(
                        this.binPath,
                        fs.constants.X_OK
                    );
                } catch (_) {
                    fs.chmodSync(this.binPath, 0o755);
                }
            }

            const args = [
                this.project,
                '--port',
                String(this.port)
            ];

            this.process = child_process.spawn(
                this.binPath,
                args,
                {
                    stdio: ['ignore', 'pipe', 'pipe']
                }
            );

            this.process.stdout?.on(
                'data',
                data => {
                    console.log(
                        '\x1b[36m[MAS]\x1b[0m',
                        data.toString().trim()
                    );
                }
            );

            this.process.stderr?.on(
                'data',
                data => {
                    console.log(
                        '\x1b[36m[MAS]\x1b[0m',
                        data.toString().trim()
                    );
                }
            );

            await new Promise(resolve =>
                setTimeout(resolve, 800)
            );
        } else if (this.port === 0) {
            this.port = 44444;
        }

        return new Promise((resolve, reject) => {
            let handshakeBuffer = '';

            const onConnect = () => {
                const onData = data => {
                    handshakeBuffer +=
                        data.toString('utf8');

                    const lines =
                        handshakeBuffer.split('\n');

                    handshakeBuffer =
                        lines.pop() || '';

                    for (const line of lines) {
                        try {
                            if (!line.trim()) continue;

                            const msg =
                                JSON.parse(line);

                            if (
                                msg.type ===
                                'mas_ready'
                            ) {
                                this.socket.off(
                                    'data',
                                    onData
                                );

                                this.socket.off(
                                    'error',
                                    onError
                                );

                                this.setupSocketEvents();

                                this.emit(
                                    'connect'
                                );

                                resolve();
                                return;
                            }
                        } catch (_) {}
                    }
                };

                const onError = err => {
                    this.socket.off(
                        'data',
                        onData
                    );

                    if (this.process) {
                        this.process.kill();
                        this.process = null;
                    }

                    reject(err);
                };

                this.socket.on(
                    'data',
                    onData
                );

                this.socket.once(
                    'error',
                    onError
                );
            };

            const onInitialError = err => {
                if (this.process) {
                    this.process.kill();
                    this.process = null;
                }

                reject(err);
            };

            this.socket.once(
                'error',
                onInitialError
            );

            this.socket.connect(
                this.port,
                this.host,
                () => {
                    this.socket.off(
                        'error',
                        onInitialError
                    );

                    onConnect();
                }
            );
        });
    }

    setupSocketEvents() {
        this.socket.on('data', data => {
            this.buffer +=
                data.toString('utf8');

            const lines =
                this.buffer.split('\n');

            this.buffer =
                lines.pop() || '';

            for (const line of lines) {
                if (!line.trim()) continue;
                this.handleIncomingLine(line);
            }
        });

        this.socket.on('close', () => {
            this.emit('disconnect');

            if (this.autoReconnect) {
                setTimeout(() => {
                    this.connect()
                        .catch(() => {});
                }, this.reconnectInterval);
            }
        });

        this.socket.on(
            'error',
            err => this.emit('error', err)
        );
    }

    handleIncomingLine(line) {
        try {
            const msg = JSON.parse(line);

            if (msg.type === 'action') {
                const rawAction =
                    msg.action;

                const {
                    name,
                    args
                } = this.parseAction(
                    rawAction
                );

                const handler =
                    this.actionHandlers.get(
                        name
                    );

                if (handler) {
                    const respond =
                        success =>
                            this.sendActionResult(
                                msg.id,
                                success
                            );

                    handler(
                        args,
                        respond
                    );
                } else {
                    this.sendActionResult(
                        msg.id,
                        true
                    );
                }

                this.emit(
                    'action',
                    {
                        name,
                        args,
                        agent: msg.agent,
                        id: msg.id
                    }
                );
            }

            else if (
                msg.type ===
                'message'
            ) {
                const {
                    performative,
                    sender,
                    receiver,
                    content
                } = msg;

                this.emit(
                    'message',
                    performative,
                    sender,
                    receiver,
                    content
                );

                this.emit(
                    performative,
                    sender,
                    receiver,
                    content
                );

                if (
                    content &&
                    typeof content ===
                    'string'
                ) {
                    const parsed =
                        this.parseAction(
                            content
                        );

                    const handler =
                        this.actionHandlers.get(
                            parsed.name
                        );

                    if (handler) {
                        handler(
                            parsed.args,
                            () => {}
                        );
                    }

                    this.emit(
                        'action',
                        {
                            name:
                                parsed.name,
                            args:
                                parsed.args,
                            agent:
                                sender,
                            id: null
                        }
                    );
                }
            }
        } catch (err) {
            this.emit('error', err);
        }
    }

    parseAction(actionStr) {
        const parenIdx =
            actionStr.indexOf('(');

        if (parenIdx === -1) {
            return {
                name:
                    actionStr.trim(),
                args: []
            };
        }

        const name =
            actionStr
                .substring(
                    0,
                    parenIdx
                )
                .trim();

        const argsStr =
            actionStr.substring(
                parenIdx + 1,
                actionStr.lastIndexOf(
                    ')'
                )
            );

        const args = [];

        let current = '';
        let insideQuotes = false;
        let depthBrackets = 0;
        let depthParens = 0;

        for (
            let i = 0;
            i < argsStr.length;
            i++
        ) {
            const char =
                argsStr[i];

            if (char === '"') {
                insideQuotes =
                    !insideQuotes;
                current += char;
            }

            else if (
                !insideQuotes &&
                char === '['
            ) {
                depthBrackets++;
                current += char;
            }

            else if (
                !insideQuotes &&
                char === ']'
            ) {
                depthBrackets--;
                current += char;
            }

            else if (
                !insideQuotes &&
                char === '('
            ) {
                depthParens++;
                current += char;
            }

            else if (
                !insideQuotes &&
                char === ')'
            ) {
                depthParens--;
                current += char;
            }

            else if (
                char === ',' &&
                !insideQuotes &&
                depthBrackets === 0 &&
                depthParens === 0
            ) {
                args.push(
                    this.cleanArg(
                        current
                    )
                );

                current = '';
            }

            else {
                current += char;
            }
        }

        if (current.trim()) {
            args.push(
                this.cleanArg(
                    current
                )
            );
        }

        return { name, args };
    }

    cleanArg(arg) {
        const s = arg.trim();

        if (
            s.startsWith('"') &&
            s.endsWith('"')
        ) {
            return s.substring(
                1,
                s.length - 1
            );
        }

        return s;
    }

    /**
     * Sends a speech act message to an agent in the engine.
     * @param {string} performative The KQML performative (e.g., 'tell', 'achieve', 'askIf', 'tellHow')
     * @param {string} sender The name of the sender (can be an external application name)
     * @param {string} receiver The name of the receiving agent
     * @param {string} content The message content/literal (e.g., 'temperature(room_1, 35)')
     */
    sendMsg(
        performative,
        sender,
        receiver,
        content
    ) {
        this.socket.write(
            JSON.stringify({
                type: 'message',
                performative,
                sender,
                receiver,
                content
            }) + '\n'
        );
    }

    /**
     * Sends an environment perception update to the engine.
     * @param {'add' | 'remove'} action Whether to add or remove the perception
     * @param {string} perception The perception literal (e.g., 'light_on(room_1)')
     */
    sendPerception(
        action,
        perception
    ) {
        this.socket.write(
            JSON.stringify({
                type: 'perception',
                action,
                perception
            }) + '\n'
        );
    }

    /**
     * Registers a callback function to handle actions requested by the BDI agents.
     * @param {string} actionName The name of the action to intercept
     * @param {function(string[], function(boolean): void): void} callback Function receiving action arguments and a 'respond' callback to confirm success/failure.
     */
    registerAction(
        actionName,
        callback
    ) {
        this.actionHandlers.set(
            actionName,
            callback
        );
    }

    sendActionResult(
        id,
        success
    ) {
        this.socket.write(
            JSON.stringify({
                type:
                    'action_result',
                id,
                success
            }) + '\n'
        );
    }

    /**
     * Closes the socket connection and gracefully kills the engine process if it was spawned locally.
     */
    close() {
        this.autoReconnect = false;

        this.socket.destroy();

        if (this.process) {
            this.process.kill();
            this.process = null;
        }
    }
}

module.exports = {
    BdiClient,
    Panteao: BdiClient,
    Panteão: BdiClient
};