import { EventEmitter } from 'events';

export interface PanteaoOptions {
    project: string;
    port?: number;
    actionTimeout?: number;
    autoRestart?: boolean;
    useJarFallback?: boolean;
}

export class Panteao extends EventEmitter {
    constructor(options: PanteaoOptions);

    project: string;
    port: number;
    actionTimeout: number;
    autoRestart: boolean;
    useJarFallback: boolean;
    connected: boolean;

    start(): Promise<void>;
    stop(): void;
    send(json: any): void;
    sendMsg(performative: string, sender: string, receiver: string, content: string): void;

    on(event: 'connect', listener: () => void): this;
    on(event: 'ready', listener: () => void): this;
    on(event: 'disconnect', listener: () => void): this;
    on(event: 'close', listener: (code: number) => void): this;
    on(event: 'error', listener: (err: Error) => void): this;
    on(event: 'action', listener: (agent: string, action: string, callback: (success: boolean) => void) => void): this;
    on(event: 'message', listener: (performative: string, sender: string, receiver: string, content: string) => void): this;
    on(event: 'tell', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: 'untell', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: 'achieve', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: 'unachieve', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: 'tellHow', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: 'untellHow', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: 'askIf', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: 'askAll', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: 'askHow', listener: (sender: string, receiver: string, content: string) => void): this;
    on(event: string, listener: (...args: any[]) => void): this;
}
