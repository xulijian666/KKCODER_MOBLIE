import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'conversation_screen.dart';

class SessionsScreen extends StatefulWidget {
  final ApiService api;
  final StorageService storage;

  const SessionsScreen({
    super.key,
    required this.api,
    required this.storage,
  });

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<Session> _sessions = [];
  bool _isLoading = true;
  String? _error;
  String? _operatingSessionId; // 正在操作的会话 ID

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await widget.storage.getToken();
      if (token == null) throw Exception('未登录');
      final sessions = await widget.api.getSessions(token);
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openSession(Session session) {
    if (!session.active) {
      // 非活跃会话，弹出唤醒确认
      _showWakeUpDialog(session);
      return;
    }
    _navigateToConversation(session);
  }

  void _navigateToConversation(Session session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          api: widget.api,
          storage: widget.storage,
          session: session,
        ),
      ),
    );
  }

  /// 唤醒非活跃会话
  Future<void> _wakeUpSession(Session session) async {
    final token = await widget.storage.getToken();
    if (token == null) return;

    setState(() => _operatingSessionId = session.id);

    try {
      await widget.api.spawnSession(session.id, token);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已请求启动会话，等待桌面端响应...'),
          duration: Duration(seconds: 2),
        ),
      );

      // 等待一小段时间让桌面端启动
      await Future.delayed(const Duration(seconds: 2));
      await _loadSessions();

      // 检查是否已激活
      final updated = _sessions.firstWhere(
        (s) => s.id == session.id,
        orElse: () => session,
      );
      if (updated.active && mounted) {
        _navigateToConversation(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _operatingSessionId = null);
    }
  }

  /// 在项目中新建对话
  Future<void> _createNewSession(String project, String projectPath) async {
    final token = await widget.storage.getToken();
    if (token == null) return;

    // 生成唯一 ID
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final name = '新对话';

    setState(() => _operatingSessionId = sessionId);

    try {
      // 1. 创建会话记录
      await widget.api.createSession(
        token: token,
        id: sessionId,
        name: name,
        project: project,
        path: projectPath,
      );

      // 2. 请求桌面端启动
      await widget.api.spawnSession(sessionId, token);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已创建新对话，等待桌面端启动...'),
          duration: Duration(seconds: 2),
        ),
      );

      // 3. 等待启动并刷新列表
      await Future.delayed(const Duration(seconds: 2));
      await _loadSessions();

      // 4. 自动进入新会话
      final newSession = _sessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => Session(
          id: sessionId,
          name: name,
          project: project,
          path: projectPath,
          type: 'claude',
          agentSessionId: '',
          active: false,
        ),
      );

      if (mounted) {
        _navigateToConversation(newSession);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _operatingSessionId = null);
    }
  }

  void _showWakeUpDialog(Session session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('唤醒会话'),
        content: Text('是否在桌面端启动 "${session.name.isNotEmpty ? session.name : session.id}"？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _wakeUpSession(session);
            },
            child: const Text('唤醒'),
          ),
        ],
      ),
    );
  }

  void _showNewSessionMenu(String project, String projectPath) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('新建对话'),
              subtitle: Text(project),
              onTap: () {
                Navigator.pop(ctx);
                _createNewSession(project, projectPath);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.storage.deleteToken();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/pairing');
    }
  }

  /// 按项目分组，返回 {项目名: (path, [会话列表])}
  Map<String, (String, List<Session>)> _groupByProject() {
    final map = <String, (String, List<Session>)>{};
    for (final s in _sessions) {
      final key = s.project.isNotEmpty ? s.project : '未分类';
      final existing = map[key];
      if (existing != null) {
        final (path, list) = existing;
        list.add(s);
      } else {
        map[key] = (s.path, [s]);
      }
    }
    // 每个项目内：活跃的排前面
    for (final entry in map.values) {
      final (_, list) = entry;
      list.sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return 0;
      });
    }
    // 项目排序：有活跃会话的排前面
    final entries = map.entries.toList()
      ..sort((a, b) {
        final aActive = a.value.$2.any((s) => s.active);
        final bActive = b.value.$2.any((s) => s.active);
        if (aActive != bActive) return aActive ? -1 : 1;
        return a.key.compareTo(b.key);
      });
    return Map.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KKCODER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
          PopupMenuButton(
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('断开连接')),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadSessions,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无会话', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final grouped = _groupByProject();

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: grouped.length,
        itemBuilder: (ctx, i) {
          final project = grouped.keys.elementAt(i);
          final (projectPath, sessions) = grouped[project]!;
          final activeCount = sessions.where((s) => s.active).length;

          return _buildProjectTile(project, projectPath, sessions, activeCount);
        },
      ),
    );
  }

  Widget _buildProjectTile(String project, String projectPath, List<Session> sessions, int activeCount) {
    // 使用 ExpansionTile 并在 header 上添加长按
    return GestureDetector(
      onLongPress: () => _showNewSessionMenu(project, projectPath),
      child: ExpansionTile(
        dense: true,
        initiallyExpanded: activeCount > 0,
        leading: Icon(
          Icons.folder,
          size: 20,
          color: activeCount > 0
              ? Colors.orange.shade400
              : Colors.grey.shade600,
        ),
        title: Text(
          project,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${sessions.length} 个会话'
          '${activeCount > 0 ? ' · $activeCount 运行中' : ''}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        children: [
          // 添加一个"新建对话"按钮
          InkWell(
            onTap: () => _createNewSession(project, projectPath),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, size: 20, color: Colors.orange.shade400),
                  const SizedBox(width: 12),
                  Text(
                    '新建对话',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 原有的会话列表
          ...sessions.map((s) => _buildSessionTile(s)),
        ],
      ),
    );
  }

  Widget _buildSessionTile(Session session) {
    final isActive = session.active;
    final isClaude = session.type == 'claude';
    final isOperating = _operatingSessionId == session.id;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isClaude
                ? Colors.orange.shade700
                : Colors.blue.shade700,
            child: isOperating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isClaude ? Icons.terminal : Icons.smart_toy,
                    color: Colors.white,
                    size: 16,
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.grey.shade700,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        session.name.isNotEmpty ? session.name : session.id,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isActive ? null : Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
      trailing: isActive
          ? const Icon(Icons.chevron_right, size: 18)
          : Icon(Icons.power_settings_new, size: 16, color: Colors.grey.shade600),
      onTap: () => _openSession(session),
    );
  }
}
