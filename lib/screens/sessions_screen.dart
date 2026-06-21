import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/session_card.dart';
import 'terminal_screen.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TerminalScreen(
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
            Text('暂无活跃会话', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sessions.length,
        itemBuilder: (ctx, i) => SessionCard(
          session: _sessions[i],
          onTap: () => _openSession(_sessions[i]),
        ),
      ),
    );
  }
}
