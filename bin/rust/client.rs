use std::net::TcpStream;
use std::io::Write;
use serde::Serialize;

#[derive(Serialize)]
struct Perception {
    #[serde(rename = "type")]
    msg_type: String,
    action: String,
    perception: String,
}

fn main() -> std::io::Result<()> {
    let mut stream = TcpStream::connect("127.0.0.1:40000")?;
    println!("[Rust Client] Connected to Panteao BDI Engine!");
    
    let percept = Perception {
        msg_type: "perception".to_string(),
        action: "add".to_string(),
        perception: "test_percept".to_string(),
    };
    let payload = serde_json::to_string(&percept).unwrap() + "\n";
    stream.write_all(payload.as_bytes())?;
    Ok(())
}
