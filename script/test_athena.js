const { Panteao } = require('./index');

console.log("[JS Test] Instantiating Panteao engine with test_athena.jcm...");
const engine = new Panteao({
    project: 'test/test_athena.jcm',
    port: 0,
    actionTimeout: 3000,
    autoRestart: false
});

engine.on('ready', () => {
    console.log("[JS Test] MAS is ready! Sending tell to beholder...");
    engine.sendMsg("tell", "external", "beholder", "hello(beholder)");
});

engine.on('message', (performative, sender, receiver, content) => {
    console.log(`[JS Test] Message: ${performative} from ${sender} to ${receiver}: ${content}`);
});

engine.on('action', (agent, action, respond) => {
    console.log(`[JS Test] Action intercepted: ${action} from ${agent}`);
    if (action.startsWith("do_something")) {
        console.log(`[JS Test] Athena agent ${agent} is doing something!`);
        respond(true);
    } else {
        respond(false);
    }
});

engine.on('disconnect', () => {
    console.log("[JS Test] Engine disconnected.");
});

engine.on('error', (err) => {
    console.error("[JS Test] Error: ", err);
});

engine.start();

// Run for 5 seconds and exit
setTimeout(() => {
    console.log("[JS Test] Stopping engine...");
    engine.stop();
    console.log("[JS Test] Test completed successfully.");
    process.exit(0);
}, 5000);
