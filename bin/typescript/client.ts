import * as net from 'net';
const client = net.createConnection({ port: 40000 }, () => {
    client.write(JSON.stringify({ type: 'perception', action: 'add', perception: 'test_percept' }) + '\n');
});