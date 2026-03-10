class TimetableEntry {
  TimetableEntry({
    required this.id,
    required this.subject,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.notes = '',
  });

  final String id;
  final String subject;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String notes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'notes': notes,
    };
  }

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      id: json['id'] as String,
      subject: json['subject'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      notes: (json['notes'] as String?) ?? '',
    );
  }
}
