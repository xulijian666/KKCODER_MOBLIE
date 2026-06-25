class Session {
  final String id;
  final String name;
  final String project;
  final String path;
  final String type;
  final String agentSessionId;
  final String? createdAt;
  final String? lastUserMessageAt;
  final bool active;
  final String runStatus; // "thinking" | "idle"

  Session({
    required this.id,
    required this.name,
    required this.project,
    required this.path,
    required this.type,
    required this.agentSessionId,
    this.createdAt,
    this.lastUserMessageAt,
    this.active = false,
    this.runStatus = 'idle',
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      project: json['project'] as String? ?? '',
      path: json['path'] as String? ?? '',
      type: json['type'] as String? ?? 'claude',
      agentSessionId: json['agentSessionId'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      lastUserMessageAt: json['lastUserMessageAt'] as String?,
      active: json['active'] as bool? ?? false,
      runStatus: json['runStatus'] as String? ?? 'idle',
    );
  }
}
