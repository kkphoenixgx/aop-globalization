import os
import re

sdks = {
    "c": {
        "files": ["sdk/c/include/panteao_client.h", "sdk/c/src/panteao_client.c", "test/diluvio/c/src/client.c"],
        "decl": "int panteao_send_msg(PanteaoClient *client, const char *performative, const char *sender, const char *receiver, const char *content);",
        "impl": """int panteao_send_msg(PanteaoClient *client, const char *performative, const char *sender, const char *receiver, const char *content) {
    char buffer[2048];
    snprintf(buffer, sizeof(buffer), "{\\"type\\":\\"message\\",\\"performative\\":\\"%s\\",\\"sender\\":\\"%s\\",\\"receiver\\":\\"%s\\",\\"content\\":\\"%s\\"}\\n", performative, sender, receiver, content);
    return write(client->socket_fd, buffer, strlen(buffer)) >= 0 ? 0 : -1;
}""",
        "replace_call": r'panteao_send_perception\(&client,\s*"[^"]*",\s*([^)]*)\)',
        "new_call": r'panteao_send_msg(&client, "tell", "external", "orquestrador", \1)'
    },
    "cpp": {
        "files": ["sdk/cpp/include/panteao_client.h", "sdk/cpp/src/panteao_client.cpp", "test/diluvio/cpp/src/client.cpp"],
        "decl": "bool sendMsg(const std::string& performative, const std::string& sender, const std::string& receiver, const std::string& content);",
        "impl": """bool BdiClient::sendMsg(const std::string& performative, const std::string& sender, const std::string& receiver, const std::string& content) {
    std::string json = "{\\"type\\":\\"message\\",\\"performative\\":\\"" + performative + "\\",\\"sender\\":\\"" + sender + "\\",\\"receiver\\":\\"" + receiver + "\\",\\"content\\":\\"" + content + "\\"}\\n";
    return write(socket_fd, json.c_str(), json.length()) >= 0;
}""",
        "replace_call": r'client\.sendPerception\("[^"]*",\s*([^)]*)\)',
        "new_call": r'client.sendMsg("tell", "external", "orquestrador", \1)'
    },
    "csharp": {
        "files": ["sdk/csharp/src/BdiClient.cs", "test/diluvio/csharp/Client.cs"],
        "decl": "",
        "impl": """        public void SendMsg(string performative, string sender, string receiver, string content)
        {
            var msg = new { type = "message", performative = performative, sender = sender, receiver = receiver, content = content };
            var json = System.Text.Json.JsonSerializer.Serialize(msg) + "\\n";
            var bytes = System.Text.Encoding.UTF8.GetBytes(json);
            _stream.Write(bytes, 0, bytes.Length);
            _stream.Flush();
        }""",
        "replace_call": r'client\.SendPerception\("[^"]*",\s*([^)]*)\)',
        "new_call": r'client.SendMsg("tell", "external", "orquestrador", \1)'
    },
    "java": {
        "files": ["sdk/java/src/main/java/io/panteao/BdiClient.java", "test/diluvio/java/Client.java"],
        "decl": "",
        "impl": """    public void sendMsg(String performative, String sender, String receiver, String content) {
        String json = "{\\"type\\":\\"message\\",\\"performative\\":\\"" + performative + "\\",\\"sender\\":\\"" + sender + "\\",\\"receiver\\":\\"" + receiver + "\\",\\"content\\":\\"" + content + "\\"}\\n";
        out.print(json);
        out.flush();
    }""",
        "replace_call": r'client\.sendPerception\("[^"]*",\s*([^)]*)\)',
        "new_call": r'client.sendMsg("tell", "external", "orquestrador", \1)'
    },
    "python": {
        "files": ["sdk/python/src/panteao/client.py", "test/diluvio/python/client.py"],
        "decl": "",
        "impl": """    def send_msg(self, performative: str, sender: str, receiver: str, content: str) -> None:
        msg = {"type": "message", "performative": performative, "sender": sender, "receiver": receiver, "content": content}
        self.sock.sendall((json.dumps(msg) + "\\n").encode('utf-8'))""",
        "replace_call": r'client\.send_perception\("[^"]*",\s*([^)]*)\)',
        "new_call": r'client.send_msg("tell", "external", "orquestrador", \1)'
    },
    "typescript": {
        "files": ["sdk/typescript/src/index.ts", "test/diluvio/typescript/client.ts"],
        "decl": "",
        "impl": """    public sendMsg(performative: string, sender: string, receiver: string, content: string): void {
        const payload = JSON.stringify({ type: 'message', performative, sender, receiver, content }) + '\\n';
        this.socket.write(payload);
    }""",
        "replace_call": r'client\.sendPerception\("[^"]*",\s*([^)]*)\)',
        "new_call": r'client.sendMsg("tell", "external", "orquestrador", \1)'
    },
    "rust": {
        "files": ["sdk/rust/src/lib.rs", "test/diluvio/rust/src/main.rs"],
        "decl": "",
        "impl": """    pub fn send_msg(&self, performative: &str, sender: &str, receiver: &str, content: &str) -> std::io::Result<()> {
        let msg = serde_json::json!({
            "type": "message",
            "performative": performative,
            "sender": sender,
            "receiver": receiver,
            "content": content
        });
        let mut stream = self.stream.as_ref().unwrap().lock().unwrap();
        stream.write_all(format!("{}\\n", msg.to_string()).as_bytes())?;
        stream.flush()
    }""",
        "replace_call": r'client\.send_perception\("[^"]*",\s*([^)]*)\)',
        "new_call": r'client.send_msg("tell", "external", "orquestrador", \1)'
    },
    "ruby": {
        "files": ["sdk/ruby/lib/panteao_client.rb", "test/diluvio/ruby/client.rb"],
        "decl": "",
        "impl": """    def send_msg(performative, sender, receiver, content)
      msg = { type: 'message', performative: performative, sender: sender, receiver: receiver, content: content }
      @socket.puts(msg.to_json)
    end""",
        "replace_call": r'client\.send_perception\([^,]*,[^,]*,\s*([^)]*)\)',
        "new_call": r"client.send_msg('tell', 'external', 'orquestrador', \1)"
    },
    "php": {
        "files": ["sdk/php/src/BdiClient.php", "test/diluvio/php/client.php"],
        "decl": "",
        "impl": """    public function sendMsg(string $performative, string $sender, string $receiver, string $content): void {
        $msg = json_encode(['type' => 'message', 'performative' => $performative, 'sender' => $sender, 'receiver' => $receiver, 'content' => $content]) . "\\n";
        fwrite($this->socket, $msg);
    }""",
        "replace_call": r'->sendPerception\([^,]*,[^,]*,\s*([^)]*)\)',
        "new_call": r"->sendMsg('tell', 'external', 'orquestrador', \1)"
    },
    "dart": {
        "files": ["sdk/dart/lib/panteao_client.dart", "test/diluvio/dart/client.dart"],
        "decl": "",
        "impl": """  void sendMsg(String performative, String sender, String receiver, String content) {
    var msg = jsonEncode({'type': 'message', 'performative': performative, 'sender': sender, 'receiver': receiver, 'content': content});
    _socket?.write('$msg\\n');
  }""",
        "replace_call": r'\.sendPerception\([^,]*,[^,]*,\s*([^)]*)\)',
        "new_call": r".sendMsg('tell', 'external', 'orquestrador', \1)"
    },
    "kotlin": {
        "files": ["sdk/kotlin/src/main/kotlin/io/panteao/BdiClient.kt", "test/diluvio/kotlin/Client.kt"],
        "decl": "",
        "impl": """    fun sendMsg(performative: String, sender: String, receiver: String, content: String) {
        val json = "{\\"type\\":\\"message\\",\\"performative\\":\\"$performative\\",\\"sender\\":\\"$sender\\",\\"receiver\\":\\"$receiver\\",\\"content\\":\\"$content\\"}\\n"
        out.print(json)
        out.flush()
    }""",
        "replace_call": r'\.sendPerception\([^,]*,[^,]*,\s*([^)]*)\)',
        "new_call": r".sendMsg(\"tell\", \"external\", \"orquestrador\", \1)"
    },
    "scala": {
        "files": ["sdk/scala/src/main/scala/io/panteao/BdiClient.scala", "test/diluvio/scala/Client.scala"],
        "decl": "",
        "impl": """  def sendMsg(performative: String, sender: String, receiver: String, content: String): Unit = {
    val json = s\\"\\"\\"{"type":"message","performative":"$performative","sender":"$sender","receiver":"$receiver","content":"$content"}\\n\\"\\"\\"
    out.print(json)
    out.flush()
  }""",
        "replace_call": r'\.sendPerception\([^,]*,[^,]*,\s*([^)]*)\)',
        "new_call": r".sendMsg(\"tell\", \"external\", \"orquestrador\", \1)"
    },
    "r": {
        "files": ["sdk/r/R/client.R", "test/diluvio/r/client.R"],
        "decl": "sendMsg = sendMsg,",
        "impl": """  sendMsg <- function(performative, sender, receiver, content) {
    msg <- jsonlite::toJSON(list(type="message", performative=performative, sender=sender, receiver=receiver, content=content), auto_unbox=TRUE)
    cat(paste0(msg, "\\n"), file=con)
  }""",
        "replace_call": r'\$sendPerception\([^,]*,[^,]*,\s*([^)]*)\)',
        "new_call": r"$sendMsg(\"tell\", \"external\", \"orquestrador\", \1)"
    },
    "swift": {
        "files": ["sdk/swift/Sources/PanteaoClient/BdiClient.swift", "test/diluvio/swift/client.swift"],
        "decl": "",
        "impl": """    public func sendMsg(performative: String, sender: String, receiver: String, content: String) {
        let dict: [String: String] = [
            "type": "message",
            "performative": performative,
            "sender": sender,
            "receiver": receiver,
            "content": content
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let json = String(data: data, encoding: .utf8) {
            let payload = json + "\\n"
            let bytes = Array(payload.utf8)
            outputStream?.write(bytes, maxLength: bytes.count)
        }
    }""",
        "replace_call": r'\.sendPerception\(action:\s*"[^"]*",\s*perception:\s*([^)]*)\)',
        "new_call": r'.sendMsg(performative: "tell", sender: "external", receiver: "orquestrador", content: \1)'
    },
    "objc": {
        "files": ["sdk/objc/include/BdiClient.h", "sdk/objc/src/BdiClient.m", "test/diluvio/objc/client.m"],
        "decl": "- (void)sendMsgWithPerformative:(NSString *)performative sender:(NSString *)sender receiver:(NSString *)receiver content:(NSString *)content;",
        "impl": """- (void)sendMsgWithPerformative:(NSString *)performative sender:(NSString *)sender receiver:(NSString *)receiver content:(NSString *)content {
    NSDictionary *dict = @{
        @"type": @"message",
        @"performative": performative,
        @"sender": sender,
        @"receiver": receiver,
        @"content": content
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *payload = [json stringByAppendingString:@"\\n"];
    [self.outputStream write:(const uint8_t *)[payload UTF8String] maxLength:[payload length]];
}""",
        "replace_call": r'\[client sendPerceptionWithAction:@"[^"]*" perception:([^\]]*)\]',
        "new_call": r'[client sendMsgWithPerformative:@"tell" sender:@"external" receiver:@"orquestrador" content:\1]'
    },
    "shell": {
        "files": ["sdk/shell/panteao_client.sh", "test/diluvio/shell/client.sh"],
        "decl": "",
        "impl": """panteao_send_msg() {
    local perf="$1"
    local sender="$2"
    local receiver="$3"
    local content="$4"
    echo "{\\"type\\":\\"message\\",\\"performative\\":\\"$perf\\",\\"sender\\":\\"$sender\\",\\"receiver\\":\\"$receiver\\",\\"content\\":\\"$content\\"}" >&3
}""",
        "replace_call": r'panteao_send_perception "[^"]*" "([^"]*)"',
        "new_call": r'panteao_send_msg "tell" "external" "orquestrador" "\1"'
    }
}

for lang, data in sdks.items():
    print(f"Refactoring {lang}...")
    for fpath in data["files"]:
        if not os.path.exists(fpath):
            continue
        with open(fpath, "r") as f:
            content = f.read()

        # Update test call
        if "test/diluvio" in fpath:
            content = re.sub(data["replace_call"], data["new_call"], content)

        # Update SDK
        if "sdk/" in fpath:
            if "panteao_send_perception" in content or "sendPerception" in content or "send_perception" in content:
                # Add decl
                if data["decl"]:
                    content = content.replace("int panteao_send_perception(", f"{data['decl']}\\nint panteao_send_perception(")
                    content = content.replace("bool sendPerception(", f"{data['decl']}\\nbool sendPerception(")
                    content = content.replace("sendPerception = sendPerception,", f"{data['decl']}\\nsendPerception = sendPerception,")
                    content = content.replace("- (void)sendPerceptionWithAction", f"{data['decl']}\\n- (void)sendPerceptionWithAction")
                
                # We won't remove sendPerception, just add sendMsg
                # Find the implementation of sendPerception and append sendMsg after it
                # It's tricky to find the end of the method. We can just insert it before sendPerception
                
                if "int panteao_send_perception" in content:
                    content = content.replace("int panteao_send_perception(", f"{data['impl']}\n\nint panteao_send_perception(")
                elif "bool BdiClient::sendPerception" in content:
                    content = content.replace("bool BdiClient::sendPerception(", f"{data['impl']}\n\nbool BdiClient::sendPerception(")
                elif "public void SendPerception(" in content:
                    content = content.replace("public void SendPerception(", f"{data['impl']}\n\n        public void SendPerception(")
                elif "public void sendPerception(" in content:
                    content = content.replace("public void sendPerception(", f"{data['impl']}\n\n    public void sendPerception(")
                elif "def send_perception(" in content:
                    content = content.replace("def send_perception(", f"{data['impl']}\n\n    def send_perception(")
                elif "public sendPerception(" in content:
                    content = content.replace("public sendPerception(", f"{data['impl']}\n\n    public sendPerception(")
                elif "pub fn send_perception(" in content:
                    content = content.replace("pub fn send_perception(", f"{data['impl']}\n\n    pub fn send_perception(")
                elif "def send_perception(" in content:  # ruby
                    content = content.replace("def send_perception(", f"{data['impl']}\n\n    def send_perception(")
                elif "public function sendPerception(" in content:
                    content = content.replace("public function sendPerception(", f"{data['impl']}\n\n    public function sendPerception(")
                elif "void sendPerception(" in content: # dart
                    content = content.replace("void sendPerception(", f"{data['impl']}\n\n  void sendPerception(")
                elif "fun sendPerception(" in content: # kotlin
                    content = content.replace("fun sendPerception(", f"{data['impl']}\n\n    fun sendPerception(")
                elif "def sendPerception(" in content: # scala
                    content = content.replace("def sendPerception(", f"{data['impl']}\n\n  def sendPerception(")
                elif "sendPerception <- function(" in content: # r
                    content = content.replace("sendPerception <- function(", f"{data['impl']}\n\n  sendPerception <- function(")
                elif "public func sendPerception(" in content: # swift
                    content = content.replace("public func sendPerception(", f"{data['impl']}\n\n    public func sendPerception(")
                elif "- (void)sendPerceptionWithAction" in content: # objc
                    content = content.replace("- (void)sendPerceptionWithAction", f"{data['impl']}\n\n- (void)sendPerceptionWithAction")
                elif "panteao_send_perception()" in content: # shell
                    content = content.replace("panteao_send_perception()", f"{data['impl']}\n\npanteao_send_perception()")

        with open(fpath, "w") as f:
            f.write(content)

print("Done")
