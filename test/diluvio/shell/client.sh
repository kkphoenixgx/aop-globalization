#!/usr/bin/env bash
source sdk/panteao_client.sh

echo "[DILUVIO] Shell client starting"

function handle_scale_up_servers() {
    echo "[DILUVIO] Action handled: scale_up_servers"
    panteao_send_action_result "$1" true
    echo "[DILUVIO] SUCCESS"
    panteao_close
    exit 0
}

panteao_register_action "scale_up_servers" "handle_scale_up_servers"

panteao_connect "127.0.0.1" 44444

echo "[DILUVIO] Connected!"
panteao_send_msg "tell" "external" "orquestrador" "high_latency(600)"

panteao_process_actions 10

sleep 5
echo "[DILUVIO] TIMEOUT"
panteao_close
exit 1
