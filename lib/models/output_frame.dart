class OutputFrame {
  final int seq;
  final String sessionId;
  final String data;
  final int timestamp;

  OutputFrame({
    required this.seq,
    required this.sessionId,
    required this.data,
    required this.timestamp,
  });

  factory OutputFrame.fromJson(Map<String, dynamic> json) {
    return OutputFrame(
      seq: json['seq'] as int,
      sessionId: json['session_id'] as String? ?? '',
      data: json['data'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }
}
