class TaskStep {
  final String name;
  final bool isCompleted;
  final DateTime? completedAt;

  TaskStep({
    required this.name,
    this.isCompleted = false,
    this.completedAt,
  });

  factory TaskStep.fromJson(Map<String, dynamic> json) {
    return TaskStep(
      name: json['name'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  TaskStep copyWith({
    String? name,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return TaskStep(
      name: name ?? this.name,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}