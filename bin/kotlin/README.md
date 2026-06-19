# Client BDI Coprocessor - Kotlin

Kotlin TCP client using java.net.Socket.

## Protocol Interaction Example

```kt
import java.net.Socket
import java.io.PrintWriter
fun main() {
    val socket = Socket("127.0.0.1", 40000)
    val out = PrintWriter(socket.getOutputStream(), true)
    out.println("{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"test_percept\"}")
    socket.close()
}
```
