import socket
import json
import threading
import re
from typing import Callable, List

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
                # Simple reconnect logic
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
                    # Trigger the callback
                    handler(args, respond)
                else:
                    # Auto-succeed if no handler to prevent blocking
                    self._send_action_result(msg.get("id"), True)
        except Exception:
            pass

    def _parse_action(self, action_str: str) -> tuple:
        paren_idx = action_str.find("(")
        if paren_idx == -1:
            return action_str.strip(), []
        
        name = action_str[:paren_idx].strip()
        args_str = action_str[paren_idx + 1:action_str.rfind(")")]
        
        # Simple AgentSpeak tokenization
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
