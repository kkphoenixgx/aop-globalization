#!/usr/bin/env python3
"""
=============================================================
 OPERAÇÃO DILÚVIO — Os Olhos do Drone (Python)
=============================================================
"""

import sys
import threading
import time
from panteao import Panteao

HOST = "127.0.0.1"
PORT = 44444
TIMEOUT = 5  # seconds
PERCEPTION = "victim_spotted(-22.28,-42.53,ferido)"

def timestamp_ms() -> float:
    return time.monotonic() * 1000

def main() -> None:
    t_start = timestamp_ms()
    print(f"[DILUVIO][Python] Os Olhos do Drone — início")
    print(f"[DILUVIO][Python] Percepção: {PERCEPTION}")

    t_conn_start = timestamp_ms()
    client = Panteao(host=HOST, port=PORT)
    try:
        client.connect()
    except Exception as e:
        print(f"[DILUVIO][Python] ERRO: Não foi possível conectar em {HOST}:{PORT} - {e}")
        sys.exit(1)
    t_conn_end = timestamp_ms()
    print(f"[DILUVIO][Python] Conectado ao motor BDI ({t_conn_end - t_conn_start:.1f}ms)")

    action_received = threading.Event()
    received_args = []

    client.register_action("dispatch_rescue_bot", lambda args, respond: (
        received_args.extend(args),
        respond(True),
        action_received.set()
    ))

    t_send = timestamp_ms()
    client.send_msg("tell", "external", "orquestrador", PERCEPTION)
    print(f"[DILUVIO][Python] Percepção enviada ({timestamp_ms() - t_send:.1f}ms)")

    t_wait = timestamp_ms()
    if not action_received.wait(timeout=TIMEOUT - 1):
        print("[DILUVIO][Python] ERRO: Nenhuma ação recebida dentro do timeout")
        client.close()
        sys.exit(1)
    t_action = timestamp_ms()

    print(f"[DILUVIO][Python] Ação recebida: dispatch_rescue_bot({received_args}) (espera: {t_action - t_wait:.1f}ms)")

    t_end = timestamp_ms()
    total = t_end - t_start

    print()
    print("╔══════════════════════════════════════════════════╗")
    print("║       OS OLHOS DO DRONE — MÉTRICAS              ║")
    print("╠══════════════════════════════════════════════════╣")
    print(f"║  Conexão TCP:        {t_conn_end - t_conn_start:>8.1f} ms             ║")
    print(f"║  Envio percepção:    {timestamp_ms() - t_send:>8.1f} ms             ║")
    print(f"║  Espera ação BDI:    {t_action - t_wait:>8.1f} ms             ║")
    print(f"║  Tempo total:        {total:>8.1f} ms             ║")
    print("╚══════════════════════════════════════════════════╝")
    print()

    client.close()

    if total < 5000:
        print("[DILUVIO] SUCCESS")
        sys.exit(0)
    else:
        print("[DILUVIO] FALHA: Teste excedeu 5 segundos")
        sys.exit(1)

if __name__ == "__main__":
    main()
