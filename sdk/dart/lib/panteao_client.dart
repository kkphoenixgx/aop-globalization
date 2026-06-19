import 'dart:io';
import 'dart:convert';
import 'dart:async';

class BdiClient {
  late Socket _socket;
  final String host;
  final int port;
  final Map<String, Function(List<String> args, Function(bool success) respond)> _handlers = {};

  BdiClient({this.host = '127.0.0.1', this.port = 44444});

  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    _socket
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .listen(_handleIncomingLine, onError: (err) {});
  }

  void _handleIncomingLine(String line) {
    try {
      final msg = jsonDecode(line) as Map<String, dynamic>;
      if (msg['type'] == 'action') {
        final rawAction = msg['action'] as String;
        final id = msg['id'] as String;
        final parsed = _parseAction(rawAction);
        
        final handler = _handlers[parsed.name];
        if (handler != null) {
          handler(parsed.args, (success) => _sendActionResult(id, success));
        } else {
          _sendActionResult(id, true);
        }
      }
    } catch (_) {}
  }

  _ParsedAction _parseAction(String actionStr) {
    final parenIdx = actionStr.indexOf('(');
    if (parenIdx == -1) {
      return _ParsedAction(actionStr.trim(), []);
    }
    final name = actionStr.substring(0, parenIdx).trim();
    final argsStr = actionStr.substring(parenIdx + 1, actionStr.lastIndexOf(')'));
    
    final args = <String>[];
    final current = StringBuffer();
    bool insideQuotes = false;
    for (int i = 0; i < argsStr.length; i++) {
      final char = argsStr[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == ',' && !insideQuotes) {
        args.add(_cleanArg(current.toString()));
        current.clear();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) {
      args.add(_cleanArg(current.toString()));
    }
    return _ParsedAction(name, args);
  }

  String _cleanArg(String arg) {
    return arg.trim().replaceAll(RegExp(r'^"|"$'), '');
  }

  void sendPerception(String action, String perception) {
    final payload = jsonEncode({
      'type': 'perception',
      'action': action,
      'perception': perception,
    });
    _socket.write('$payload\n');
  }

  void registerAction(String actionName, Function(List<String> args, Function(bool success) respond) callback) {
    _handlers[actionName] = callback;
  }

  void _sendActionResult(String id, bool success) {
    final payload = jsonEncode({
      'type': 'action_result',
      'id': id,
      'success': success,
    });
    _socket.write('$payload\n');
  }

  void close() {
    _socket.destroy();
  }
}

class _ParsedAction {
  final String name;
  final List<String> args;
  _ParsedAction(this.name, this.args);
}
