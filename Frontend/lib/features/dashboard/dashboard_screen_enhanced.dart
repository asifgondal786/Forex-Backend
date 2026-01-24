import 'dialogs/create_task_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';
import 'widgets/sidebar.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/live_updates_panel.dart';
import 'widgets/auth_header.dart';
import 'widgets/trust_bar.dart';
import 'widgets/ai_status_banner.dart';
import 'widgets/emergency_stop_button.dart';
import 'widgets/trust_reinforcement_footer.dart';

class DashboardScreenEnhanced extends StatefulWidget {
  const DashboardScreenEnhanced({super.key});

  @override
  State<DashboardScreenEnhanced> createState() =>
      _DashboardScreenEnhancedState();
}

class _DashboardScreenEnhancedState extends State<DashboardScreenEnhanced> {
  bool _sidebarCollapsed = false;
  bool _aiEnabled = true;
  bool _aiStopped = false;
  String _aiMode = 'Full Auto';
  double _aiConfidence = 82.0;

  void _handleStopAI() {
    setState(() {
      _aiStopped = true;
      _aiEnabled = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ All AI actions have been stopped'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleSignIn() {
    // Navigate to login screen
    Navigator.pushNamed(context, '/login');
  }

  void _handleCreateAccount() {
    // Navigate to signup screen
    Navigator.pushNamed(context, '/signup');
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Logout?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle logout
              context.read<UserProvider>().logout();
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      body: Consumer2<TaskProvider, UserProvider>(
        builder: (context, taskProvider, userProvider, _) {
          final activeTasks = taskProvider.activeTasks;
          final selectedTaskId =
              activeTasks.isNotEmpty ? activeTasks.first.id : null;
          final isLoggedIn = userProvider.user != null;
          final userName = userProvider.user?.name ?? 'User';

          if (isMobile) {
            // Mobile Layout
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // Auth Header
                      AuthHeader(
                        isLoggedIn: isLoggedIn,
                        userName: userName,
                        userEmail: userProvider.user?.email,
                        riskLevel: 'Moderate',
                        onSignIn: _handleSignIn,
                        onCreateAccount: _handleCreateAccount,
                        onLogout: _handleLogout,
                      ),
                      // AI Status Banner
                      if (isLoggedIn)
                        AIStatusBanner(
                          aiEnabled: _aiEnabled,
                          aiMode: _aiMode,
                          dataSourcesMonitored: 12,
                          confidenceScore: _aiConfidence,
                          onAITapped: () {
                            // Open AI settings
                          },
                        ),
                      // Mobile Header
                      Container(
                        color: const Color(0xFF1F2937),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Builder(
                              builder: (context) => GestureDetector(
                                onTap: () =>
                                    Scaffold.of(context).openDrawer(),
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
                      // Live Panel
                      if (selectedTaskId != null)
                        LiveUpdatesPanel(taskId: selectedTaskId),
                    ],
                  ),
                ),
                // Emergency Stop Button
                if (isLoggedIn && _aiEnabled)
                  EmergencyStopButton(
                    onStop: _handleStopAI,
                    isStopped: _aiStopped,
                  ),
              ],
            );
          } else if (isTablet) {
            // Tablet Layout
            return Stack(
              children: [
                Column(
                  children: [
                    // Auth Header
                    AuthHeader(
                      isLoggedIn: isLoggedIn,
                      userName: userName,
                      userEmail: userProvider.user?.email,
                      riskLevel: 'Moderate',
                      onSignIn: _handleSignIn,
                      onCreateAccount: _handleCreateAccount,
                      onLogout: _handleLogout,
                    ),
                    // AI Status Banner
                    if (isLoggedIn)
                      AIStatusBanner(
                        aiEnabled: _aiEnabled,
                        aiMode: _aiMode,
                        dataSourcesMonitored: 12,
                        confidenceScore: _aiConfidence,
                        onAITapped: () {
                          // Open AI settings
                        },
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          Sidebar(
                            isCollapsed: true,
                          ),
                          Expanded(
                            child: DashboardContent(),
                          ),
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
                      ),
                    ),
                    // Trust Bar at bottom
                    if (isLoggedIn)
                      TrustBar(
                        readOnlyMode: false,
                        withdrawalEnabled: false,
                        tradesWithinLimits: true,
                        riskLevel: 'Moderate',
                      ),
                    // Trust Reinforcement Footer
                    if (isLoggedIn)
                      TrustReinforcementFooter(
                        isAIActive: _aiEnabled,
                        userEmail: userProvider.user?.email,
                      ),
                  ],
                ),
                // Emergency Stop Button
                if (isLoggedIn && _aiEnabled)
                  EmergencyStopButton(
                    onStop: _handleStopAI,
                    isStopped: _aiStopped,
                  ),
              ],
            );
          } else {
            // Desktop Layout
            return Stack(
              children: [
                Column(
                  children: [
                    // Auth Header
                    AuthHeader(
                      isLoggedIn: isLoggedIn,
                      userName: userName,
                      userEmail: userProvider.user?.email,
                      riskLevel: 'Moderate',
                      onSignIn: _handleSignIn,
                      onCreateAccount: _handleCreateAccount,
                      onLogout: _handleLogout,
                    ),
                    // AI Status Banner
                    if (isLoggedIn)
                      AIStatusBanner(
                        aiEnabled: _aiEnabled,
                        aiMode: _aiMode,
                        dataSourcesMonitored: 12,
                        confidenceScore: _aiConfidence,
                        onAITapped: () {
                          // Open AI settings
                        },
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          Sidebar(),
                          Expanded(
                            flex: 3,
                            child: DashboardContent(),
                          ),
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
                                child:
                                    LiveUpdatesPanel(taskId: selectedTaskId),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Trust Bar at bottom
                    if (isLoggedIn)
                      TrustBar(
                        readOnlyMode: false,
                        withdrawalEnabled: false,
                        tradesWithinLimits: true,
                        riskLevel: 'Moderate',
                      ),
                    // Trust Reinforcement Footer
                    if (isLoggedIn)
                      TrustReinforcementFooter(
                        isAIActive: _aiEnabled,
                        userEmail: userProvider.user?.email,
                      ),
                  ],
                ),
                // Emergency Stop Button
                if (isLoggedIn && _aiEnabled)
                  EmergencyStopButton(
                    onStop: _handleStopAI,
                    isStopped: _aiStopped,
                  ),
              ],
            );
          }
        },
      ),
    );
  }
}
