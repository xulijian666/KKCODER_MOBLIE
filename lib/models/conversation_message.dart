class ConversationMessage {
  final String id;
  final String role; // "user" | "assistant"
  final String text;
  final String? createdAt;
  final int seq;

  ConversationMessage({
    required this.id,
    required this.role,
    required this.text,
    this.createdAt,
    required this.seq,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String,
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      seq: json['seq'] as int? ?? 0,
    );
  }
}
