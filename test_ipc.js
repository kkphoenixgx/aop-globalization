const { Panteao } = require('./index');

console.log("[JS Backend] Instantiating Panteao engine...");
const engine = new Panteao({
    project: 'test/test_ipc.jcm',
    port: 0, // 0 = Let Panteão find a free port
    actionTimeout: 3000, // 3 seconds timeout for actions
    autoRestart: true // restart if it crashes
});

engine.on('connect', () => {
    console.log("[JS Backend] Connected successfully via Sockets!");
    console.log("[JS Backend] Adding percept: test_percept...");
    engine.addPercept("test_percept");
});

engine.on('action', (agent, action, callback) => {
    console.log(`[JS Backend] Action request intercepted: agent='${agent}', action='${action}'`);
    
    // Simulate some logic and send success result
    setTimeout(() => {
        console.log(`[JS Backend] Responding to engine with success=true`);
        callback(true);
    }, 100);
});

engine.on('disconnect', () => {
    console.log("[JS Backend] Engine disconnected.");
});

engine.on('error', (err) => {
    console.error("[JS Backend] Error: ", err);
});

console.log("[JS Backend] Starting Panteao engine process...");
engine.start();

// Run for 6 seconds and then stop
setTimeout(() => {
    console.log("[JS Backend] Stopping engine...");
    engine.stop();
    console.log("[JS Backend] Test complete.");
    process.exit(0);
}, 6000);
