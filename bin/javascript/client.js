const net = require('net');
const port = 40000; // Replace with your port
const client = net.createConnection({ port }, () => {
    console.log('Connected to Panteao BDI Engine!');
    client.write(JSON.stringify({type: 'perception', action: 'add', perception: 'test_percept'}) + '\n');
});
client.on('data', (data) => {
    console.log('Received from BDI:', data.toString());
});