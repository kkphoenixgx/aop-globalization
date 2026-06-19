# Client BDI Coprocessor - Rust

Rust TCP client using std::net::TcpStream.

## Protocol Interaction Example

```rs
use std::net::TcpStream;
use std::io::Write;
fn main() -> std::io::Result<()> {
    let mut stream = TcpStream::connect("127.0.0.1:40000")?;
    stream.write_all(b"{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"test_percept\"}\n")?;
    Ok(())
}
```
