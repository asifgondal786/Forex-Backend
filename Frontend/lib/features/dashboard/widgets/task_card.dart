import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tajir/core/models/task.dart';
import 'package:tajir/core/theme/app_colors.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(task.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(_getStatusIcon(task.status), size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      task.status.name[0].toUpperCase() + task.status.name.substring(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Task Details
          Row(
            children: [
              Text(
                'Start: ${task.startTime != null ? DateFormat.yMMMd().add_jm().format(task.startTime!) : 'Not started'}',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  const Text(
                    'Priority: ',
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  Icon(Icons.circle, size: 12, color: _getPriorityColor(task.priority)),
                  const SizedBox(width: 4),
                  Text(
                    task.priority.name[0].toUpperCase() + task.priority.name.substring(1),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Progress Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: ${task.currentStep} / ${task.totalSteps}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const Icon(Icons.refresh, size: 18, color: Colors.black54),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Steps
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: task.steps.take(3).map((step) {
              return Expanded(
                child: _StepItem(
                  label: step.name,
                  isCompleted: step.isCompleted,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // AI Generated Result
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [ // This part cannot be const due to `task`
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI-Generated Result:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.resultFileName ?? 'No result file yet.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (task.resultFileUrl != null) ...[
                  TextButton(
                    onPressed: () {},
                    child: const Text('Download'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View'),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Suggest Next Task
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: const Text('Suggest Next Task'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return AppColors.statusRunning;
      case TaskStatus.completed:
        return AppColors.statusCompleted;
      case TaskStatus.pending:
        return AppColors.statusPending;
      case TaskStatus.failed:
        return AppColors.stopButton;
      case TaskStatus.paused:
        return AppColors.pauseButton;
    }
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return Icons.play_arrow;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.pending:
      case TaskStatus.paused:
        return Icons.pause;
      case TaskStatus.failed:
        return Icons.error;
    }
  }
}

class _StepItem extends StatelessWidget {
  final String label;
  final bool isCompleted;

  const _StepItem({
    required this.label,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.circle_outlined,
          color: isCompleted ? AppColors.primaryGreen : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isCompleted ? Colors.black87 : Colors.black54,
              fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}