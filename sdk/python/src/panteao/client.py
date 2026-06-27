import socket
import json
import threading
import subprocess
import time
import os
import platform
from typing import Callable, List

class Panteao:
    def __init__(self, host: str = "127.0.0.1", port: int = 0, auto_reconnect: bool = True, project: str = None):
        self.host = host
        self.port = port
        self.project = project
        
        # Resolve binary location inside the package structure
        current_dir = os.path.dirname(os.path.abspath(__file__))
        bin_name = "panteao-engine.exe" if platform.system() == "Windows" else "panteao-engine"
        
        self.bin_path = os.path.join(current_dir, "bin", bin_name)
        if not os.path.exists(self.bin_path):
            self.bin_path = os.path.join(current_dir, bin_name)
            
        self.version = "1.0.0" # This will be bumped automatically by CI
            
        self.auto_reconnect = False if project else auto_reconnect
        self.socket = None
        self.file = None
        self.action_handlers = {}
        self.message_handlers = {}
        self.general_message_handler = None
        self.running = False
        self.thread = None
        self.process = None

    def _get_free_port(self) -> int:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind(("", 0))
        port = s.getsockname()[1]
        s.close()
        return port

    def connect(self) -> None:
        if self.project:
            if not os.path.exists(self.bin_path):
                self._download_engine()

            if self.port == 0:
                self.port = self._get_free_port()
            
            # Spawn the GraalVM engine subprocess
            args = [self.bin_path, self.project, "--port", str(self.port)]
            self.process = subprocess.Popen(
                args, 
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )
            
            threading.Thread(target=self._read_logs, args=(self.process.stdout,), daemon=True).start()
            threading.Thread(target=self._read_logs, args=(self.process.stderr,), daemon=True).start()
            
            time.sleep(0.8)
        elif self.port == 0:
            self.port = 44444

        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect((self.host, self.port))
        self.file = self.socket.makefile('r', encoding='utf-8')
        while True:
            line = self.file.readline()
            if not line:
                raise ConnectionError("Disconnected during handshake")
            try:
                msg = json.loads(line.strip())
                if msg.get("type") == "mas_ready":
                    break
            except Exception:
                pass
        self.running = True
        self.thread = threading.Thread(target=self._listen, daemon=True)
        self.thread.start()

    def _read_logs(self, pipe) -> None:
        import re
        pattern = re.compile(r"^\[(.*?)\]\s(.*)")
        try:
            for line in iter(pipe.readline, ''):
                if not line:
                    break
                line = line.strip()
                if not line:
                    continue
                match = pattern.match(line)
                if match:
                    # \033[36m is Cyan ANSI code
                    print(f"\033[36m[{match.group(1)}]\033[0m {match.group(2)}")
                else:
                    print(f"\033[36m[MAS]\033[0m {line}")
        except Exception:
            pass

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
            elif msg.get("type") == "message":
                performative = msg.get("performative")
                sender = msg.get("sender")
                receiver = msg.get("receiver")
                content = msg.get("content")
                handler = self.message_handlers.get(performative)
                if handler:
                    handler(sender, receiver, content)
                if self.general_message_handler:
                    self.general_message_handler(performative, sender, receiver, content)
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
        depth_brackets = 0
        depth_parens = 0
        
        for char in args_str:
            if char == '"':
                inside_quotes = not inside_quotes
                current.append(char)
            elif not inside_quotes and char == '[':
                depth_brackets += 1
                current.append(char)
            elif not inside_quotes and char == ']':
                depth_brackets -= 1
                current.append(char)
            elif not inside_quotes and char == '(':
                depth_parens += 1
                current.append(char)
            elif not inside_quotes and char == ')':
                depth_parens -= 1
                current.append(char)
            elif char == ',' and not inside_quotes and depth_brackets == 0 and depth_parens == 0:
                args.append(self._clean_arg("".join(current)))
                current = []
            else:
                current.append(char)
        if current:
            args.append(self._clean_arg("".join(current)))
            
        return name, args

    def _clean_arg(self, arg: str) -> str:
        s = arg.strip()
        if s.startswith('"') and s.endswith('"') and len(s) >= 2:
            return s[1:-1]
        return s

    def _download_engine(self) -> None:
        import urllib.request
        import tarfile
        import zipfile
        import stat
        
        system = platform.system().lower()
        machine = platform.machine().lower()
        
        if system == "windows":
            os_name = "win32"
        elif system == "darwin":
            os_name = "darwin"
        else:
            os_name = "linux"
            
        arch = "arm64" if "arm" in machine or "aarch64" in machine else "x64"
        pkg_name = f"panteao-engine-{os_name}-{arch}"
        
        # We download the published NPM tarball from the registry directly to extract the binary
        url = f"https://registry.npmjs.org/{pkg_name}/-/{pkg_name}-{self.version}.tgz"
        
        print(f"[Panteao] Downloading native engine for {os_name}-{arch} (v{self.version})...")
        try:
            tar_path = self.bin_path + ".tgz"
            urllib.request.urlretrieve(url, tar_path)
            
            with tarfile.open(tar_path, "r:gz") as tar:
                for member in tar.getmembers():
                    if member.name.endswith("panteao-engine") or member.name.endswith("panteao-engine.exe"):
                        member.name = os.path.basename(member.name)
                        tar.extract(member, path=os.path.dirname(self.bin_path))
                        break
            
            os.remove(tar_path)
            if system != "windows":
                os.chmod(self.bin_path, os.stat(self.bin_path).st_mode | stat.S_IEXEC)
                
            print("[Panteao] Engine downloaded successfully.")
        except Exception as e:
            raise RuntimeError(f"Failed to download Panteao engine from {url}: {e}")


    def send_perception(self, action: str, perception: str) -> None:
        payload = {
            "type": "perception",
            "action": action,
            "perception": perception
        }
        self.socket.sendall((json.dumps(payload) + "\n").encode('utf-8'))

    def register_action(self, action_name: str, callback: Callable[[List[str], Callable[[bool], None]], None]) -> None:
        self.action_handlers[action_name] = callback

    def register_message(self, callback: Callable[[str, str, str, str], None]) -> None:
        self.general_message_handler = callback

    def register_performative(self, performative: str, callback: Callable[[str, str, str], None]) -> None:
        self.message_handlers[performative] = callback

    def send_msg(self, performative: str, sender: str, receiver: str, content: str) -> None:
        payload = {
            "type": "message",
            "performative": performative,
            "sender": sender,
            "receiver": receiver,
            "content": content
        }
        self.socket.sendall((json.dumps(payload) + "\n").encode('utf-8'))

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
            if self.socket:
                self.socket.shutdown(socket.SHUT_RDWR)
        except Exception:
            pass
        try:
            if self.file:
                self.file.close()
        except Exception:
            pass
        try:
            if self.socket:
                self.socket.close()
        except Exception:
            pass
        try:
            if self.process:
                self.process.terminate()
                self.process.wait()
        except Exception:
            pass
