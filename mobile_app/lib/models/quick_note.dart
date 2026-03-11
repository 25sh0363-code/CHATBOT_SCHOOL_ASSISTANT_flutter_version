class QuickNote {
  QuickNote({
    required this.id,
    required this.topic,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String topic;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuickNote copyWith({
    String? topic,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuickNote(
      id: id,
      topic: topic ?? this.topic,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory QuickNote.fromJson(Map<String, dynamic> json) {
    return QuickNote(
      id: json['id'] as String,
      topic: json['topic'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
