import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/task_provider.dart';
import 'task_card.dart';
import 'task_history_table.dart';
import 'forex_feed_widget.dart';
import 'performance_analytics.dart';
import 'news_sentiment_widget.dart';
import 'intelligent_empty_state.dart';

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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: const Color(0xFF0F1419),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header Section
              _buildHeader(context, isMobile),

              const SizedBox(height: 24),

              // Stats Cards Row
              if (!isMobile) _buildStatsRow(),
              if (!isMobile) const SizedBox(height: 24),

              // Main Content Area with Tabs
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tab Navigation
                    _buildTabNavigation(isMobile),

                    const SizedBox(height: 24),

                    // Tab Content
                    _buildTabContent(isMobile),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👋 Welcome Back!',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitor and manage your AI trading tasks',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3B82F6),
                        Color(0xFF2563EB),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          if (!isMobile) const SizedBox(height: 20),
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/create-task');
              },
              icon: const Icon(Icons.add_circle),
              label: const Text('Create New Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
              ),
            )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 600))
                .slideX(begin: -0.3),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final activeTasks = taskProvider.activeTasks.length;
        final completedTasks = taskProvider.completedTasks.length;
        final totalTasks = taskProvider.tasks.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              _buildStatCard(
                label: 'Live AI Operations',
                value: activeTasks.toString(),
                icon: Icons.play_circle,
                color: const Color(0xFF3B82F6),
                delay: 0,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                label: 'Executed Successfully',
                value: completedTasks.toString(),
                icon: Icons.check_circle,
                color: const Color(0xFF10B981),
                delay: 100,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                label: 'Total Operations',
                value: totalTasks.toString(),
                icon: Icons.task,
                color: const Color(0xFF8B5CF6),
                delay: 200,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: const Duration(milliseconds: 600))
          .slideY(
            begin: 0.3,
            delay: Duration(milliseconds: delay),
          ),
    );
  }

  Widget _buildTabNavigation(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTabButton('Live AI Operations', 0, isMobile),
          const SizedBox(width: 8),
          _buildTabButton('Executed Successfully', 1, isMobile),
          const SizedBox(width: 8),
          _buildTabButton('Analytics', 2, isMobile),
          const SizedBox(width: 8),
          _buildTabButton('News', 3, isMobile),
          const SizedBox(width: 8),
          _buildTabButton('Alerts', 4, isMobile),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, bool isMobile) {
    final isSelected = _selectedTab == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: isMobile ? 12 : 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isMobile) {
    switch (_selectedTab) {
      case 0:
        return _buildActiveTasksTab(isMobile);
      case 1:
        return _buildCompletedTasksTab();
      case 2:
        return _buildAnalyticsTab();
      case 3:
        return _buildNewsTab();
      case 4:
        return _buildAlertsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildActiveTasksTab(bool isMobile) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading tasks...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final activeTasks = taskProvider.activeTasks;

        if (activeTasks.isEmpty) {
          return Column(
            children: [
              // Forex Feed at top even with no tasks
              const ForexFeedWidget()
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 600)),
              const SizedBox(height: 24),
              // Intelligent Empty State
              IntelligentEmptyState(
                type: EmptyStateType.noActiveTasks,
                customCTA: 'Create Your First AI Task',
                onCTA: () {
                  Navigator.pushNamed(context, '/create-task');
                },
                secondaryCTA: 'Learn More',
                onSecondaryCTA: () {
                  // Open help/tutorial
                },
              ),
            ],
          );
        }

        if (isMobile) {
          // Mobile: Stack view
          return Column(
            children: [
              // Forex Feed
              const ForexFeedWidget(),
              const SizedBox(height: 16),
              // Task Cards
              ...activeTasks
                  .map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TaskCard(task: task),
                      ))
                  .toList(),
            ],
          );
        } else {
          // Desktop: Forex Feed + Grid + Details
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Forex Feed Widget
              const ForexFeedWidget()
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 600))
                  .slideY(begin: 0.2),
              const SizedBox(height: 24),

              // Task Cards Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: activeTasks.length,
                itemBuilder: (context, index) {
                  return TaskCard(task: activeTasks[index])
                      .animate()
                      .fadeIn(
                        duration: const Duration(milliseconds: 600),
                      )
                      .slideY(
                        begin: 0.2,
                        delay: Duration(milliseconds: (index + 1) * 100),
                      );
                },
              ),
              const SizedBox(height: 24),
              // Task History
              const TaskHistoryTable(),
            ],
          );
        }
      },
    );
  }

  Widget _buildCompletedTasksTab() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            const Text(
              'Completed Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed trading tasks will appear here',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const PerformanceAnalytics()
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 600))
              .slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildNewsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const NewsSentimentWidget()
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 600))
              .slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            const Text(
              'Trading Alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time alerts and notifications for your trades',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enable alerts in the Automation Panel to receive real-time notifications',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}