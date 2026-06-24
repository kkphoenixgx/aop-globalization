import * as net from 'net';
import { EventEmitter } from 'events';
import * as child_process from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import { createRequire } from 'module';

function findEngineBinary(binName: string): string | null {
    const platformPkg = `panteao-engine-${process.platform}-${process.arch}`;
    const requireFromProject = createRequire(process.cwd() + '/package.json');
    const searchRoots = [
        process.cwd(),
        path.resolve(process.cwd(), 'node_modules'),
        path.resolve(process.cwd(), '..'),
        path.resolve(process.cwd(), '..', '..'),
        path.resolve(process.cwd(), '..', '..', '..')
    ];

    const candidates: string[] = [];
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

    const envPath = process.env.PANTEAO_ENGINE_PATH || process.env.PANTEAO_ENGINE_BIN;
    if (envPath) {
        candidates.push(envPath);
    }

    for (const candidate of candidates) {
        if (fs.existsSync(candidate)) {
            return candidate;
        }
    }

    try {
        const pkgPath = requireFromProject.resolve(path.join(platformPkg, 'package.json'));
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

export interface BdiClientOptions {
    host?: string;
    port?: number;
    autoReconnect?: boolean;
    reconnectInterval?: number;
    project?: string;
    binPath?: string;
}

export type ActionCallback = (args: string[], respond: (success: boolean) => void) => void;

function getFreePort(): Promise<number> {
    return new Promise((resolve, reject) => {
        const server = net.createServer();
        server.listen(0, '127.0.0.1', () => {
            const address = server.address();
            const port = typeof address === 'string' ? 0 : address?.port;
            server.close(() => {
                if (port) resolve(port);
                else reject(new Error('Failed to allocate port'));
            });
        });
        server.on('error', reject);
    });
}

export class BdiClient extends EventEmitter {
    private socket: net.Socket;
    private host: string;
    private port: number;
    private buffer: string = '';
    private autoReconnect: boolean;
    private reconnectInterval: number;
    private actionHandlers: Map<string, ActionCallback> = new Map();
    private project?: string;
    private binPath: string;
    private process: child_process.ChildProcess | null = null;

    constructor(options: BdiClientOptions = {}) {
        super();
        this.host = options.host || '127.0.0.1';
        this.port = options.port || 0;
        this.project = options.project;
        this.autoReconnect = options.project ? false : (options.autoReconnect ?? true);
        this.reconnectInterval = options.reconnectInterval || 2000;
        this.socket = new net.Socket();

        let binPath = options.binPath;
        if (!binPath) {
            const isWin = process.platform === 'win32';
            const binName = isWin ? 'panteao-engine.exe' : 'panteao-engine';
            const resolvedPath = findEngineBinary(binName);
            if (resolvedPath) {
                binPath = resolvedPath;
            } else {
                binPath = path.join(process.cwd(), 'node_modules', '.bin', binName);
                if (!fs.existsSync(binPath)) {
                    binPath = binName;
                }
            }
        }
        this.binPath = binPath;
    }

    public async connect(): Promise<void> {
        if (this.project) {
            if (this.port === 0) {
                this.port = await getFreePort();
            }

            if (!fs.existsSync(this.binPath)) {
                const errMsg = `[Panteão] Engine binary not found at resolved path: ${this.binPath}. ` +
                            `Ensure the correct architecture package (panteao-engine-${process.platform}-${process.arch}) is installed ` +
                            `or provide a valid absolute path via the 'binPath' option.`;
                
                this.emit('error', new Error(errMsg));
                throw new Error(errMsg);
            }

            if (process.platform !== 'win32') {
                try {
                    fs.accessSync(this.binPath, fs.constants.X_OK);
                } catch (e) {
                    fs.chmodSync(this.binPath, 0o755);
                }
            }


            const args = [this.project, '--port', String(this.port)];
            this.process = child_process.spawn(this.binPath, args, { stdio: 'ignore' });
            await new Promise((resolve) => setTimeout(resolve, 800));
        } else if (this.port === 0) {
            this.port = 44444;
        }

        return new Promise((resolve, reject) => {
            let handshakeBuffer = '';
            const onConnect = () => {
                const onData = (data: Buffer) => {
                    handshakeBuffer += data.toString('utf8');
                    const lines = handshakeBuffer.split('\n');
                    handshakeBuffer = lines.pop() || '';
                    for (const line of lines) {
                        try {
                            if (!line.trim()) continue;
                            const msg = JSON.parse(line);
                            if (msg.type === 'mas_ready') {
                                this.socket.off('data', onData);
                                this.socket.off('error', onError);
                                this.setupSocketEvents();
                                this.emit('connect');
                                resolve();
                                return;
                            }
                        } catch (e) {}
                    }
                };
                const onError = (err: Error) => {
                    this.socket.off('data', onData);
                    if (this.process) {
                        this.process.kill();
                        this.process = null;
                    }
                    reject(err);
                };
                this.socket.on('data', onData);
                this.socket.once('error', onError);
            };

            const onInitialError = (err: Error) => {
                if (this.process) {
                    this.process.kill();
                    this.process = null;
                }
                reject(err);
            };

            this.socket.once('error', onInitialError);
            this.socket.connect(this.port, this.host, () => {
                this.socket.off('error', onInitialError);
                onConnect();
            });
        });
    }

    private setupSocketEvents(): void {
        this.socket.on('data', (data: Buffer) => {
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

        this.socket.on('error', (err: Error) => {
            this.emit('error', err);
        });
    }

    private handleIncomingLine(line: string): void {
        try {
            const msg = JSON.parse(line);
            if (msg.type === 'action') {
                const rawAction: string = msg.action;
                const { name, args } = this.parseAction(rawAction);
                const handler = this.actionHandlers.get(name);

                if (handler) {
                    const respond = (success: boolean) => {
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

    private parseAction(actionStr: string): { name: string; args: string[] } {
        const parenIdx = actionStr.indexOf('(');
        if (parenIdx === -1) {
            return { name: actionStr.trim(), args: [] };
        }

        const name = actionStr.substring(0, parenIdx).trim();
        const argsStr = actionStr.substring(parenIdx + 1, actionStr.lastIndexOf(')'));
        
        const args: string[] = [];
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

    private cleanArg(arg: string): string {
        const s = arg.trim();
        if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
            return s.substring(1, s.length - 1);
        }
        return s;
    }

        public sendMsg(performative: string, sender: string, receiver: string, content: string): void {
        const payload = JSON.stringify({ type: 'message', performative, sender, receiver, content }) + '\n';
        this.socket.write(payload);
    }

    public sendPerception(action: 'add' | 'remove', perception: string): void {
        const payload = JSON.stringify({ type: 'perception', action, perception }) + '\n';
        this.socket.write(payload);
    }

    public registerAction(actionName: string, callback: ActionCallback): void {
        this.actionHandlers.set(actionName, callback);
    }

    private sendActionResult(id: string, success: boolean): void {
        const payload = JSON.stringify({ type: 'action_result', id, success }) + '\n';
        this.socket.write(payload);
    }

    public close(): void {
        this.autoReconnect = false;
        this.socket.destroy();
        if (this.process) {
            this.process.kill();
            this.process = null;
        }
    }
}

export { BdiClient as Panteao, BdiClient as Panteão };

