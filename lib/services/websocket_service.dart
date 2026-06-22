import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsState { disconnected, connecting, connected }

class WebSocketService {
  WebSocketChannel? _channel;
  WsState _state = WsState.disconnected;
  int _lastSeq = 0;
  Timer? _reconnectTimer;
  final _outputController = StreamController<String>.broadcast();
  final _stateController = StreamController<WsState>.broadcast();

  Stream<String> get output => _outputController.stream;
  Stream<WsState> get stateStream => _stateController.stream;
  WsState get connectionState => _state;
  int get lastSeq => _lastSeq;

  void connect(String url) {
    disconnect();
    _setState(WsState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.ready.then((_) {
        _setState(WsState.connected);
        // 新连接 lastSeq=0 会获取所有缓冲输出，断线重连会补发缺失部分
        send(jsonEncode({'type': 'replay', 'last_seq': _lastSeq}));
      }).catchError((e) {
        _setState(WsState.disconnected);
        _scheduleReconnect(url);
      });

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String);
          if (msg['type'] == 'pty_output') {
            _lastSeq = msg['seq'] as int? ?? _lastSeq;
            _outputController.add(msg['data'] as String? ?? '');
          }
        },
        onDone: () {
          _setState(WsState.disconnected);
          _scheduleReconnect(url);
        },
        onError: (e) {
          _setState(WsState.disconnected);
          _scheduleReconnect(url);
        },
      );
    } catch (e) {
      _setState(WsState.disconnected);
      _scheduleReconnect(url);
    }
  }

  void send(String data) {
    _channel?.sink.add(data);
  }

  void sendInput(String text) {
    send(jsonEncode({'type': 'input', 'data': text}));
  }

  void sendResize(int cols, int rows) {
    send(jsonEncode({'type': 'resize', 'cols': cols, 'rows': rows}));
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _setState(WsState.disconnected);
  }

  void _setState(WsState s) {
    _state = s;
    _stateController.add(s);
  }

  void _scheduleReconnect(String url) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () => connect(url));
  }

  void dispose() {
    disconnect();
    _outputController.close();
    _stateController.close();
  }
}
