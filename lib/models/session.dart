class Session {
  final String id;
  final String name;
  final String project;
  final String type;
  final String agentSessionId;
  final String? createdAt;
  final String? lastUserMessageAt;

  Session({
    required this.id,
    required this.name,
    required this.project,
    required this.type,
    required this.agentSessionId,
    this.createdAt,
    this.lastUserMessageAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      project: json['project'] as String? ?? '',
      type: json['type'] as String? ?? 'claude',
      agentSessionId: json['agentSessionId'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      lastUserMessageAt: json['lastUserMessageAt'] as String?,
    );
  }
}
