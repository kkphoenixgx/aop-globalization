const { Panteao } = require('./index');

let counter = 0;

console.log("[Node App] Instanciando motor Panteao BDI...");
const engine = new Panteao({
    project: 'test/counter_test.jcm',
    port: 0,              // Porta dinâmica
    actionTimeout: 3000,  // Timeout de 3 segundos
    autoRestart: false
});

engine.on('connect', () => {
    console.log("[Node App] Conectado ao motor BDI!");
    
    // Inicia contador incrementando a cada 500ms
    const intervalId = setInterval(() => {
        counter++;
        console.log(`[Node App] Contador = ${counter}`);
        
        // Atualiza a percepção do agente
        engine.addPercept(`counter(${counter})`);
        
        // Remove a percepção anterior para manter a base de crenças limpa
        if (counter > 1) {
            engine.removePercept(`counter(${counter - 1})`);
        }
    }, 500);
    
    engine.intervalId = intervalId;
});

engine.on('action', (agent, action, callback) => {
    console.log(`[Node App] Ação interceptada: agente='${agent}', ação='${action}'`);
    
    if (action === 'reset_counter') {
        console.log("[Node App] Zerando o contador conforme solicitado pelo agente!");
        
        // Remove percepção antiga
        engine.removePercept(`counter(${counter})`);
        
        // Reseta o contador local
        counter = 0;
        
        // Adiciona nova percepção
        engine.addPercept(`counter(0)`);
        
        // Reporta sucesso ao agente
        callback(true);
    } else {
        callback(false);
    }
});

engine.on('close', (code) => {
    console.log(`[Node App] Motor BDI encerrado com código: ${code}`);
    if (engine.intervalId) clearInterval(engine.intervalId);
});

engine.on('error', (err) => {
    console.error("[Node App] Erro no motor BDI:", err);
});

engine.start();

// Roda por 12 segundos (o suficiente para ver o contador chegar a 10 e reiniciar)
setTimeout(() => {
    console.log("[Node App] Finalizando teste...");
    engine.stop();
    console.log("[Node App] Teste concluído com sucesso.");
    process.exit(0);
}, 12000);
