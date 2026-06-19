import * as net from 'net';
import { EventEmitter } from 'events';

export interface BdiClientOptions {
    host?: string;
    port?: number;
    autoReconnect?: boolean;
    reconnectInterval?: number;
}

export type ActionCallback = (args: string[], respond: (success: boolean) => void) => void;

export class BdiClient extends EventEmitter {
    private socket: net.Socket;
    private host: string;
    private port: number;
    private buffer: string = '';
    private autoReconnect: boolean;
    private reconnectInterval: number;
    private actionHandlers: Map<string, ActionCallback> = new Map();

    constructor(options: BdiClientOptions = {}) {
        super();
        this.host = options.host || '127.0.0.1';
        this.port = options.port || 44444;
        this.autoReconnect = options.autoReconnect ?? true;
        this.reconnectInterval = options.reconnectInterval || 2000;
        this.socket = new net.Socket();
        this.setupSocketEvents();
    }

    public connect(): Promise<void> {
        return new Promise((resolve, reject) => {
            this.socket.connect(this.port, this.host, () => {
                this.emit('connect');
                resolve();
            });

            this.socket.once('error', (err) => {
                reject(err);
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
                    // Auto-succeed if no handler registered, to prevent deadlock
                    this.sendActionResult(msg.id, true);
                }
                this.emit('action', { name, args, agent: msg.agent, id: msg.id });
            }
        } catch (e) {
            this.emit('error', e);
        }
    }

    /**
     * Parses an AgentSpeak action term like: action_name("param1", 42, atom)
     * into a clean name and string args array.
     */
    private parseAction(actionStr: string): { name: string; args: string[] } {
        const parenIdx = actionStr.indexOf('(');
        if (parenIdx === -1) {
            return { name: actionStr.trim(), args: [] };
        }

        const name = actionStr.substring(0, parenIdx).trim();
        const argsStr = actionStr.substring(parenIdx + 1, actionStr.lastIndexOf(')'));
        
        // Simple AgentSpeak parameter tokenizer (handles quoted strings, commas, atoms)
        const args: string[] = [];
        let current = '';
        let insideQuotes = false;

        for (let i = 0; i < argsStr.length; i++) {
            const char = argsStr[i];
            if (char === '"') {
                insideQuotes = !insideQuotes;
            } else if (char === ',' && !insideQuotes) {
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
        return arg.trim().replace(/^"|"$/g, '');
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
    }
}
