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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先在桌面端打开此会话'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
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

  Future<void> _logout() async {
    await widget.storage.deleteToken();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/pairing');
    }
  }

  /// 按项目分组，返回 {项目名: [会话列表]}
  Map<String, List<Session>> _groupByProject() {
    final map = <String, List<Session>>{};
    for (final s in _sessions) {
      final key = s.project.isNotEmpty ? s.project : '未分类';
      map.putIfAbsent(key, () => []).add(s);
    }
    // 每个项目内：活跃的排前面
    for (final list in map.values) {
      list.sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return 0;
      });
    }
    // 项目排序：有活跃会话的排前面
    final entries = map.entries.toList()
      ..sort((a, b) {
        final aActive = a.value.any((s) => s.active);
        final bActive = b.value.any((s) => s.active);
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
          final sessions = grouped[project]!;
          final activeCount = sessions.where((s) => s.active).length;

          return ExpansionTile(
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
            children: sessions.map((s) => _buildSessionTile(s)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildSessionTile(Session session) {
    final isActive = session.active;
    final isClaude = session.type == 'claude';

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
            child: Icon(
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
          : Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade700),
      onTap: () => _openSession(session),
    );
  }
}
