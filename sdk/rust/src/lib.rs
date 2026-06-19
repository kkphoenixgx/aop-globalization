use std::net::TcpStream;
use std::io::{BufRead, BufReader, Write};
use std::sync::{Arc, Mutex};
use std::thread;
use std::collections::HashMap;
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
}

impl BdiClient {
    pub fn connect(addr: &str) -> std::io::Result<Self> {
        let stream = TcpStream::connect(addr)?;
        let client = Self {
            stream: Arc::new(Mutex::new(stream)),
            handlers: Arc::new(Mutex::new(HashMap::new())),
            running: Arc::new(Mutex::new(true)),
        };
        client.start_listener();
        Ok(client)
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
        let stream_clone = Arc.clone(&self.stream);
        let handlers_clone = Arc.clone(&self.handlers);
        let running_clone = Arc.clone(&self.running);

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
                            let s_clone = Arc.clone(&stream_clone);
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
                            // Auto-succeed
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
            for c in args_str.chars() {
                if c == '"' {
                    inside_quotes = !inside_quotes;
                } else if c == ',' && !inside_quotes {
                    args.push(clean_arg(&current));
                    current.clear();
                } else {
                    current.push(c);
                }
            }
            if !current.is_empty() {
                args.push(clean_arg(&current));
            }
            return (name, args);
        }
    }
    (action_str.trim().to_string(), Vec::new())
}

fn clean_arg(arg: &str) -> String {
    arg.trim().trim_matches('"').to_string()
}
