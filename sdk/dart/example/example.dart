import 'package:panteao/panteao.dart';

void main() async {
  // Initialize the Panteão engine and auto-spawn the BDI coprocessor
  final engine = Panteao(host: '127.0.0.1', port: 0, project: './project.jcm');
  
  // Connect via sockets
  await engine.connect();
  
  // Register an action that the BDI agent might request
  engine.registerAction('turn_on_ac', (args, respond) {
    print("Action received! Turning on AC in ${args[0]}");
    
    // Send a perception back to the agent
    engine.sendMsg('tell', 'sensor', 'bob', 'ac_status(on)');
    
    // Acknowledge the action was successful
    respond(true);
  });

  // Block the main thread while the simulation runs
  await engine.wait();
}
