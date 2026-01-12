import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_step.dart';

class Task {
  final String? userId;
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? createdAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final int currentStep;
  final int totalSteps;
  final List<TaskStep> steps;
  final String? resultFileUrl;
  final String? resultFileName;
  final int? resultFileSize;

  Task({
    this.userId,
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.createdAt,
    this.startTime,
    this.endTime,
    required this.currentStep,
    required this.totalSteps,
    required this.steps,
    this.resultFileUrl,
    this.resultFileName,
    this.resultFileSize,
  });

  double get progress => totalSteps > 0 ? currentStep / totalSteps : 0.0;

  bool get isCompleted => status == TaskStatus.completed;
  bool get isRunning => status == TaskStatus.running;
  bool get isPending => status == TaskStatus.pending;

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date);
      return null;
    }

    return Task(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      createdAt: parseDate(json['createdAt']),
      startTime: parseDate(json['startTime']),
      endTime: parseDate(json['endTime']),
      currentStep: json['currentStep'] as int? ?? 0,
      totalSteps: json['totalSteps'] as int? ?? 0,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((step) => TaskStep.fromJson(step as Map<String, dynamic>))
              .toList() ??
          [],
      resultFileUrl: json['resultFileUrl'] as String?,
      resultFileName: json['resultFileName'] as String?,
      resultFileSize: json['resultFileSize'] as int?,
    );
  }

  factory Task.fromFirestore(Map<String, dynamic> data, String documentId) {
    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date);
      return null;
    }

    return Task(
      id: documentId,
      userId: data['userId'] as String?,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TaskStatus.pending,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => TaskPriority.medium,
      ),
      createdAt: parseDate(data['createdAt']),
      startTime: parseDate(data['startTime']),
      endTime: parseDate(data['endTime']),
      currentStep: data['currentStep'] as int? ?? 0,
      totalSteps: data['totalSteps'] as int? ?? 0,
      steps: (data['steps'] as List<dynamic>?)
              ?.map((step) => TaskStep.fromJson(step as Map<String, dynamic>))
              .toList() ??
          [],
      resultFileUrl: data['resultFileUrl'] as String?,
      resultFileName: data['resultFileName'] as String?,
      resultFileSize: data['resultFileSize'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'currentStep': currentStep,
      'totalSteps': totalSteps,
      'steps': steps.map((step) => step.toJson()).toList(),
      'resultFileUrl': resultFileUrl,
      'resultFileName': resultFileName,
      'resultFileSize': resultFileSize,
    };
  }

  Task copyWith({
    String? userId,
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? startTime,
    DateTime? endTime,
    int? currentStep,
    int? totalSteps,
    List<TaskStep>? steps,
    String? resultFileUrl,
    String? resultFileName,
    int? resultFileSize,
  }) {
    return Task(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      steps: steps ?? this.steps,
      resultFileUrl: resultFileUrl ?? this.resultFileUrl,
      resultFileName: resultFileName ?? this.resultFileName,
      resultFileSize: resultFileSize ?? this.resultFileSize,
    );
  }
}

enum TaskStatus {
  pending,
  running,
  completed,
  failed,
  paused,
}

enum TaskPriority {
  low,
  medium,
  high,
}