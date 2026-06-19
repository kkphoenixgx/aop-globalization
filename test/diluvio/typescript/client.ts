import * as net from "net";
import { performance } from "perf_hooks";

const HOST = "127.0.0.1";
const PORT = 44444;
const TIMEOUT_MS = 5000;

interface ActionRequest {
  type: "action";
  id: string;
  agent: string;
  action: string;
}

function log(msg: string): void {
  console.log(`[DILUVIO] ${msg}`);
}

function sendJson(socket: net.Socket, obj: Record<string, unknown>): void {
  const line = JSON.stringify(obj) + "\n";
  socket.write(line);
}

function run(): void {
  const t0 = performance.now();

  log("O Centro de Comando (TypeScript) - starting");
  log(`Connecting to ${HOST}:${PORT}...`);

  const socket = new net.Socket();
  let buffer = "";
  let actionHandled = false;

  const timeout = setTimeout(() => {
    log("ERROR: Timeout exceeded (5s)");
    socket.destroy();
    process.exit(1);
  }, TIMEOUT_MS);

  socket.connect(PORT, HOST, () => {
    const tConn = performance.now();
    log(`Connected in ${(tConn - t0).toFixed(2)}ms`);

    // Wait 1 second for engine readiness, then send perception
    setTimeout(() => {
      const perception = {
        type: "perception",
        action: "add",
        perception: "dashboard_update(painel_ativo)",
      };
      log(`Sending perception: ${perception.perception}`);
      sendJson(socket, perception);
      const tSend = performance.now();
      log(`Perception sent in ${(tSend - tConn).toFixed(2)}ms (after 1s wait)`);
    }, 1000);
  });

  socket.on("data", (data: Buffer) => {
    buffer += data.toString();
    const lines = buffer.split("\n");
    buffer = lines.pop() || "";

    for (const line of lines) {
      if (line.trim().length === 0) continue;

      let msg: Record<string, unknown>;
      try {
        msg = JSON.parse(line);
      } catch {
        log(`Ignoring non-JSON line: ${line}`);
        continue;
      }

      log(`Received: ${JSON.stringify(msg)}`);

      if (msg.type === "action") {
        const action = msg as unknown as ActionRequest;
        log(`Action request: id=${action.id} agent=${action.agent} action=${action.action}`);

        const result = {
          type: "action_result",
          id: action.id,
          success: true,
        };
        sendJson(socket, result);
        log(`Action result sent for id=${action.id}`);
        actionHandled = true;

        const tEnd = performance.now();
        const elapsed = tEnd - t0;

        log("--- Timing Metrics ---");
        log(`Total elapsed: ${elapsed.toFixed(2)}ms`);
        log("[DILUVIO] SUCCESS");

        clearTimeout(timeout);
        socket.destroy();
        process.exit(0);
      }
    }
  });

  socket.on("error", (err: Error) => {
    log(`Socket error: ${err.message}`);
    clearTimeout(timeout);
    process.exit(1);
  });

  socket.on("close", () => {
    if (!actionHandled) {
      log("ERROR: Connection closed without handling action");
      clearTimeout(timeout);
      process.exit(1);
    }
    log("Connection closed. Test complete.");
    process.exit(0);
  });
}

run();
