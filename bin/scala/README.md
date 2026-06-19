# Client BDI Coprocessor - Scala

Scala Socket client.

## Protocol Interaction Example

```scala
import java.net.Socket
import java.io.PrintWriter
object Client extends App {
  val socket = new Socket("127.0.0.1", 40000)
  val out = new PrintWriter(socket.getOutputStream, true)
  out.println("""{"type":"perception","action":"add","perception":"test_percept"}""")
  socket.close()
}
```
