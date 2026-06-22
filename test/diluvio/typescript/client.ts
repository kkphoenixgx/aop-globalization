import { Panteão } from 'panteaots';

const HOST = "127.0.0.1";
const PORT = 44444;

function log(msg: string): void {
  console.log(`[DILUVIO] ${msg}`);
}

async function run() {
  log("O Centro de Comando (TypeScript) - starting");
  const client = new Panteão({ host: HOST, port: PORT });
  
  setTimeout(() => {
    log("TIMEOUT");
    client.close();
    process.exit(1);
  }, 5000);

  client.registerAction("update_dashboard", (args, respond) => {
    log(`Action handled: dashboard_update`);
    respond(true);
    log("[DILUVIO] SUCCESS");
    client.close();
    process.exit(0);
  });

  try {
    await client.connect();
    log("Connected!");
    client.sendMsg("tell", "external", "orquestrador", "dashboard_update(sistema_ts)")
  } catch (err) {
    log(`Error: ${err}`);
    process.exit(1);
  }
}

run();
