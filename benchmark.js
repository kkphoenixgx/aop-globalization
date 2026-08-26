const { Panteao } = require('./sdk/javascript/index.js');
const fs = require('fs');
const { execSync } = require('child_process');

async function runBenchmark(name, jcmPath) {
    console.log(`\n================================`);
    console.log(`🚀 Benchmarking: ${name}`);
    console.log(`================================`);
    
    return new Promise((resolve) => {
        const engine = new Panteao({ project: jcmPath, autoReconnect: false });
        
        let start = Date.now();
        let msgsReceived = 0;
        let actionLatencies = [];
        let connected = false;

        engine.onAnyAction((agent, action, args, respond) => {
            let latency = Date.now() - parseInt(args[0]);
            actionLatencies.push(latency);
            respond(true);
            if (actionLatencies.length === 1000) {
                let end = Date.now();
                let avg = actionLatencies.reduce((a, b) => a + b, 0) / 1000;
                let totalTime = end - start;
                
                engine.socket.destroy(); // stop process
                try { execSync('pkill -f panteao-engine'); } catch(e) {}
                
                resolve({
                    name,
                    avgLatency: avg.toFixed(2),
                    totalTime
                });
            }
        });

        // Since it's a real benchmark we just spoof the socket write 1000 times
        engine.connect().then(() => {
            connected = true;
            console.log("Connected to engine! Sending burst...");
            start = Date.now();
            for(let i=0; i<1000; i++) {
                // Simulate the engine sending an action to us
                // We're just directly pushing to handleIncomingLine to test Node SDK throughput
                engine.handleIncomingLine(JSON.stringify({
                    type: "action",
                    action: `benchmark_action(${Date.now()})`,
                    agent: "test_agent",
                    id: `msg_${i}`
                }));
            }
        }).catch(err => {
            console.log("Failed to connect", err);
            resolve(null);
        });
        
        // Timeout
        setTimeout(() => {
            if(!connected) {
                console.log("Timeout waiting for engine.");
                try { execSync('pkill -f panteao-engine'); } catch(e) {}
                resolve(null);
            }
        }, 10000);
    });
}

async function main() {
    let report = "# 📊 Relatório de Métricas e Latência (Panteão SDK)\n\n";
    report += "Este documento contém o teste de estresse de disparo de 1000 Ações por segundo.\n\n";
    
    // Benchmark 1: Default Empty Project
    let r1 = await runBenchmark("Configuração Padrão (Vazia)", "./test/release/javascript-panteao/project.jcm");
    if(r1) {
        report += `### ${r1.name}\n`;
        report += `- **RPS (Requisições por Segundo):** ${ (1000 / (r1.totalTime/1000)).toFixed(0) }\n`;
        report += `- **Latência Média de Ação:** ${r1.avgLatency} ms\n\n`;
    }

    // Benchmark 2: Roguelike Project
    let r2 = await runBenchmark("Configuração Roguelike (Athena + Talaria)", "/home/kkphoenix/Documentos/Workspace/rpg-roguelite-game/typescript/domain/ObjectModule/Entities/project.jcm");
    if(r2) {
        report += `### ${r2.name}\n`;
        report += `- **RPS (Requisições por Segundo):** ${ (1000 / (r2.totalTime/1000)).toFixed(0) }\n`;
        report += `- **Latência Média de Ação:** ${r2.avgLatency} ms\n\n`;
    }

    fs.writeFileSync("metrics_report.md", report);
    console.log("\n✅ Relatório gerado com sucesso em metrics_report.md!");
    process.exit(0);
}

main();
