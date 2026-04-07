class LearningJourneyRecord {
  LearningJourneyRecord({
    required this.id,
    required this.title,
    required this.examName,
    required this.subject,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String examName;
  final String subject;
  final Map<String, dynamic> state;
  final DateTime createdAt;
  final DateTime updatedAt;

  LearningJourneyRecord copyWith({
    String? id,
    String? title,
    String? examName,
    String? subject,
    Map<String, dynamic>? state,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LearningJourneyRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      examName: examName ?? this.examName,
      subject: subject ?? this.subject,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'examName': examName,
      'subject': subject,
      'state': state,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LearningJourneyRecord.fromJson(Map<String, dynamic> json) {
    return LearningJourneyRecord(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? json['examName'] ?? 'Learning Journey') as String,
      examName: (json['examName'] ?? json['exam_name'] ?? '') as String,
      subject: (json['subject'] ?? 'physics') as String,
      state: (json['state'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
      updatedAt: DateTime.parse((json['updatedAt'] ?? json['updated_at']) as String),
    );
  }
}
