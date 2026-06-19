# Client BDI Coprocessor - Go

Go (Golang) TCP client.

## Protocol Interaction Example

```go
package main
import (
    "net"
    "fmt"
)
func main() {
    conn, _ := net.Dial("tcp", "127.0.0.1:40000")
    fmt.Fprintf(conn, "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"test_percept\"}\n")
    conn.Close()
}
```
