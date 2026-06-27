# Panteão (Dart SDK)

Panteão is a lightweight SDK to integrate the Panteão BDI (Belief-Desire-Intention) engine natively into your Dart applications.

## Usage

```dart
import 'package:panteao/panteao.dart';

void main() async {
  final engine = Panteao(host: '127.0.0.1', port: 0, project: './project.jcm');
  await engine.connect();
  
  engine.registerAction('turn_on_ac', (args, respond) {
    print("Action received!");
    engine.sendMsg('tell', 'sensor', 'bob', 'ac_status(on)');
    respond(true);
  });

  await engine.wait();
}
```

See [aop-globalization repository](https://github.com/kkphoenixgx/aop-globalization) for the full architecture.
