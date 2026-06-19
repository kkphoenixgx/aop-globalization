# Client BDI Coprocessor - Shell

Bash / Shell client using nc (netcat) or bash dev-tcp.

## Protocol Interaction Example

```sh
#!/bin/bash
# Send perception using netcat
echo '{"type":"perception","action":"add","perception":"test_percept"}' | nc localhost 40000
```
