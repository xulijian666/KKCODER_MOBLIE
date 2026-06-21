import 'dart:async';
import 'package:flutter/foundation.dart';
import 'websocket_service.dart';

class TerminalService extends ChangeNotifier {
  final WebSocketService _ws;
  final _buffer = StringBuffer();
  Timer? _flushTimer;
  String _output = '';

  TerminalService(this._ws) {
    _ws.output.listen(_onData);
    _startFlushTimer();
  }

  String get output => _output;
  Stream<WsState> get connectionState => _ws.stateStream;

  void _onData(String data) {
    _buffer.write(data);
  }

  void _startFlushTimer() {
    _flushTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _flush(),
    );
  }

  void _flush() {
    if (_buffer.isEmpty) return;
    final chunk = _buffer.toString();
    _buffer.clear();
    _output += chunk;
    if (_output.length > 100000) {
      _output = _output.substring(_output.length - 80000);
    }
    notifyListeners();
  }

  void sendInput(String text) {
    _ws.sendInput(text);
  }

  void sendResize(int cols, int rows) {
    _ws.sendResize(cols, rows);
  }

  void clear() {
    _output = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }
}
