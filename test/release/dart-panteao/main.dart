import 'package:panteao/panteao.dart';
void main() async {
  final engine = Panteao(project: './project.jcm');
  await engine.connect();
  await engine.wait();
}