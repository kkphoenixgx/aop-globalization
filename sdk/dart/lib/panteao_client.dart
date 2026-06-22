import 'dart:io';
import 'dart:convert';
import 'dart:async';

class BdiClient {
  late Socket _socket;
  final String host;
  int port;
  final String? project;
  Process? _process;
  final Map<String, Function(List<String> args, Function(bool success) respond)> _handlers = {};

  BdiClient({this.host = '127.0.0.1', this.port = 0, this.project});

  static Future<int> getFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static String findBinary() {
    final isWin = Platform.isWindows;
    final binName = isWin ? 'panteao-engine.exe' : 'panteao-engine';
    
    try {
      final scriptDir = File(Platform.script.toFilePath()).parent.path;
      final cand1 = '$scriptDir/$binName';
      if (FileSystemEntity.typeSync(cand1) != FileSystemEntityType.notFound) return cand1;
      final cand2 = '$scriptDir/bin/$binName';
      if (FileSystemEntity.typeSync(cand2) != FileSystemEntityType.notFound) return cand2;
    } catch (_) {}
    
    final cwd = Directory.current.path;
    final cand3 = '$cwd/$binName';
    if (FileSystemEntity.typeSync(cand3) != FileSystemEntityType.notFound) return cand3;
    final cand4 = '$cwd/bin/$binName';
    if (FileSystemEntity.typeSync(cand4) != FileSystemEntityType.notFound) return cand4;
    
    return binName;
  }

  Future<void> connect() async {
    if (project != null) {
      if (port == 0) {
        port = await getFreePort();
      }
      final bin = findBinary();
      _process = await Process.start(bin, [project!, '--port', port.toString()]);
      await Future.delayed(const Duration(milliseconds: 800));
    } else if (port == 0) {
      port = 44444;
    }

    _socket = await Socket.connect(host, port);

    final completer = Completer<void>();
    var handshakeBuffer = '';
    
    _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (!completer.isCompleted) {
            handshakeBuffer += line;
            if (handshakeBuffer.contains('"type":"mas_ready"')) {
              completer.complete();
            }
          } else {
            if (line.trim().isNotEmpty) {
              _handleIncomingLine(line);
            }
          }
        }, onError: (err) {
          if (!completer.isCompleted) completer.completeError(err);
        }, onDone: () {
          if (!completer.isCompleted) completer.completeError(Exception('Disconnected during handshake'));
        });

    await completer.future;
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
    int depthBrackets = 0;
    int depthParens = 0;
    for (int i = 0; i < argsStr.length; i++) {
      final char = argsStr[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
        current.write(char);
      } else if (!insideQuotes && char == '[') {
        depthBrackets++;
        current.write(char);
      } else if (!insideQuotes && char == ']') {
        depthBrackets--;
        current.write(char);
      } else if (!insideQuotes && char == '(') {
        depthParens++;
        current.write(char);
      } else if (!insideQuotes && char == ')') {
        depthParens--;
        current.write(char);
      } else if (char == ',' && !insideQuotes && depthBrackets == 0 && depthParens == 0) {
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
    final s = arg.trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

    void sendMsg(String performative, String sender, String receiver, String content) {
    var msg = jsonEncode({'type': 'message', 'performative': performative, 'sender': sender, 'receiver': receiver, 'content': content});
    _socket?.write('$msg\n');
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
    _process?.kill();
  }
}

class _ParsedAction {
  final String name;
  final List<String> args;
  _ParsedAction(this.name, this.args);
}
