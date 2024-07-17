import 'package:learn_dart_robust_ports_example/learn_dart_robust_ports_example.dart';

void main(List<String> arguments) async {
  final worker = await Worker.spawn();
  print(await worker.parseJson('{"key": "value"}'));
  print(await worker.parseJson('"banana"'));
  print(await worker.parseJson('[true, false, null, 1, "string"]'));
  print(await worker.parseJson('{"key": "value"}'));
  print(
      await Future.wait([worker.parseJson('"yes"'), worker.parseJson('"no"')]));
  worker.close();
}
