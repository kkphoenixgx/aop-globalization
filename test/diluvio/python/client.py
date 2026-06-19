#!/usr/bin/env python3
"""
=============================================================
 OPERAÇÃO DILÚVIO — Os Olhos do Drone (Python)
 Uses the high-level panteao.BdiClient callback API.
=============================================================
"""

import json
import socket
import sys
import threading
import time
from typing import Callable, List

# ---------------------------------------------------------------------------
# High-Level BdiClient SDK Implementation (embedded for self-contained context)
# ---------------------------------------------------------------------------

class BdiClient:
    def __init__(self, host: str = "127.0.0.1", port: int = 44444, auto_reconnect: bool = True):
        self.host = host
        self.port = port
        self.auto_reconnect = auto_reconnect
        self.socket = None
        self.file = None
        self.action_handlers = {}
        self.running = False
        self.thread = None

    def connect(self) -> None:
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect((self.host, self.port))
        self.file = self.socket.makefile('r', encoding='utf-8')
        self.running = True
        self.thread = threading.Thread(target=self._listen, daemon=True)
        self.thread.start()

    def _listen(self) -> None:
        try:
            while self.running:
                line = self.file.readline()
                if not line:
                    break
                self._handle_incoming_line(line.strip())
        except Exception:
            pass
        finally:
            if self.running and self.auto_reconnect:
                try:
                    self.close()
                    self.connect()
                except Exception:
                    pass

    def _handle_incoming_line(self, line: str) -> None:
        if not line:
            return
        try:
            msg = json.loads(line)
            if msg.get("type") == "action":
                raw_action = msg.get("action", "")
                name, args = self._parse_action(raw_action)
                handler = self.action_handlers.get(name)
                
                if handler:
                    action_id = msg.get("id")
                    def respond(success: bool):
                        self._send_action_result(action_id, success)
                    handler(args, respond)
                else:
                    self._send_action_result(msg.get("id"), True)
        except Exception:
            pass

    def _parse_action(self, action_str: str) -> tuple:
        paren_idx = action_str.find("(")
        if paren_idx == -1:
            return action_str.strip(), []
        
        name = action_str[:paren_idx].strip()
        args_str = action_str[paren_idx + 1:action_str.rfind(")")]
        
        args = []
        current = []
        inside_quotes = False
        
        for char in args_str:
            if char == '"':
                inside_quotes = not inside_quotes
            elif char == ',' and not inside_quotes:
                args.append(self._clean_arg("".join(current)))
                current = []
            else:
                current.append(char)
        if current:
            args.append(self._clean_arg("".join(current)))
            
        return name, args

    def _clean_arg(self, arg: str) -> str:
        return arg.strip().strip('"')

    def send_perception(self, action: str, perception: str) -> None:
        payload = {
            "type": "perception",
            "action": action,
            "perception": perception
        }
        self.socket.sendall((json.dumps(payload) + "\n").encode('utf-8'))

    def register_action(self, action_name: str, callback: Callable[[List[str], Callable[[bool], None]], None]) -> None:
        self.action_handlers[action_name] = callback

    def _send_action_result(self, action_id: str, success: bool) -> None:
        payload = {
            "type": "action_result",
            "id": action_id,
            "success": success
        }
        self.socket.sendall((json.dumps(payload) + "\n").encode('utf-8'))

    def close(self) -> None:
        self.running = False
        try:
            if self.file:
                self.file.close()
            if self.socket:
                self.socket.close()
        except Exception:
            pass

# ---------------------------------------------------------------------------
# Test Logic
# ---------------------------------------------------------------------------

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

    # ── 1. Connect ──────────────────────────────────────────
    t_conn_start = timestamp_ms()
    client = BdiClient(host=HOST, port=PORT)
    try:
        client.connect()
    except Exception as e:
        print(f"[DILUVIO][Python] ERRO: Não foi possível conectar em {HOST}:{PORT} - {e}")
        sys.exit(1)
    t_conn_end = timestamp_ms()
    print(f"[DILUVIO][Python] Conectado ao motor BDI ({t_conn_end - t_conn_start:.1f}ms)")

    # ── 2. Wait for engine readiness ────────────────────────
    time.sleep(1)

    action_received = threading.Event()
    received_args = []

    # Register action callback
    client.register_action("dispatch_rescue_bot", lambda args, respond: (
        received_args.extend(args),
        respond(True),
        action_received.set()
    ))

    # ── 3. Send perception ──────────────────────────────────
    t_send = timestamp_ms()
    client.send_perception("add", PERCEPTION)
    print(f"[DILUVIO][Python] Percepção enviada ({timestamp_ms() - t_send:.1f}ms)")

    # ── 4. Wait for action ──────────────────────────────────
    t_wait = timestamp_ms()
    if not action_received.wait(timeout=TIMEOUT - 1):
        print("[DILUVIO][Python] ERRO: Nenhuma ação recebida dentro do timeout")
        client.close()
        sys.exit(1)
    t_action = timestamp_ms()

    print(f"[DILUVIO][Python] Ação recebida: dispatch_rescue_bot({received_args}) (espera: {t_action - t_wait:.1f}ms)")

    # ── 5. Metrics & cleanup ────────────────────────────────
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
    else:
        print("[DILUVIO] FALHA: Teste excedeu 5 segundos")
        sys.exit(1)

if __name__ == "__main__":
    main()
