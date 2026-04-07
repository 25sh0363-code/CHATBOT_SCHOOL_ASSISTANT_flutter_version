class MindMapRecord {
  MindMapRecord({
    required this.id,
    required this.title,
    required this.topic,
    required this.content,
    this.drawingJson = '[]',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String topic;
  final String content;
  final String drawingJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  MindMapRecord copyWith({
    String? title,
    String? topic,
    String? content,
    String? drawingJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MindMapRecord(
      id: id,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      content: content ?? this.content,
      drawingJson: drawingJson ?? this.drawingJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'topic': topic,
      'content': content,
      'drawingJson': drawingJson,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MindMapRecord.fromJson(Map<String, dynamic> json) {
    return MindMapRecord(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? json['topic'] ?? '') as String,
      topic: (json['topic'] ?? json['title'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      drawingJson: (json['drawingJson'] ?? json['drawing_json'] ?? '[]') as String,
      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      updatedAt: DateTime.parse((json['updatedAt'] ?? json['updated_at']) as String),
    );
  }
}