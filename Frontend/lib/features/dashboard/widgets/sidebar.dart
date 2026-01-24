import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/models/user.dart';

class Sidebar extends StatefulWidget {
  final bool isCollapsed;

  const Sidebar({super.key, this.isCollapsed = false});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Container(
      width: widget.isCollapsed ? 80 : 280,
      color: AppColors.sidebarDark,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _scrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Logo & App Name
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isCollapsed ? 16.0 : 24.0,
                          vertical: 24.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryBlue,
                                    AppColors.primaryGreen,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.currency_exchange,
                                color: Colors.white,
                              ),
                            )
                                .animate()
                                .scale(
                                  begin: const Offset(0.8, 0.8),
                                  duration: const Duration(milliseconds: 600),
                                )
                                .fadeIn(),
                            if (!widget.isCollapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: const Text(
                                  'Forex Companion',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                )
                                    .animate()
                                    .fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600),
                                    )
                                    .slideX(
                                      begin: -0.2,
                                      end: 0,
                                      duration:
                                          const Duration(milliseconds: 600),
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Navigation Items
                      _buildMenuItem(context, Icons.dashboard, 'Dashboard',
                          '/', widget.isCollapsed, 0),
                      _buildMenuItem(context, Icons.add_circle_outline,
                          'Task Creation', '/create-task', widget.isCollapsed, 1),
                      _buildMenuItem(context, Icons.history, 'Task History',
                          '/task-history', widget.isCollapsed, 2),
                      _buildMenuItem(context, Icons.psychology,
                          'AI Assistant', '/ai-chat', widget.isCollapsed, 3),
                      _buildMenuItem(context, Icons.settings, 'Settings',
                          '/settings', widget.isCollapsed, 4),
                      const Spacer(),
                      // User Profile Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            );
                          },
                          child: widget.isCollapsed
                              ? _buildCollapsedProfile(context, user)
                              : _buildExpandedProfile(context, user),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: const Duration(milliseconds: 600),
                          )
                          .slideY(
                            begin: 0.2,
                            end: 0,
                            duration: const Duration(milliseconds: 600),
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
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Row(
                children: [
                  Icon(
                    themeProvider.isDarkMode
                        ? Icons.brightness_2_outlined
                        : Icons.brightness_7_outlined,
                    color: Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Dark Mode',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Spacer(),
                  Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                    activeThumbColor: AppColors.primaryGreen,
                    activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.withValues(alpha: 0.5),
                  ),
                ],
              );
            },
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
  Widget _buildMenuItem(BuildContext context, IconData icon, String label,
      String route, bool isCollapsed, int delayIndex) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: isCollapsed ? label : '',
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, route),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            hoverColor: Colors.white.withOpacity(0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryBlue.withOpacity(0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: isActive
                      ? AppColors.primaryBlue.withOpacity(0.4)
                      : Colors.transparent,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment:
                    isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: isActive ? AppColors.primaryBlue : Colors.white54,
                      fontSize: 20,
                    ),
                    child: Icon(icon),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                        child: Text(label),
                      ),
                    ),
                    if (isActive)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                          .animate()
                          .scale(
                            duration: const Duration(milliseconds: 300),
                          )
                          .fadeIn(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideX(
          begin: -0.2,
          end: 0,
          delay: Duration(milliseconds: delayIndex * 50),
        );
  }
}