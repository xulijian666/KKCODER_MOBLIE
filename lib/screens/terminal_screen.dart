import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../widgets/xterm_view.dart';

class TerminalScreen extends StatefulWidget {
  final ApiService api;
  final StorageService storage;
  final Session session;

  const TerminalScreen({
    super.key,
    required this.api,
    required this.storage,
    required this.session,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final WebSocketService _ws;
  final _xtermKey = GlobalKey<XTermViewState>();
  WsState _wsState = WsState.disconnected;
  late final StreamSubscription<WsState> _stateSub;
  late final StreamSubscription<String> _outputSub;

  @override
  void initState() {
    super.initState();
    _ws = WebSocketService();
    _stateSub = _ws.stateStream.listen((s) {
      if (mounted) setState(() => _wsState = s);
    });
    // 监听 WebSocket 输出，写入 xterm
    _outputSub = _ws.output.listen((data) {
      _xtermKey.currentState?.write(data);
    });
  }

  Future<void> _connectWs() async {
    final token = await widget.storage.getToken();
    if (token == null) return;
    final url = widget.api.wsUrl(widget.session.id, token);
    _ws.connect(url);
  }

  void _onXtermReady() {
    // xterm.js 加载完成后连接 WebSocket
    _connectWs();
  }

  void _onXtermInput(String data) {
    // 来自 xterm.js 的键盘输入
    try {
      // 尝试解析为 JSON（resize 消息）
      final msg = jsonDecode(data);
      if (msg is Map && msg['type'] == 'resize') {
        _ws.sendResize(msg['cols'] as int, msg['rows'] as int);
        return;
      }
    } catch (_) {
      // 不是 JSON，是普通输入
    }
    // 普通键盘输入
    _ws.sendInput(data);
  }

  @override
  void dispose() {
    _outputSub.cancel();
    _stateSub.cancel();
    _ws.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.session.name.isNotEmpty ? widget.session.name : widget.session.id,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          _buildStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清屏',
            onPressed: () => _xtermKey.currentState?.clear(),
          ),
        ],
      ),
      body: XTermView(
        key: _xtermKey,
        onReady: (_) => _onXtermReady(),
        onInput: _onXtermInput,
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final color = switch (_wsState) {
      WsState.connected => Colors.green,
      WsState.connecting => Colors.orange,
      WsState.disconnected => Colors.red,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
