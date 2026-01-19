import '../../core/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
import '../../core/models/task.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/task_provider.dart';

class TaskHistoryScreen extends StatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  String _filterStatus = 'all'; // all, completed, running, pending

  List<Task> _getFilteredTasks(TaskProvider provider) {
    switch (_filterStatus) {
      case 'running':
        return provider.activeTasks;
      case 'completed':
        return provider.completedTasks;
      default:
        return provider.tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredTasks = _getFilteredTasks(taskProvider);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Task History',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${filteredTasks.length} tasks',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/create-task');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('New Task'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Filters
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Filter:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _FilterChip(
                            label: 'All',
                            isSelected: _filterStatus == 'all',
                            onTap: () => setState(() => _filterStatus = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Running',
                            isSelected: _filterStatus == 'running',
                            color: AppColors.statusRunning,
                            onTap: () => setState(() => _filterStatus = 'running'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Completed',
                            isSelected: _filterStatus == 'completed',
                            color: AppColors.statusCompleted,
                            onTap: () => setState(() => _filterStatus = 'completed'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Pending',
                            isSelected: _filterStatus == 'pending',
                            color: AppColors.statusPending,
                            onTap: () => setState(() => _filterStatus = 'pending'),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Task List
                    if (filteredTasks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tasks found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first task to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filteredTasks.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TaskHistoryCard(task: task),
                      )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primaryBlue;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withAlpha(51) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? chipColor : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _TaskHistoryCard extends StatelessWidget {
  final Task task;

  const _TaskHistoryCard({required this.task});

  @override
  Widget build(BuildContext context) {
    // final dateFormat = DateFormat('MMM dd, yyyy, hh:mm a');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              _StatusBadge(status: task.status),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Text(
            task.description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              _InfoChip(
                icon: Icons.calendar_today,
                label: task.createdAt != null
                    ? DateFormatter.formatDate(task.createdAt!)
                    : 'Unknown',
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: Icons.flag,
                label: task.priority.name.toUpperCase(),
                color: _getPriorityColor(task.priority),
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: Icons.timer,
                label: 'Progress: ${task.currentStep}/${task.totalSteps}',
              ),
            ],
          ),
          
          if (task.isRunning) ...[
            const SizedBox(height: 16),
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
          
          if (task.resultFileName != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.file_download, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.resultFileName!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Implement download
                    },
                    child: const Text('Download'),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              if (task.isRunning) ...[
                TextButton.icon(
                  onPressed: () {
                    context.read<TaskProvider>().pauseTask(task.id);
                  },
                  icon: const Icon(Icons.pause, size: 18),
                  label: const Text('Pause'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    context.read<TaskProvider>().stopTask(task.id);
                  },
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.stopButton),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _showTaskDetails(context, task);
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Details'),
              ),
            ],
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

  void _showTaskDetails(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Description: ${task.description}'),
              const SizedBox(height: 16),
              Text('Status: ${task.status.name}'),
              Text('Priority: ${task.priority.name}'),
              Text('Progress: ${task.currentStep}/${task.totalSteps}'),
              const SizedBox(height: 16),
              const Text('Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...task.steps.map((step) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Row(
                  children: [
                    Icon(
                      step.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: step.isCompleted ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(step.name)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.black54),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color ?? Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    
    switch (status) {
      case TaskStatus.running:
        color = AppColors.statusRunning;
        label = 'Running';
        break;
      case TaskStatus.completed:
        color = AppColors.statusCompleted;
        label = 'Completed';
        break;
      case TaskStatus.pending:
        color = AppColors.statusPending;
        label = 'Pending';
        break;
      case TaskStatus.failed:
        color = AppColors.stopButton;
        label = 'Failed';
        break;
      case TaskStatus.paused:
        color = AppColors.pauseButton;
        label = 'Paused';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}