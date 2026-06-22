import 'dart:io';
import 'package:panteao_client/panteao_client.dart';

void main() async {
  print('[DILUVIO] Dart client starting');
  final client = BdiClient(host: '127.0.0.1', port: 44444);

  Future.delayed(Duration(seconds: 5), () {
    print('[DILUVIO] TIMEOUT');
    client.close();
    exit(1);
  });

  client.registerAction('update_rescue_map', (args, respond) {
    print('[DILUVIO] Action handled: update_rescue_map');
    respond(true);
    print('[DILUVIO] SUCCESS');
    client.close();
    exit(0);
  });

  try {
    await client.connect();
    print('[DILUVIO] Connected!');
    client.sendMsg('tell', 'external', 'orquestrador', 'rescue_coordinates(-22.91,-43.18)');
  } catch (e) {
    print('[DILUVIO] FAILURE: $e');
    exit(1);
  }
}
