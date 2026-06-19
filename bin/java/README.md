# Client BDI Coprocessor - Java

Java TCP socket client using Socket class.

## Protocol Interaction Example

```java
import java.io.*;
import java.net.Socket;
public class BDIClient {
    public static void main(String[] args) throws Exception {
        Socket socket = new Socket("127.0.0.1", 40000);
        PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
        out.println("{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"test_percept\"}");
        socket.close();
    }
}
```
