import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/user_provider.dart';
import '../../../core/models/user.dart';
import '../../../core/widgets/custom_snackbar.dart';

class Sidebar extends StatelessWidget {
  final bool isCollapsed;

  const Sidebar({super.key, this.isCollapsed = false});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Container(
      width: isCollapsed ? 80 : 280,
      color: AppColors.sidebarDark,
      child: Scrollbar(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Logo & App Name
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCollapsed ? 16.0 : 24.0,
                          vertical: 24.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'images/logo.png',
                              height: 36,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback if logo doesn't exist
                                return Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    borderRadius: BorderRadius.all(Radius.circular(8)),
                                  ),
                                  child: const Icon(Icons.currency_exchange, color: Colors.white),
                                );
                              },
                            ),
                            if (!isCollapsed) ...[
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Forex Companion',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Navigation Items
                      _buildMenuItem(context, Icons.dashboard, 'Dashboard', '/', isCollapsed),
                      _buildMenuItem(context, Icons.add_circle_outline, 'Task Creation', '/create-task', isCollapsed),
                      _buildMenuItem(context, Icons.history, 'Task History', '/task-history', isCollapsed),
                      _buildMenuItem(context, Icons.psychology, 'AI Assistant', '/ai-chat', isCollapsed),
                      _buildMenuItem(context, Icons.settings, 'Settings', '/settings', isCollapsed),
                      
                      const Spacer(),
                      
                      // User Profile Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isCollapsed
                              ? _buildCollapsedProfile(context, user)
                              : _buildExpandedProfile(context, user),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandedProfile(BuildContext context, User? user) {
    return Column(
      key: const ValueKey('expanded_profile'),
      children: [
        Row(
          children: [
            // Notification Bell
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white54),
              onPressed: () {},
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildAvatar(user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to Forex',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user?.plan.displayName ?? 'Free Plan',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              const Icon(Icons.brightness_6_outlined, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Dark Mode',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Switch(
                value: true, // Assuming default is dark mode
                onChanged: (value) {
                  // TODO: Implement theme switching logic using a ThemeProvider
                  CustomSnackbar.info(context, 'Theme switching not implemented yet.');
                },
                activeColor: AppColors.primaryGreen,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.5),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.settings, size: 16, color: Colors.white54),
          label: const Text(
            'Settings',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedProfile(BuildContext context, User? user) {
    return GestureDetector(
      key: const ValueKey('collapsed_profile'),
      onTap: () => Navigator.pushNamed(context, '/settings'),
      child: _buildAvatar(user),
    );
  }

  Widget _buildAvatar(User? user) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primaryGreen,
      backgroundImage: user?.avatarUrl != null
          ? NetworkImage(user!.avatarUrl!)
          : null,
      child: user?.avatarUrl == null
          ? Text(
              user?.initials ?? '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  // Helper method to build menu items
  Widget _buildMenuItem(BuildContext context, IconData icon, String label, String route, bool isCollapsed) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;
    
    final menuItemContent = Row(
      mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: isActive ? AppColors.primaryBlue : Colors.white54,
        ),
        if (!isCollapsed) ...[
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryBlue.withAlpha(51) : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, route),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: menuItemContent,
          ),
        ),
      ),
    );
  }
}