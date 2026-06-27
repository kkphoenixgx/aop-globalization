import 'package:panteao/panteao.dart';

void main() async {
  print("Iniciando Panteao no Dart...");
  
  final engine = Panteao(host: '127.0.0.1', port: 0, project: './project.jcm');
  await engine.connect();
  
  engine.registerAction('turn_on_ac', (args, respond) {
    print("Action received! Turning on AC.");
    engine.sendMsg('tell', 'sensor', 'bob', 'ac_status(on)');
    respond(true); // Action successful
  });

  print("teste log da minha aplicação Dart");
  
  await engine.wait();
}
