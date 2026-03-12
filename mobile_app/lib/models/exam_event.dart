class ExamEvent {
  const ExamEvent({
    required this.id,
    required this.title,
    required this.subject,
    required this.examDate,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String subject;
  final DateTime examDate;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'examDate': examDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static ExamEvent fromJson(Map<String, dynamic> json) {
    return ExamEvent(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      examDate: DateTime.parse(json['examDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
