use std::net::{TcpStream, TcpListener};
use std::io::{BufRead, BufReader, Write};
use std::sync::{Arc, Mutex};
use std::thread;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::env;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
struct PerceptionMessage {
    r#type: String,
    action: String,
    perception: String,
}

#[derive(Deserialize, Debug)]
struct ActionRequest {
    r#type: String,
    id: String,
    agent: String,
    action: String,
}

#[derive(Serialize, Debug)]
struct ActionResult {
    r#type: String,
    id: String,
    success: bool,
}

pub type ActionCallback = Box<dyn Fn(&[String], Box<dyn FnOnce(bool) + Send>) + Send + Sync>;

pub struct BdiClient {
    stream: Arc<Mutex<TcpStream>>,
    handlers: Arc<Mutex<HashMap<String, ActionCallback>>>,
    running: Arc<Mutex<bool>>,
    process: Option<Arc<Mutex<std::process::Child>>>,
}

fn get_free_port() -> std::io::Result<u16> {
    let listener = TcpListener::bind("127.0.0.1:0")?;
    Ok(listener.local_addr()?.port())
}

fn find_binary() -> PathBuf {
    let is_win = cfg!(target_os = "windows");
    let bin_name = if is_win { "panteao-engine.exe" } else { "panteao-engine" };
    
    if let Ok(exe_path) = env::current_exe() {
        if let Some(exe_dir) = exe_path.parent() {
            let cand1 = exe_dir.join(bin_name);
            if cand1.exists() { return cand1; }
            let cand2 = exe_dir.join("bin").join(bin_name);
            if cand2.exists() { return cand2; }
        }
    }
    
    if let Ok(cwd) = env::current_dir() {
        let cand1 = cwd.join(bin_name);
        if cand1.exists() { return cand1; }
        let cand2 = cwd.join("bin").join(bin_name);
        if cand2.exists() { return cand2; }
    }
    
    PathBuf::from(bin_name)
}

impl BdiClient {
    pub fn connect(addr: &str) -> std::io::Result<Self> {
        Self::connect_with_project(addr, None)
    }

    pub fn connect_with_project(addr: &str, project: Option<&str>) -> std::io::Result<Self> {
        let mut port = 0;
        let mut host = "127.0.0.1".to_string();
        if let Some(pos) = addr.find(':') {
            host = addr[..pos].to_string();
            if let Ok(p) = addr[pos+1..].parse::<u16>() {
                port = p;
            }
        } else if let Ok(p) = addr.parse::<u16>() {
            port = p;
        }

        let mut child_proc = None;
        if let Some(proj_path) = project {
            if port == 0 {
                port = get_free_port()?;
            }
            let bin = find_binary();
            let child = std::process::Command::new(bin)
                .arg(proj_path)
                .arg("--port")
                .arg(port.to_string())
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn()?;
            child_proc = Some(Arc::new(Mutex::new(child)));
            std::thread::sleep(std::time::Duration::from_millis(800));
        } else if port == 0 {
            port = 44444;
        }

        let dial_addr = format!("{}:{}", host, port);
        let stream = TcpStream::connect(dial_addr)?;
        
        let mut handshake_reader = BufReader::new(stream.try_clone()?);
        let mut line = String::new();
        loop {
            line.clear();
            if handshake_reader.read_line(&mut line)? == 0 {
                return Err(std::io::Error::new(std::io::ErrorKind::ConnectionAborted, "Connection closed during handshake"));
            }
            if let Ok(msg) = serde_json::from_str::<serde_json::Value>(&line) {
                if let Some(t) = msg.get("type") {
                    if t == "mas_ready" {
                        break;
                    }
                }
            }
        }

        let client = Self {
            stream: Arc::new(Mutex::new(stream)),
            handlers: Arc::new(Mutex::new(HashMap::new())),
            running: Arc::new(Mutex::new(true)),
            process: child_proc,
        };
        client.start_listener();
        Ok(client)
    }

        pub fn send_msg(&self, performative: &str, sender: &str, receiver: &str, content: &str) -> std::io::Result<()> {
        let msg = serde_json::json!({
            "type": "message",
            "performative": performative,
            "sender": sender,
            "receiver": receiver,
            "content": content
        });
        let mut stream = self.stream.lock().unwrap();
        stream.write_all(format!("{}\n", msg.to_string()).as_bytes())?;
        stream.flush()
    }

    pub fn send_perception(&self, action: &str, perception: &str) -> std::io::Result<()> {
        let msg = PerceptionMessage {
            r#type: "perception".to_string(),
            action: action.to_string(),
            perception: perception.to_string(),
        };
        let mut payload = serde_json::to_string(&msg).unwrap();
        payload.push('\n');
        let mut s = self.stream.lock().unwrap();
        s.write_all(payload.as_bytes())?;
        s.flush()?;
        Ok(())
    }

    pub fn register_action<F>(&self, action_name: &str, callback: F)
    where
        F: Fn(&[String], Box<dyn FnOnce(bool) + Send>) + Send + Sync + 'static,
    {
        self.handlers.lock().unwrap().insert(action_name.to_string(), Box::new(callback));
    }

    fn start_listener(&self) {
        let stream_clone = Arc::clone(&self.stream);
        let handlers_clone = Arc::clone(&self.handlers);
        let running_clone = Arc::clone(&self.running);

        thread::spawn(move || {
            let reader_stream = stream_clone.lock().unwrap().try_clone().unwrap();
            let mut reader = BufReader::new(reader_stream);
            let mut line = String::new();

            while *running_clone.lock().unwrap() {
                line.clear();
                if reader.read_line(&mut line).is_err() || line.is_empty() {
                    break;
                }
                
                if let Ok(req) = serde_json::from_str::<ActionRequest>(&line) {
                    if req.r#type == "action" {
                        let (name, args) = parse_action(&req.action);
                        let handlers = handlers_clone.lock().unwrap();
                        
                        if let Some(handler) = handlers.get(&name) {
                            let action_id = req.id.clone();
                            let s_clone = Arc::clone(&stream_clone);
                            let respond = Box::new(move |success: bool| {
                                let res = ActionResult {
                                    r#type: "action_result".to_string(),
                                    id: action_id,
                                    success,
                                };
                                let mut payload = serde_json::to_string(&res).unwrap();
                                payload.push('\n');
                                if let Ok(mut s) = s_clone.lock() {
                                    let _ = s.write_all(payload.as_bytes());
                                    let _ = s.flush();
                                }
                            });
                            handler(&args, respond);
                        } else {
                            let res = ActionResult {
                                r#type: "action_result".to_string(),
                                id: req.id,
                                success: true,
                            };
                            let mut payload = serde_json::to_string(&res).unwrap();
                            payload.push('\n');
                            if let Ok(mut s) = stream_clone.lock() {
                                let _ = s.write_all(payload.as_bytes());
                                let _ = s.flush();
                            }
                        }
                    }
                }
            }
        });
    }

    pub fn close(&self) {
        *self.running.lock().unwrap() = false;
        if let Some(ref proc_mutex) = self.process {
            if let Ok(mut child) = proc_mutex.lock() {
                let _ = child.kill();
            }
        }
    }
}

impl Drop for BdiClient {
    fn drop(&mut self) {
        self.close();
    }
}

fn parse_action(action_str: &str) -> (String, Vec<String>) {
    if let Some(paren_idx) = action_str.find('(') {
        let name = action_str[..paren_idx].trim().to_string();
        if let Some(end_paren) = action_str.rfind(')') {
            let args_str = &action_str[paren_idx + 1..end_paren];
            let mut args = Vec::new();
            let mut current = String::new();
            let mut inside_quotes = false;
            let mut depth_brackets = 0;
            let mut depth_parens = 0;
            for c in args_str.chars() {
                if c == '"' {
                    inside_quotes = !inside_quotes;
                    current.push(c);
                } else if !inside_quotes && c == '[' {
                    depth_brackets += 1;
                    current.push(c);
                } else if !inside_quotes && c == ']' {
                    depth_brackets -= 1;
                    current.push(c);
                } else if !inside_quotes && c == '(' {
                    depth_parens += 1;
                    current.push(c);
                } else if !inside_quotes && c == ')' {
                    depth_parens -= 1;
                    current.push(c);
                } else if c == ',' && !inside_quotes && depth_brackets == 0 && depth_parens == 0 {
                    args.push(clean_arg(&current));
                    current.clear();
                } else {
                    current.push(c);
                }
            }
            if !current.trim().is_empty() {
                args.push(clean_arg(&current));
            }
            return (name, args);
        }
    }
    (action_str.trim().to_string(), Vec::new())
}

fn clean_arg(arg: &str) -> String {
    let s = arg.trim();
    if s.starts_with('"') && s.ends_with('"') && s.len() >= 2 {
        s[1..s.len() - 1].to_string()
    } else {
        s.to_string()
    }
}
