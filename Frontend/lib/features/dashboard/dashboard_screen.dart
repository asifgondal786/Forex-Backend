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
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          final activeTasks = taskProvider.activeTasks;
          final selectedTaskId = activeTasks.isNotEmpty ? activeTasks.first.id : null;

          return SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: Row(
              children: [
                // Left Sidebar
                const Sidebar(),
                
                // Main Content Area (Expanded to fill)
                Expanded(
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
        },
      ),
    );
  }
}
