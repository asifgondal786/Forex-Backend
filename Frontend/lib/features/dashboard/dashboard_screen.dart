import 'dialogs/create_task_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/live_updates_panel.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activeTasks = context.watch<TaskProvider>().activeTasks;
    final selectedTaskId = activeTasks.isNotEmpty ? activeTasks.first.id : null;

    void _showCreateTaskDialog() {
  showDialog(
    context: context,
    builder: (context) => CreateTaskDialog(),
  );
}

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          const Sidebar(),
          
          // Main Content Area
          const Expanded(
            flex: 3,
            child: DashboardContent(),
          ),
          
          // Right Live Updates Panel (conditionally displayed)
          if (selectedTaskId != null)
            Expanded(
              flex: 1,
              child: LiveUpdatesPanel(taskId: selectedTaskId),
            ),
        ],
      ),
    );
  }
}
