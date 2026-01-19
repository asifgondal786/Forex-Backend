import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/task_provider.dart';
import '../../../core/models/task.dart';
import 'task_card.dart';
import 'live_updates_panel.dart';
import 'task_history_table.dart';

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  int _selectedTab = 0;
  String? _selectedTaskId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkBlue,
            AppColors.midBlue,
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Welcome To Forex Companion',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Assign Task to AI and Monitor Its Progress.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Assign New Task Button
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/create-task');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Assign New Task',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Tab Navigation
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Tabs
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _TabButton(
                              label: 'Active Tasks',
                              isSelected: _selectedTab == 0,
                              onTap: () => setState(() => _selectedTab = 0),
                            ),
                            _TabButton(
                              label: 'Completed Tasks',
                              isSelected: _selectedTab == 1,
                              onTap: () => setState(() => _selectedTab = 1),
                            ),
                            _TabButton(
                              label: 'Settings',
                              isSelected: _selectedTab == 2,
                              onTap: () => setState(() => _selectedTab = 2),
                            ),
                            _TabButton(
                              label: 'Reports',
                              isSelected: _selectedTab == 3,
                              onTap: () => setState(() => _selectedTab = 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Tab Content
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildTabContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildActiveTasksTab();
      case 1:
        return const Center(
          child: Text('Completed Tasks', style: TextStyle(fontSize: 18)),
        );
      case 2:
        return const Center(
          child: Text('Settings', style: TextStyle(fontSize: 18)),
        );
      case 3:
        return const Center(
          child: Text('Reports', style: TextStyle(fontSize: 18)),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildActiveTasksTab() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        // Show a loading indicator while fetching tasks.
        if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final activeTasks = taskProvider.activeTasks;

        // Show a message if there are no active tasks.
        if (activeTasks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48.0),
              child: Text(
                'No active tasks. Create one to get started!',
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            ),
          );
        }

        // Auto-select first task if none selected or selected task not in active list
        if (_selectedTaskId == null || 
            !activeTasks.any((t) => t.id == _selectedTaskId)) {
          // Use post-frame callback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && activeTasks.isNotEmpty) {
              setState(() {
                _selectedTaskId = activeTasks.first.id;
              });
            }
          });
          // Return loading while waiting for state update
          return const Center(child: CircularProgressIndicator());
        }

        // Get the selected task
        final selectedTask = taskProvider.getTaskById(_selectedTaskId!);
        
        if (selectedTask == null) {
          return const Center(
            child: Text(
              'Task not found',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          );
        }

        // Main layout: Left (Task Card + History) and Right (Live Updates)
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Task Card + Task History
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Card
                  TaskCard(task: selectedTask),
                  
                  const SizedBox(height: 24),
                  
                  // Task History Table
                  const TaskHistoryTable(),
                ],
              ),
            ),
            
            const SizedBox(width: 24),
            
            // Right Column: Live Updates Panel
            Expanded(
              flex: 1,
              child: LiveUpdatesPanel(taskId: selectedTask.id),
            ),
          ],
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue.shade50 : Colors.transparent,
          foregroundColor: isSelected ? Colors.blue : Colors.black54,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}