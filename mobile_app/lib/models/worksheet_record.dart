class WorksheetRecord {
  WorksheetRecord({
    required this.id,
    required this.title,
    required this.subject,
    required this.topic,
    required this.createdAt,
    required this.questions,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String subject;
  final String topic;
  final DateTime createdAt;
  final List<String> questions;
  final bool isPinned;

  WorksheetRecord copyWith({
    String? title,
    String? subject,
    String? topic,
    DateTime? createdAt,
    List<String>? questions,
    bool? isPinned,
  }) {
    return WorksheetRecord(
      id: id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      createdAt: createdAt ?? this.createdAt,
      questions: questions ?? this.questions,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'topic': topic,
      'createdAt': createdAt.toIso8601String(),
      'questions': questions,
      'isPinned': isPinned,
    };
  }

  factory WorksheetRecord.fromJson(Map<String, dynamic> json) {
    final dynamic rawQuestions = json['questions'];
    return WorksheetRecord(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      subject: (json['subject'] ?? '') as String,
      topic: (json['topic'] ?? '') as String,
      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      questions: rawQuestions is List
          ? rawQuestions.map((e) => e.toString()).toList()
          : <String>[],
      isPinned: (json['isPinned'] ?? json['is_pinned']) as bool? ?? false,
    );
  }
}
