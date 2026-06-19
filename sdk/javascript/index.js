const net = require('net');
const EventEmitter = require('events');

class BdiClient extends EventEmitter {
    constructor(options = {}) {
        super();
        this.host = options.host || '127.0.0.1';
        this.port = options.port || 44444;
        this.autoReconnect = options.autoReconnect ?? true;
        this.reconnectInterval = options.reconnectInterval || 2000;
        this.socket = new net.Socket();
        this.buffer = '';
        this.actionHandlers = new Map();
        this.setupSocketEvents();
    }

    connect() {
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
            if (msg.type === 'action') {
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

    cleanArg(arg) {
        return arg.trim().replace(/^"|"$/g, '');
    }

    sendPerception(action, perception) {
        const payload = JSON.stringify({ type: 'perception', action, perception }) + '\n';
        this.socket.write(payload);
    }

    registerAction(actionName, callback) {
        this.actionHandlers.set(actionName, callback);
    }

    sendActionResult(id, success) {
        const payload = JSON.stringify({ type: 'action_result', id, success }) + '\n';
        this.socket.write(payload);
    }

    close() {
        this.autoReconnect = false;
        this.socket.destroy();
    }
}

module.exports = { BdiClient };
