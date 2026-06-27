import 'dart:io';
import 'dart:convert';
import 'dart:async';

class Panteao {
  late Socket _socket;
  final String host;
  int port;
  final String? project;
  Process? _process;
  final Map<String, Function(List<String> args, Function(bool success) respond)> _handlers = {};
  bool _running = false;
  final String sdkVersion = '1.0.0';

  Panteao({this.host = '127.0.0.1', this.port = 0, this.project});

  static Future<int> getFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<String> _downloadEngine() async {
    final isWin = Platform.isWindows;
    final osName = isWin ? 'win32' : (Platform.isMacOS ? 'darwin' : 'linux');
    final arch = (Platform.version.toLowerCase().contains('arm') || Platform.version.toLowerCase().contains('aarch64')) ? 'arm64' : 'x64';
    
    final pkgName = 'panteao-engine-$osName-$arch';
    final binName = isWin ? 'panteao-engine.exe' : 'panteao-engine';
    
    final scriptDir = File(Platform.script.toFilePath()).parent.path;
    final binPath = '$scriptDir/$binName';
    
    if (FileSystemEntity.typeSync(binPath) != FileSystemEntityType.notFound) {
      return binPath;
    }

    print('[Panteao] Downloading native engine for $osName-$arch (v$sdkVersion)...');
    
    final url = Uri.parse('https://registry.npmjs.org/$pkgName/-/$pkgName-$sdkVersion.tgz');
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(url);
    final response = await request.close();
    
    final tarPath = '$scriptDir/engine.tgz';
    await response.pipe(File(tarPath).openWrite());
    
    if (isWin) {
      await Process.run('tar', ['-xf', tarPath, '-C', scriptDir]);
    } else {
      await Process.run('tar', ['-xzf', tarPath, '-C', scriptDir]);
      await Process.run('chmod', ['+x', binPath]);
    }
    
    try {
      File(tarPath).deleteSync();
      // Move from package folder if it extracts into a subfolder
      final extractedBin = '$scriptDir/package/bin/$binName';
      if (FileSystemEntity.typeSync(extractedBin) != FileSystemEntityType.notFound) {
        File(extractedBin).renameSync(binPath);
        Directory('$scriptDir/package').deleteSync(recursive: true);
      }
    } catch (_) {}
    
    print('[Panteao] Engine downloaded successfully.');
    return binPath;
  }

  Future<void> connect() async {
    if (project != null) {
      if (port == 0) {
        port = await getFreePort();
      }
      final bin = await _downloadEngine();
      _process = await Process.start(bin, [project!, '--port', port.toString()]);
      
      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_readLog);
      _process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(_readLog);
      
      await Future.delayed(const Duration(milliseconds: 800));
    } else if (port == 0) {
      port = 44444;
    }

    _socket = await Socket.connect(host, port);
    _running = true;

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
          _running = false;
        });

    await completer.future;
  }

  void _readLog(String line) {
    if (line.trim().isEmpty) return;
    final regex = RegExp(r'^\[(.*?)\]\s(.*)');
    final match = regex.firstMatch(line);
    if (match != null) {
      final name = match.group(1)!.split('.').last;
      print('\x1B[36m[$name]\x1B[0m ${match.group(2)}');
    } else {
      print('\x1B[36m[MAS]\x1B[0m $line');
    }
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
    var msg = jsonEncode({'type': 'message', 'ilf': performative, 'sender': sender, 'receiver': receiver, 'message': content});
    _socket.write('$msg\n');
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

  Future<void> wait() async {
    while (_running) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void close() {
    _running = false;
    _socket.destroy();
    _process?.kill();
  }
}

class _ParsedAction {
  final String name;
  final List<String> args;
  _ParsedAction(this.name, this.args);
}
