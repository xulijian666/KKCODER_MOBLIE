import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/conversation_message.dart';

enum ConversationWsState { disconnected, connecting, connected }

class ConversationService extends ChangeNotifier {
  WebSocketChannel? _channel;
  ConversationWsState _state = ConversationWsState.disconnected;
  int _lastSeq = 0;
  Timer? _reconnectTimer;
  String? _url;

  final List<ConversationMessage> _messages = [];
  String _runStatus = 'idle'; // "thinking" | "running" | "idle"

  List<ConversationMessage> get messages => List.unmodifiable(_messages);
  String get runStatus => _runStatus;
  ConversationWsState get connectionState => _state;
  int get lastSeq => _lastSeq;

  void connect(String wsUrl) {
    disconnect();
    _url = wsUrl;
    _setState(ConversationWsState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.ready.then((_) {
        _setState(ConversationWsState.connected);
        // 请求断线重连补发
        send(jsonEncode({'type': 'replay', 'last_seq': _lastSeq}));
      }).catchError((e) {
        _setState(ConversationWsState.disconnected);
        _scheduleReconnect();
      });

      _channel!.stream.listen(
        (data) {
          _handleMessage(data as String);
        },
        onDone: () {
          _setState(ConversationWsState.disconnected);
          _scheduleReconnect();
        },
        onError: (e) {
          _setState(ConversationWsState.disconnected);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _setState(ConversationWsState.disconnected);
      _scheduleReconnect();
    }
  }

  void _handleMessage(String raw) {
    try {
      final msg = jsonDecode(raw);
      final type = msg['type'] as String? ?? '';
      switch (type) {
        case 'conversation_snapshot':
          _handleSnapshot(msg);
          break;
        case 'message_added':
          _handleMessageAdded(msg);
          break;
        case 'run_status':
          _handleRunStatus(msg);
          break;
        case 'choice_card':
          _handleChoiceCard(msg);
          break;
        case 'replay_complete':
          // replay 完成，无需特殊处理
          break;
        case 'error':
          debugPrint('ConversationService error: ${msg['message']}');
          break;
      }
    } catch (e) {
      debugPrint('ConversationService: failed to parse message: $e');
    }
  }

  void _handleSnapshot(Map<String, dynamic> msg) {
    final messagesJson = msg['messages'] as List<dynamic>? ?? [];
    _messages.clear();
    for (final m in messagesJson) {
      _messages.add(ConversationMessage.fromJson(m as Map<String, dynamic>));
    }
    _lastSeq = msg['last_seq'] as int? ?? 0;
    notifyListeners();
  }

  void _handleMessageAdded(Map<String, dynamic> msg) {
    final seq = msg['seq'] as int? ?? 0;
    if (seq <= _lastSeq) return; // 去重
    _lastSeq = seq;

    final role = msg['role'] as String? ?? '';
    final text = msg['text'] as String? ?? '';
    final id = msg['id'] as String? ?? '';

    // 如果是用户消息，检查是否与本地消息重复
    if (role == 'user') {
      final localIndex = _messages.indexWhere(
        (m) => m.id.startsWith('local_') && m.text == text,
      );
      if (localIndex != -1) {
        // 用服务端消息替换本地消息
        _messages[localIndex] = ConversationMessage(
          id: id,
          role: role,
          text: text,
          createdAt: msg['created_at'] as String?,
          seq: seq,
        );
        notifyListeners();
        return;
      }
    }

    // 添加新消息
    _messages.add(ConversationMessage(
      id: id,
      role: role,
      text: text,
      createdAt: msg['created_at'] as String?,
      seq: seq,
    ));

    // 收到 assistant 回复，状态变为空闲
    if (role == 'assistant') {
      _runStatus = 'idle';
    }

    notifyListeners();
  }

  void _handleRunStatus(Map<String, dynamic> msg) {
    final newStatus = msg['status'] as String? ?? 'idle';
    if (_runStatus != newStatus) {
      _runStatus = newStatus;
      notifyListeners();
    }
  }

  void _handleChoiceCard(Map<String, dynamic> msg) {
    final text = msg['text'] as String? ?? '';
    final createdAt = msg['created_at'] as String?;
    if (text.isEmpty) return;

    // 作为特殊 assistant 消息添加到列表
    _messages.add(ConversationMessage(
      id: 'choice_${DateTime.now().millisecondsSinceEpoch}',
      role: 'choice_card',
      text: text,
      createdAt: createdAt,
      seq: _lastSeq + 1,
    ));
    _lastSeq++;
    _runStatus = 'idle';
    notifyListeners();
  }

  void submitPrompt(String text) {
    // 立即在本地显示用户消息
    final localMsg = ConversationMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      text: text,
      createdAt: DateTime.now().toIso8601String(),
      seq: _lastSeq + 1,
    );
    _messages.add(localMsg);
    _runStatus = 'thinking';
    notifyListeners();

    // 发送到桌面端
    send(jsonEncode({'type': 'submit_prompt', 'text': text}));
  }

  void send(String data) {
    _channel?.sink.add(data);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _setState(ConversationWsState.disconnected);
  }

  void _setState(ConversationWsState s) {
    _state = s;
    notifyListeners();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_url != null) connect(_url!);
    });
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
