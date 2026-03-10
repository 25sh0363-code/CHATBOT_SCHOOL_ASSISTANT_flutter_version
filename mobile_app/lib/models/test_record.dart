class TestRecord {
  TestRecord({
    required this.id,
    required this.title,
    required this.subject,
    required this.testDate,
    required this.maxMarks,
    this.score,
  });

  final String id;
  final String title;
  final String subject;
  final DateTime testDate;
  final double maxMarks;
  final double? score;

  double? get percentage {
    if (score == null || maxMarks == 0) {
      return null;
    }
    return (score! * 100) / maxMarks;
  }

  TestRecord copyWith({double? score}) {
    return TestRecord(
      id: id,
      title: title,
      subject: subject,
      testDate: testDate,
      maxMarks: maxMarks,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'testDate': testDate.toIso8601String(),
      'maxMarks': maxMarks,
      'score': score,
    };
  }

  factory TestRecord.fromJson(Map<String, dynamic> json) {
    return TestRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      testDate: DateTime.parse(json['testDate'] as String),
      maxMarks: (json['maxMarks'] as num).toDouble(),
      score: json['score'] == null ? null : (json['score'] as num).toDouble(),
    );
  }
}
