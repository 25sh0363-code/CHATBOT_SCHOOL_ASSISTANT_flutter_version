class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.details,
    required this.dueDate,
    required this.createdAt,
    required this.isCompleted,
    this.completedAt,
  });

  final String id;
  final String title;
  final String details;
  final DateTime dueDate;
  final DateTime createdAt;
  final bool isCompleted;
  final DateTime? completedAt;

  TodoItem copyWith({
    String? id,
    String? title,
    String? details,
    DateTime? dueDate,
    DateTime? createdAt,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'details': details,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  static TodoItem fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      details: json['details'] as String? ?? '',
      dueDate: DateTime.parse(json['dueDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );
  }
}
