import 'dialogs/create_task_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/task_provider.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/live_updates_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet = MediaQuery.of(context).size.width < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      drawer: isMobile
          ? Drawer(
              backgroundColor: const Color(0xFF1F2937),
              child: Sidebar(
                isCollapsed: false,
              ),
            )
          : null,
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          final activeTasks = taskProvider.activeTasks;
          final selectedTaskId =
              activeTasks.isNotEmpty ? activeTasks.first.id : null;

          if (isMobile) {
            // Mobile Layout - Single column with vertical scrolling
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Mobile Header with Sidebar Toggle
                  Container(
                    color: const Color(0xFF1F2937),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (context) => GestureDetector(
                            onTap: () => Scaffold.of(context).openDrawer(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.menu,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          '🚀 Forex Companion',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF3B82F6),
                                Color(0xFF2563EB),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Main Content
                  DashboardContent(),
                  // Live Panel at bottom
                  if (selectedTaskId != null)
                    LiveUpdatesPanel(taskId: selectedTaskId),
                ],
              ),
            );
          } else if (isTablet) {
            // Tablet Layout - Sidebar + Content + Collapsed Live Panel
            return Row(
              children: [
                // Collapsed Sidebar
                Sidebar(
                  isCollapsed: true,
                ),
                // Main Content
                Expanded(
                  child: DashboardContent(),
                ),
                // Live Panel on right (if task selected)
                if (selectedTaskId != null)
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: LiveUpdatesPanel(taskId: selectedTaskId),
                  ),
              ],
            );
          } else {
            // Desktop Layout - Full Sidebar + Content + Live Panel
            return Row(
              children: [
                // Left Sidebar
                Sidebar(),

                // Main Content Area (Expanded to fill)
                Expanded(
                  flex: 3,
                  child: DashboardContent(),
                ),

                // Right Live Updates Panel (conditionally displayed)
                if (selectedTaskId != null)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: LiveUpdatesPanel(taskId: selectedTaskId),
                    ),
                  ),
              ],
            );
          }
        },
      ),
    );
  }
}
