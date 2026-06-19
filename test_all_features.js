const { Panteao } = require('./index');

console.log("[Node App] Iniciando teste completo de todas as funcoes...");
const engine = new Panteao({
    project: 'test/all_features_test.jcm',
    port: 0,
    actionTimeout: 5000,
    autoRestart: false
});

engine.on('connect', () => {
    console.log("[Node App] Conectado ao motor BDI!");
});

engine.on('action', (agent, action, callback) => {
    console.log(`[Node App] Ação interceptada: agente='${agent}', ação='${action}'`);
    
    if (action.startsWith('execute_native_test')) {
        console.log(`[Node App] Recebido comando execute_native_test com sucesso!`);
        callback(true);
    } else {
        callback(false);
    }
});

engine.on('close', (code) => {
    console.log(`[Node App] Motor BDI encerrado com código: ${code}`);
});

engine.on('error', (err) => {
    console.error("[Node App] Erro no motor BDI:", err);
    process.exit(1);
});

engine.start();

// Encerra após 6 segundos de execução
setTimeout(() => {
    console.log("[Node App] Finalizando execução de testes...");
    engine.stop();
    console.log("[Node App] Teste concluído.");
    process.exit(0);
}, 6000);
