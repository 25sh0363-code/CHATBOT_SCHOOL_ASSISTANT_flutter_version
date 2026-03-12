class HomeworkTask {
  static const String kindTask = 'task';
  static const String kindHomework = 'homework';

  HomeworkTask({
    required this.id,
    required this.title,
    required this.date,
    required this.reminderTime,
    this.kind = kindTask,
    this.notes = '',
    this.completed = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final String reminderTime;
  final String kind;
  final String notes;
  final bool completed;

  HomeworkTask copyWith({
    String? title,
    DateTime? date,
    String? reminderTime,
    String? kind,
    String? notes,
    bool? completed,
  }) {
    return HomeworkTask(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      reminderTime: reminderTime ?? this.reminderTime,
      kind: kind ?? this.kind,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'reminderTime': reminderTime,
      'kind': kind,
      'notes': notes,
      'completed': completed,
    };
  }

  factory HomeworkTask.fromJson(Map<String, dynamic> json) {
    return HomeworkTask(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      reminderTime: (json['reminderTime'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? kindTask,
      notes: (json['notes'] as String?) ?? '',
      completed: (json['completed'] as bool?) ?? false,
    );
  }
}