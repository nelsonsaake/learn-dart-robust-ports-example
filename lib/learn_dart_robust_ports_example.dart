import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

class Worker {
  final SendPort _commands;
  final ReceivePort _responses;
  final Map<int, Completer<Object?>> _activeRequests = {};
  int _idCounter = 0;
  bool _closed = false;
  static const shutdownCommand = "shutdown";

  Future<Object?> parseJson(String message) async {
    if (_closed) throw StateError("Closed");
    final completer = Completer<Object?>();
    final id = _idCounter++;
    _activeRequests[id] = completer;
    _commands.send((id, message));
    return await completer.future;
  }

  static Future<Worker> spawn() async {
    // Create a receive port and add its initial message handler.
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final command = initialMessage as SendPort;
      connection.complete((
        ReceivePort.fromRawReceivePort(initPort),
        command,
      ));
    };

    // spawn an isolate
    try {
      await Isolate.spawn(_startRemoteIsolate, initPort.sendPort);
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;

    return Worker._(receivePort, sendPort);
  }

  void close() {
    if (!_closed) {
      _closed = true;
      _commands.send(shutdownCommand);
      if (_activeRequests.isEmpty) _responses.close();
      print("--- port closed ---");
    }
  }

  Worker._(this._responses, this._commands) {
    _responses.listen(_handleResponsesFromIsolate);
  }

  void _handleResponsesFromIsolate(message) {
    final (int id, response) = message;
    final completer = _activeRequests[id];
    if (response is RemoteError) {
      completer?.completeError(response);
    } else {
      completer?.complete(response as Object?);
    }
  }

  static void _handleCommandsToIsolate(
      ReceivePort receivePort, SendPort sendPort) async {
    receivePort.listen((message) {
      //...

      if (message == shutdownCommand) {
        receivePort.close();
        return;
      }

      final (int id, jsonText) = message;
      try {
        final jsonData = jsonDecode(jsonText as String);
        sendPort.send((id, jsonData));
      } catch (e) {
        sendPort.send((id, RemoteError(e.toString(), '')));
      }
    });
  }

  static void _startRemoteIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    _handleCommandsToIsolate(receivePort, sendPort);
  }
}
