# Client BDI Coprocessor - Python

Python Client using standard socket and json libraries.

## Protocol Interaction Example

```py
import socket, json
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('127.0.0.1', 40000))
sock.sendall((json.dumps({'type': 'perception', 'action': 'add', 'perception': 'test_percept'}) + '\n').encode())
```
