class CollabMessage {
  const CollabMessage({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.createdAt,
    required this.payload,
  });

  final String id;
  final String senderEmail;
  final String senderName;
  final String messageType;
  final String text;
  final String createdAt;
  final Map<String, dynamic> payload;

  factory CollabMessage.fromJson(Map<String, dynamic> json) {
    return CollabMessage(
      id: json['id'] as String? ?? '',
      senderEmail: json['sender_email'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }
}
