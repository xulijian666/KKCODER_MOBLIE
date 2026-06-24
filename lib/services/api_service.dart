import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/session.dart';
import '../models/server_status.dart';
import '../models/conversation_message.dart';

class ApiService {
  String _baseUrl = '';

  void configure(String host, int port, {bool https = false}) {
    final scheme = https ? 'https' : 'http';
    _baseUrl = '$scheme://$host:$port';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<ServerStatus> getStatus() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/status'),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Server returned ${resp.statusCode}');
    }
    return ServerStatus.fromJson(jsonDecode(resp.body));
  }

  Future<String> verifyPin(String pin, String deviceName) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/pair/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pin': pin, 'deviceName': deviceName}),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      try {
        final body = jsonDecode(resp.body);
        throw Exception(body['error'] ?? '配对失败');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('配对失败 (${resp.statusCode}): ${resp.body}');
      }
    }
    final data = jsonDecode(resp.body);
    return data['token'] as String;
  }

  Future<List<Session>> getSessions(String token) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/sessions'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load sessions');
    }
    final List<dynamic> data = jsonDecode(resp.body);
    return data.map((j) => Session.fromJson(j)).toList();
  }

  String wsUrl(String sessionId, String token) {
    final wsScheme = _baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = _baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return '$wsScheme://$host/api/sessions/$sessionId/ws?token=$token';
  }

  String chatWsUrl(String sessionId, String token) {
    final wsScheme = _baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = _baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return '$wsScheme://$host/api/sessions/$sessionId/chat-ws?token=$token';
  }

  Future<List<ConversationMessage>> getMessages(String sessionId, String token) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/sessions/$sessionId/messages'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load messages');
    }
    final List<dynamic> data = jsonDecode(resp.body);
    return data.map((j) => ConversationMessage.fromJson(j)).toList();
  }

  /// 创建新会话
  Future<void> createSession({
    required String token,
    required String id,
    required String name,
    required String project,
    required String path,
    String type = 'claude',
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/sessions'),
      headers: _headers(token),
      body: jsonEncode({
        'id': id,
        'name': name,
        'project': project,
        'path': path,
        'type': type,
      }),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 201) {
      throw Exception('创建会话失败: ${resp.statusCode}');
    }
  }

  /// 请求桌面端启动会话
  Future<void> spawnSession(String sessionId, String token, {bool isReopen = true}) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/sessions/$sessionId/spawn'),
      headers: _headers(token),
      body: jsonEncode({'is_reopen': isReopen}),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 202) {
      throw Exception('启动会话失败: ${resp.statusCode}');
    }
  }
}
