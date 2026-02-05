import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/task_provider.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/app_colors.dart';

class TaskHistoryTable extends StatelessWidget {
  const TaskHistoryTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final completedTasks = taskProvider.completedTasks;

        return Container(
          constraints: const BoxConstraints(minHeight: 180),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Task History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Table
              if (completedTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      'No completed tasks yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      Colors.white.withValues(alpha: 0.04),
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Task',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Priority',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Completed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    rows: completedTasks
                        .take(5) // Show only last 5 completed tasks
                        .map((task) => _buildDataRow(context, task))
                        .toList(),
                  ),
                ),

              if (completedTasks.length > 5)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        // TODO: Navigate to full history page
                      },
                      child: const Text(
                        'View All History',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  DataRow _buildDataRow(BuildContext context, Task task) {
    return DataRow(
      cells: [
        // Task name
        DataCell(
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: _getStatusColor(task.status),
                size: 16,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: Text(
                  task.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Status
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(task.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusText(task.status),
              style: TextStyle(
                color: _getStatusColor(task.status),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Priority
        DataCell(
          Text(
            _getPriorityText(task.priority),
            style: TextStyle(
              fontSize: 14,
              color: _getPriorityColor(task.priority),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Completion date
        DataCell(
          Text(
            _formatDate(task.endTime),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.resultFileUrl != null) ...[
                IconButton(
                  icon: const Icon(Icons.download, size: 18),
                  onPressed: () {
                    // TODO: Download result
                  },
                  tooltip: 'Download',
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  onPressed: () {
                    // TODO: View result
                  },
                  tooltip: 'View',
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ] else
                const Text(
                  '-',
                  style: TextStyle(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.failed:
        return Colors.red;
      case TaskStatus.paused:
        return Colors.orange;
      case TaskStatus.running:
        return Colors.blue;
      case TaskStatus.pending:
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.failed:
        return 'Failed';
      case TaskStatus.paused:
        return 'Paused';
      case TaskStatus.running:
        return 'Running';
      case TaskStatus.pending:
      default:
        return 'Pending';
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

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM dd, yyyy, h:mm a').format(date);
  }
}
