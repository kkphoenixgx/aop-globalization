import 'dart:io';
import 'dart:convert';
void main() async {
  var socket = await Socket.connect("127.0.0.1", 40000);
  socket.write(jsonEncode({"type": "perception", "action": "add", "perception": "test_percept"}) + "\n");
  await socket.close();
}