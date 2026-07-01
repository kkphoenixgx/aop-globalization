use std::net::{TcpStream, TcpListener};
use std::io::{BufRead, BufReader, Write};
use std::sync::{Arc, Mutex};
use std::thread;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::env;
use serde::{Deserialize, Serialize};

use std::io::Read;
use flate2::read::GzDecoder;
use tar::Archive;

const VERSION: &str = "1.1.16";

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


fn download_engine(bin_path: &PathBuf) -> std::io::Result<()> {
    let is_win = cfg!(target_os = "windows");
    let is_mac = cfg!(target_os = "macos");
    let os_name = if is_win { "win32" } else if is_mac { "darwin" } else { "linux" };
    
    let arch = if cfg!(target_arch = "aarch64") || cfg!(target_arch = "arm") { "arm64" } else { "x64" };
    
    let pkg_name = format!("panteao-engine-{}-{}", os_name, arch);
    let url = format!("https://registry.npmjs.org/{}/-/{}-{}.tgz", pkg_name, pkg_name, VERSION);
    
    println!("\x1b[36m[Panteao]\x1b[0m Downloading native engine for {}-{} (v{})...", os_name, arch, VERSION);
    
    let response = ureq::get(&url).call().map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))?;
    
    let tar = GzDecoder::new(response.into_reader());
    let mut archive = Archive::new(tar);
    
    for file in archive.entries()? {
        let mut file = file?;
        let path = file.path()?.into_owned();
        let path_str = path.to_string_lossy();
        
        if path_str.ends_with("panteao-engine") || path_str.ends_with("panteao-engine.exe") {
            if let Some(parent) = bin_path.parent() {
                std::fs::create_dir_all(parent)?;
            }
            let mut out = std::fs::File::create(bin_path)?;
            std::io::copy(&mut file, &mut out)?;
            
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut perms = std::fs::metadata(bin_path)?.permissions();
                perms.set_mode(0o755);
                std::fs::set_permissions(bin_path, perms)?;
            }
            return Ok(());
        }
    }
    
    Err(std::io::Error::new(std::io::ErrorKind::NotFound, "Binary not found in tarball"))
}

fn read_logs(reader: impl std::io::Read + Send + 'static) {
    std::thread::spawn(move || {
        let buf_reader = BufReader::new(reader);
        for line in buf_reader.lines() {
            if let Ok(line) = line {
                let trimmed = line.trim();
                if trimmed.is_empty() {
                    continue;
                }
                if let (Some(idx1), Some(idx2)) = (trimmed.find('['), trimmed.find(']')) {
                    if idx1 == 0 && idx2 > 0 {
                        let name = &trimmed[1..idx2];
                        let parts: Vec<&str> = name.split('.').collect();
                        let short_name = parts.last().unwrap_or(&name);
                        println!("\x1b[36m[{}]\x1b[0m {}", short_name, &trimmed[idx2 + 2..]);
                    } else {
                        println!("\x1b[36m[MAS]\x1b[0m {}", trimmed);
                    }
                } else {
                    println!("\x1b[36m[MAS]\x1b[0m {}", trimmed);
                }
            }
        }
    });
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
            let mut bin = find_binary();
            if !bin.exists() {
                let exe_dir = env::current_exe()?.parent().unwrap().to_path_buf();
                bin = exe_dir.join(if cfg!(target_os = "windows") { "panteao-engine.exe" } else { "panteao-engine" });
                download_engine(&bin)?;
            }
            
            let mut child = std::process::Command::new(&bin)
                .arg(proj_path)
                .arg("--port")
                .arg(port.to_string())
                .stdout(std::process::Stdio::piped())
                .stderr(std::process::Stdio::piped())
                .spawn()?;
                
            let stdout = child.stdout.take().unwrap();
            let stderr = child.stderr.take().unwrap();
            read_logs(stdout);
            read_logs(stderr);
            
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
