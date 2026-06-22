#!/usr/bin/env node
// ============================================================================
// Operação Dilúvio — O Centro de Comando (JavaScript / Node.js)
// ============================================================================

'use strict';

const { Panteão } = require('panteao');
const BdiClient = Panteão;

const HOST = '127.0.0.1';
const PORT = 44444;
const TIMEOUT_MS = 5000;
const STARTUP_DELAY_MS = 1000;

function now() {
  return process.hrtime.bigint();
}

function elapsedMs(start) {
  return Number(now() - start) / 1e6;
}

function log(msg) {
  console.log(`[DILUVIO] ${msg}`);
}

(async function main() {
  const t0 = now();
  log('O Centro de Comando — JavaScript/Node.js test starting');

  log(`Waiting ${STARTUP_DELAY_MS}ms for engine readiness...`);
  await new Promise((r) => setTimeout(r, STARTUP_DELAY_MS));

  const tConnect = now();
  const client = new Panteão({ host: HOST, port: PORT });


  const timeout = setTimeout(() => {
    log('TIMEOUT — test exceeded 5s');
    log('[DILUVIO] FAILURE');
    client.close();
    process.exit(1);
  }, TIMEOUT_MS);

  let updatesHandled = 0;

  // Register callback
  client.registerAction('update_dashboard', (args, respond) => {
    const actionMs = elapsedMs(tConnect);
    log(`Action handled: update_dashboard(${args.join(', ')})`);
    respond(true);
    updatesHandled++;
    checkSuccess();
  });

  client.registerAction('js_test_action', (args, respond) => {
    log(`Action handled: js_test_action(${args.join(', ')})`);
    respond(true);
    updatesHandled++;
    checkSuccess();
  });

  function checkSuccess() {
    if (updatesHandled >= 2) {
      const totalMs = elapsedMs(t0);
      log('--- Timing Metrics ---');
      log(`  Total elapsed    : ${totalMs.toFixed(2)}ms`);
      log(`  Connection time  : ${elapsedMs(tConnect).toFixed(2)}ms`);
      log('--- Test Complete ---');
      log('[DILUVIO] SUCCESS');

      clearTimeout(timeout);
      client.close();
      process.exit(0);
    }
  }

  try {
    await client.connect();
    const connMs = elapsedMs(tConnect);
    log(`Connected to engine at ${HOST}:${PORT} (${connMs.toFixed(2)}ms)`);

    log('Engine reported MAS is ready! Sending performatives...');
    const tSend = now();
    
    // Testing multiple performatives
    client.sendMsg('tell', 'external', 'orquestrador', 'dashboard_update(sistema_online)');
    client.sendMsg('achieve', 'external', 'orquestrador', 'js_test_goal(1)');
    client.sendMsg('askOne', 'external', 'orquestrador', 'alert_active(X)');
    client.sendMsg('unachieve', 'external', 'orquestrador', 'dummy_goal');
    client.sendMsg('untell', 'external', 'orquestrador', 'dummy_belief');

    const sendMs = elapsedMs(tSend);
    log(`Performatives sent (tell, achieve, askOne, unachieve, untell) (${sendMs.toFixed(2)}ms)`);
  } catch (err) {
    log(`Connection/execution error: ${err.message}`);
    log('[DILUVIO] FAILURE');
    clearTimeout(timeout);
    process.exit(1);
  }
})();
