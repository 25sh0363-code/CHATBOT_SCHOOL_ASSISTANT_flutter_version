class SharedTestResult {
  SharedTestResult({
    required this.id,
    required this.studentName,
    required this.subject,
    required this.percentage,
    required this.createdAt,
    this.testTitle,
  });

  final String id;
  final String studentName;
  final String subject;
  final double percentage;
  final DateTime createdAt;
  final String? testTitle;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentName': studentName,
      'subject': subject,
      'percentage': percentage,
      'createdAt': createdAt.toIso8601String(),
      'testTitle': testTitle,
    };
  }

  factory SharedTestResult.fromJson(Map<String, dynamic> json) {
    return SharedTestResult(
      id: json['id'] as String,
      studentName: json['studentName'] as String,
      subject: json['subject'] as String,
      percentage: (json['percentage'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      testTitle: json['testTitle'] as String?,
    );
  }
}
