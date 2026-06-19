import 'dart:io';
import 'dart:convert';

void main() async {
  final host = '127.0.0.1';
  final port = 44444;
  final start = DateTime.now();

  print('[DILUVIO] Dart client starting');
  try {
    final socket = await Socket.connect(host, port);
    print('[DILUVIO] Connected in ${DateTime.now().difference(start).inMilliseconds}ms');

    // Wait 1s
    await Future.delayed(Duration(seconds: 1));

    // Send perception
    final percept = '{"type":"perception","action":"add","perception":"rescue_coordinates(-22.91,-43.18)"}\n';
    print('[DILUVIO] Sending: $percept');
    socket.write(percept);

    // Listen
    await for (var data in socket.cast<List<int>>().transform(utf8.decoder).transform(LineSplitter())) {
      print('[DILUVIO] Received: $data');
      if (data.contains('"type":"action"')) {
        final Map<String, dynamic> msg = jsonDecode(data);
        final id = msg['id'];
        final response = '{"type":"action_result","id":"$id","success":true}\n';
        print('[DILUVIO] Sending result: $response');
        socket.write(response);
        print('[DILUVIO] SUCCESS');
        break;
      }
    }
    await socket.close();
  } catch (e) {
    print('[DILUVIO] FAILURE: $e');
    exit(1);
  }
}
