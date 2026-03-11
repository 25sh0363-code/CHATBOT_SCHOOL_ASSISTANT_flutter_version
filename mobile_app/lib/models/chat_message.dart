class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String text;
  final bool isUser;
  final bool isError;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'isError': isError,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        isError: json['isError'] as bool? ?? false,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
