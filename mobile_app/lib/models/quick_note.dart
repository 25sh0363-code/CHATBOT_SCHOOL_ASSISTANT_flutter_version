class QuickNoteAttachment {
  const QuickNoteAttachment({
    required this.name,
    required this.base64Data,
    required this.mimeType,
  });

  final String name;
  final String base64Data;
  final String mimeType;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'base64Data': base64Data,
      'mimeType': mimeType,
    };
  }

  factory QuickNoteAttachment.fromJson(Map<String, dynamic> json) {
    return QuickNoteAttachment(
      name: json['name'] as String? ?? '',
      base64Data: json['base64Data'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    );
  }
}

class QuickNote {
  QuickNote({
    required this.id,
    required this.topic,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const <QuickNoteAttachment>[],
  });

  final String id;
  final String topic;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QuickNoteAttachment> attachments;

  QuickNote copyWith({
    String? topic,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QuickNoteAttachment>? attachments,
  }) {
    return QuickNote(
      id: id,
      topic: topic ?? this.topic,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'attachments': attachments.map((item) => item.toJson()).toList(),
    };
  }

  factory QuickNote.fromJson(Map<String, dynamic> json) {
    return QuickNote(
      id: json['id'] as String,
      topic: json['topic'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(QuickNoteAttachment.fromJson)
          .toList(),
    );
  }
}
