# Client BDI Coprocessor - C

Low-level C socket client for embedded and systems programming.

## Protocol Interaction Example

```c
#include <stdio.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
int main() {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr = {AF_INET, htons(40000)};
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);
    connect(sock, (struct sockaddr*)&addr, sizeof(addr));
    char* msg = "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"test_percept\"}\n";
    send(sock, msg, 70, 0);
    close(sock);
    return 0;
}
```
