import 'dart:async';
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../services/terminal_service.dart';

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
  late final TerminalService _terminal;
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  WsState _wsState = WsState.disconnected;
  late final StreamSubscription<WsState> _stateSub;

  @override
  void initState() {
    super.initState();
    _ws = WebSocketService();
    _terminal = TerminalService(_ws);
    _terminal.addListener(_onTerminalUpdate);
    _stateSub = _ws.stateStream.listen((s) {
      if (mounted) setState(() => _wsState = s);
    });
    _connectWs();
  }

  Future<void> _connectWs() async {
    final token = await widget.storage.getToken();
    if (token == null) return;
    final url = widget.api.wsUrl(widget.session.id, token);
    _ws.connect(url);
  }

  void _onTerminalUpdate() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }

  void _sendInput() {
    final text = _inputController.text;
    if (text.isEmpty) return;
    _terminal.sendInput('$text\r');
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _terminal.removeListener(_onTerminalUpdate);
    _terminal.dispose();
    _ws.dispose();
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _stateSub.cancel();
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
            onPressed: () => _terminal.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildTerminalView()),
          _buildInputBar(),
        ],
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

  Widget _buildTerminalView() {
    return GestureDetector(
      onTap: () => _inputFocusNode.requestFocus(),
      child: Container(
        color: const Color(0xFF1E1E1E),
        child: ListenableBuilder(
          listenable: _terminal,
          builder: (context, _) {
            final text = _terminal.output;
            if (text.isEmpty) {
              return const Center(
                child: Text(
                  '等待输出...',
                  style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                ),
              );
            }
            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                text,
                style: const TextStyle(
                  color: Color(0xFFD4D4D4),
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: const Color(0xFF2D2D2D),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Color(0xFFD4D4D4),
                ),
                decoration: InputDecoration(
                  hintText: '输入命令...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: const Color(0xFF3C3C3C),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendInput(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sendInput,
              icon: const Icon(Icons.send, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
