import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/session.dart';
import '../models/conversation_message.dart';
import '../services/api_service.dart';
import '../services/conversation_service.dart';
import '../services/storage_service.dart';
import 'terminal_screen.dart';

class ConversationScreen extends StatefulWidget {
  final ApiService api;
  final StorageService storage;
  final Session session;

  const ConversationScreen({
    super.key,
    required this.api,
    required this.storage,
    required this.session,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final ConversationService _conv = ConversationService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _conv.addListener(_onConversationChanged);
    _scrollController.addListener(_onScrollChanged);
    _connectChatWs();
  }

  Future<void> _connectChatWs() async {
    final token = await widget.storage.getToken();
    if (token == null) return;
    final url = widget.api.chatWsUrl(widget.session.id, token);
    _conv.connect(url);
    // 初始快照会通过 WS 推送，不需要单独调 REST
    if (mounted) setState(() => _isLoading = false);
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // 距离底部超过 200px 时显示按钮
    final showButton = (maxScroll - currentScroll) > 200;
    if (showButton != _showScrollToBottom) {
      setState(() => _showScrollToBottom = showButton);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isInitialLoad = true;

  void _onConversationChanged() {
    if (mounted) setState(() {});
    // 等待 UI 渲染完成后滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_isInitialLoad) {
        // 首次加载：直接跳到底部（无动画），避免大量消息时定位不准
        _isInitialLoad = false;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendPrompt() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _conv.submitPrompt(text);
    _inputController.clear();
    // 发送后滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openTerminalDebug() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TerminalScreen(
          api: widget.api,
          storage: widget.storage,
          session: widget.session,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _conv.removeListener(_onConversationChanged);
    _scrollController.removeListener(_onScrollChanged);
    _conv.dispose();
    _inputController.dispose();
    _scrollController.dispose();
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
          _buildRunStatusChip(),
          IconButton(
            icon: const Icon(Icons.terminal),
            tooltip: '终端调试模式',
            onPressed: _openTerminalDebug,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
      floatingActionButton: _showScrollToBottom
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: Colors.grey.shade800,
              foregroundColor: Colors.white,
              child: const Icon(Icons.keyboard_arrow_down),
            )
          : null,
    );
  }

  Widget _buildStatusIndicator() {
    final color = switch (_conv.connectionState) {
      ConversationWsState.connected => Colors.green,
      ConversationWsState.connecting => Colors.orange,
      ConversationWsState.disconnected => Colors.red,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 8),
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

  Widget _buildRunStatusChip() {
    final statusText = switch (_conv.runStatus) {
      'thinking' => '思考中...',
      'running' => '执行中...',
      _ => '空闲',
    };
    final isRunning = _conv.runStatus != 'idle';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isRunning
                ? Colors.orange.withValues(alpha: 0.2)
                : Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRunning ? Colors.orange.shade700 : Colors.green.shade700,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRunning)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.orange.shade300,
                    ),
                  ),
                ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: isRunning ? Colors.orange.shade300 : Colors.green.shade300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conv.connectionState == ConversationWsState.disconnected &&
        _conv.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('连接断开', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _connectChatWs,
              child: const Text('重新连接'),
            ),
          ],
        ),
      );
    }

    if (_conv.messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('还没有对话', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('在下方输入问题开始对话', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    final messageCount = _conv.messages.length + (_conv.runStatus != 'idle' ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messageCount,
      itemBuilder: (ctx, i) {
        if (i < _conv.messages.length) {
          return _buildMessageBubble(_conv.messages[i]);
        }
        // 最后一个 item：正在输入指示器
        return _buildTypingIndicator();
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange.shade300,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _conv.runStatus == 'thinking' ? '思考中...' : '执行中...',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage msg) {
    final isUser = msg.role == 'user';
    final isChoiceCard = msg.role == 'choice_card';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: isUser
          ? _buildUserBubble(msg)
          : isChoiceCard
              ? _buildChoiceCardBubble(msg)
              : _buildAssistantBubble(msg),
    );
  }

  Widget _buildUserBubble(ConversationMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade800.withValues(alpha: 0.7),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: SelectableText(
          msg.text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(ConversationMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: msg.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 14),
                code: TextStyle(
                  color: Colors.orange.shade300,
                  fontSize: 13,
                  fontFamily: 'Cascadia Mono, Fira Code, Consolas, monospace',
                  backgroundColor: const Color(0xFF2D2D2D),
                ),
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                codeblockPadding: const EdgeInsets.all(12),
                h1: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 20, fontWeight: FontWeight.bold),
                h2: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 18, fontWeight: FontWeight.bold),
                h3: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 16, fontWeight: FontWeight.bold),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.orange.shade700, width: 3),
                  ),
                ),
                blockquotePadding: const EdgeInsets.only(left: 12),
                listBullet: const TextStyle(color: Color(0xFFD4D4D4)),
              ),
            ),
            // 复制按钮
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.copy, size: 16, color: Colors.grey.shade600),
                tooltip: '复制',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制到剪贴板'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCardBubble(ConversationMessage msg) {
    // 解析卡片文本，高亮选中项
    final lines = msg.text.split('\n');
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.blue.shade900.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...lines.map((line) {
              final isSelected = line.contains('❯');
              final isHint = line.contains('💡');
              // 清理标记符号
              final cleanLine = line.replaceAll('❯', '  ').trim();
              if (cleanLine.isEmpty) return const SizedBox(height: 4);

              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  cleanLine,
                  style: TextStyle(
                    color: isHint
                        ? Colors.grey.shade500
                        : isSelected
                            ? Colors.blue.shade300
                            : const Color(0xFFD4D4D4),
                    fontSize: isHint ? 12 : 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontStyle: isHint ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isConnected = _conv.connectionState == ConversationWsState.connected;
    final canSend = isConnected && _inputController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: _inputController,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  enabled: isConnected,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: isConnected ? '输入问题...' : '连接中...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: const Color(0xFF2D2D2D),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.orange.shade700),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}), // 刷新发送按钮状态
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: canSend ? Colors.orange.shade700 : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: canSend ? _sendPrompt : null,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.send,
                    color: canSend ? Colors.white : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
