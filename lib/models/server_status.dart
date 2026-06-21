class ServerStatus {
  final bool running;
  final int port;
  final int activeSessions;

  ServerStatus({
    required this.running,
    required this.port,
    required this.activeSessions,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    return ServerStatus(
      running: json['running'] as bool? ?? false,
      port: json['port'] as int? ?? 0,
      activeSessions: json['active_sessions'] as int? ?? 0,
    );
  }
}
