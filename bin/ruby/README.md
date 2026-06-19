# Client BDI Coprocessor - Ruby

Ruby TCP client using TCPSocket.

## Protocol Interaction Example

```rb
require 'socket'
require 'json'
s = TCPSocket.new '127.0.0.1', 40000
s.puts({"type" => "perception", "action" => "add", "perception" => "test_percept"}.to_json)
s.close
```
