class SharedTestResult {
  SharedTestResult({
    required this.id,
    required this.studentName,
    required this.subject,
    required this.score,
    required this.maxMarks,
    required this.createdAt,
    this.testTitle,
    this.profilePhotoBase64,
  });

  final String id;
  final String studentName;
  final String subject;
  final double score;
  final double maxMarks;
  final DateTime createdAt;
  final String? testTitle;
  final String? profilePhotoBase64;

  double get percentage {
    if (maxMarks <= 0) {
      return 0;
    }
    return (score / maxMarks) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentName': studentName,
      'subject': subject,
      'score': score,
      'maxMarks': maxMarks,
      'percentage': percentage,
      'createdAt': createdAt.toIso8601String(),
      'testTitle': testTitle,
      'profilePhotoBase64': profilePhotoBase64,
    };
  }

  factory SharedTestResult.fromJson(Map<String, dynamic> json) {
    final scoreRaw = json['score'];
    final maxMarksRaw = json['maxMarks'];
    final legacyPercentageRaw = json['percentage'];

    final parsedScore = scoreRaw is num
        ? scoreRaw.toDouble()
        : double.tryParse((scoreRaw ?? '').toString());
    final parsedMaxMarks = maxMarksRaw is num
        ? maxMarksRaw.toDouble()
        : double.tryParse((maxMarksRaw ?? '').toString());
    final parsedPercentage = legacyPercentageRaw is num
        ? legacyPercentageRaw.toDouble()
        : double.tryParse((legacyPercentageRaw ?? '').toString()) ?? 0;

    return SharedTestResult(
      id: json['id'] as String,
      studentName: json['studentName'] as String,
      subject: json['subject'] as String,
      score: parsedScore ?? parsedPercentage,
      maxMarks: (parsedMaxMarks != null && parsedMaxMarks > 0)
          ? parsedMaxMarks
          : 100,
      createdAt: DateTime.parse(json['createdAt'] as String),
      testTitle: json['testTitle'] as String?,
      profilePhotoBase64: json['profilePhotoBase64'] as String?,
    );
  }
}
