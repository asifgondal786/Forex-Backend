import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/task_provider.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildStatusBadge(task.status),
            ],
          ),

          const SizedBox(height: 16),

          // Task metadata
          Row(
            children: [
              _buildMetadataItem(
                icon: Icons.access_time,
                label: 'Start',
                value: task.startTime != null
                    ? DateFormat('MMM dd, yyyy, hh:mm a').format(task.startTime!)
                    : 'Not started',
              ),
              const SizedBox(width: 24),
              _buildMetadataItem(
                icon: Icons.flag,
                label: 'Priority',
                value: _getPriorityText(task.priority),
                color: _getPriorityColor(task.priority),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: ${task.currentStep} / ${task.totalSteps}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              _buildProgressIcon(task.status),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(task.status),
              ),
              minHeight: 12,
            ),
          ),

          const SizedBox(height: 24),

          // Task steps
          if (task.steps.isNotEmpty) ...[
            const Text(
              'Steps',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...task.steps.map((step) => _buildStepItem(step)),
          ],

          const SizedBox(height: 24),

          // Result file section
          if (task.resultFileUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI-Generated Result:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          task.resultFileName ?? 'result.pdf',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (task.resultFileSize != null)
                          Text(
                            '(${_formatFileSize(task.resultFileSize!)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Download file
                    },
                    child: const Text('Download'),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: View file
                    },
                    child: const Text('View'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Suggest Next Task button
          if (task.isCompleted) ...[
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement suggest next task
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Suggest Next Task'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],

          // Action buttons for running tasks
          if (task.isRunning || task.isPending) ...[
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<TaskProvider>().stopTask(task.id);
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<TaskProvider>().pauseTask(task.id);
                  },
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement refresh
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TaskStatus status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case TaskStatus.running:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        icon = Icons.play_circle;
        label = 'Running';
        break;
      case TaskStatus.completed:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade700;
        icon = Icons.check_circle;
        label = 'Completed';
        break;
      case TaskStatus.paused:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        icon = Icons.pause_circle;
        label = 'Paused';
        break;
      case TaskStatus.failed:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        icon = Icons.error;
        label = 'Failed';
        break;
      case TaskStatus.pending:
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        icon = Icons.schedule;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressIcon(TaskStatus status) {
    if (status == TaskStatus.running) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStepItem(TaskStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            step.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: step.isCompleted ? Colors.green : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.name,
              style: TextStyle(
                fontSize: 14,
                color: step.isCompleted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                decoration: step.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (step.isCompleted && step.completedAt != null)
            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Color _getProgressColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return AppColors.primaryGreen;
      case TaskStatus.completed:
        return Colors.blue;
      case TaskStatus.paused:
        return Colors.orange;
      case TaskStatus.failed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
