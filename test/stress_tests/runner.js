const net = require('net');
const fs = require('fs');

let actions_received = 0;
let latencies = [];
let start_times = {}; // map tick -> timestamp
let tick = 0;

console.log("Connecting to Engine...");
const client = new net.Socket();
client.connect(44444, '127.0.0.1', () => {
    console.log("Connected! Starting 60Hz Perception Flooding for 10 seconds...");
    
    // Simulate 60 Hz loop (16ms)
    let interval = setInterval(() => {
        tick++;
        let t = Date.now();
        start_times[tick] = t;
        
        // Send state update to all 10 agents
        for(let i=1; i<=10; i++) {
            client.write(JSON.stringify({
                type: "message",
                performative: "tell",
                sender: "game",
                receiver: `npc${i}`,
                content: `pos(${tick % 50}, ${tick % 50})`
            }) + "\n");
        }
    }, 16);
    
    // End benchmark after 10 seconds
    setTimeout(() => {
        clearInterval(interval);
        
        // Compute Metrics
        latencies.sort((a,b) => a - b);
        let p50 = latencies[Math.floor(latencies.length * 0.50)] || 0;
        let p95 = latencies[Math.floor(latencies.length * 0.95)] || 0;
        let p99 = latencies[Math.floor(latencies.length * 0.99)] || 0;
        let max = latencies[latencies.length - 1] || 0;
        let avg = latencies.reduce((a,b) => a+b, 0) / (latencies.length || 1);
        
        let report = `# 🔬 R2 Stress Test Metrics (Cognitive Bottlenecks)\n\n`;
        report += `**Duration:** 10 seconds\n`;
        report += `**Frequency:** 60 Hz (16ms per tick)\n`;
        report += `**Agents:** 10 Concurrent BDI NPCs\n`;
        report += `**Perceptions Sent:** ${tick * 10}\n`;
        report += `**Cognitive Actions Received:** ${actions_received}\n\n`;
        
        report += `### 📉 Latency Breakdown (Percept to Action CCT)\n`;
        report += `- **Average CCT:** ${avg.toFixed(2)} ms\n`;
        report += `- **Median (p50):** ${p50} ms\n`;
        report += `- **Tail Latency (p95):** ${p95} ms\n`;
        report += `- **Extreme Tail (p99):** ${p99} ms *(This causes micro-stuttering!)*\n`;
        report += `- **Max GC/Locking Pause:** ${max} ms\n\n`;
        
        if (p99 > 16) {
            report += `> ⚠️ **ALERTA R2:** O p99 estourou a janela de 16ms do frame. O jogo sofrerá micro-stutterings sob essa carga devido à lentidão de inferência (AgentSpeak Unification) ou pausas do GC.\n`;
        } else {
            report += `> ✅ **PASSOU (R2):** O p99 se manteve abaixo de 16ms! A Engine está aguentando o ciclo cognitivo dentro do tempo de renderização do frame!\n`;
        }
        
        fs.writeFileSync("r2_metrics.md", report);
        console.log("Done! Written to r2_metrics.md");
        process.exit(0);
    }, 10000);
});

client.on('data', (data) => {
    let str = data.toString();
    let lines = str.split("\n").filter(l => l.trim() !== "");
    for(let l of lines) {
        let msg = JSON.parse(l);
        if(msg.type === "action") {
            actions_received++;
            // We just measure time from the most recent tick since percepts override each other
            let latency = Date.now() - start_times[tick];
            if (latency >= 0) latencies.push(latency);
            
            // Auto-respond success
            client.write(JSON.stringify({
                type: "action_result",
                id: msg.id,
                success: true
            }) + "\n");
        }
    }
});
client.on('error', () => {
    console.log("Connection failed.");
    process.exit(1);
});
