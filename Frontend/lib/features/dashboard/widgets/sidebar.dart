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

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  String? _hoveredRoute;
  late final AnimationController _glowController;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowPulse = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Container(
      width: widget.isCollapsed ? 80 : 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.sidebarDark.withOpacity(0.95),
            const Color(0xFF0B1220),
          ],
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryGreen.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Scrollbar(
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
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isCollapsed ? 16.0 : 24.0,
                              vertical: 24.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: widget.isCollapsed ? 44 : 52,
                                      height: widget.isCollapsed ? 44 : 52,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryBlue.withOpacity(0.35),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(
                                          'assets/images/companion_logo.png',
                                          fit: BoxFit.cover,
                                        ),
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
                                              duration: const Duration(milliseconds: 600),
                                            )
                                            .slideX(
                                              begin: -0.2,
                                              end: 0,
                                              duration: const Duration(milliseconds: 600),
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (!widget.isCollapsed) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Text(
                                      'AI Online',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!widget.isCollapsed)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'MAIN',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            context,
                            Icons.dashboard,
                            'Dashboard',
                            '/',
                            widget.isCollapsed,
                            0,
                          ),
                          _buildMenuItem(
                            context,
                            Icons.add_circle_outline,
                            'Task Creation',
                            '/create-task',
                            widget.isCollapsed,
                            1,
                          ),
                          _buildMenuItem(
                            context,
                            Icons.history,
                            'Task History',
                            '/task-history',
                            widget.isCollapsed,
                            2,
                          ),
                          _buildMenuItem(
                            context,
                            Icons.psychology,
                            'AI Assistant',
                            '/ai-chat',
                            widget.isCollapsed,
                            3,
                          ),
                          _buildMenuItem(
                            context,
                            Icons.settings,
                            'Settings',
                            '/settings',
                            widget.isCollapsed,
                            4,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
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
                      )
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
      child: const Icon(
        Icons.person_outline,
        color: Colors.white70,
        size: 24,
      ),
    );
  }

  // Helper method to build menu items
  Widget _buildMenuItem(BuildContext context, IconData icon, String label,
      String route, bool isCollapsed, int delayIndex) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;
    final iconColor = isActive ? AppColors.primaryBlue : Colors.white54;
    final isHovered = _hoveredRoute == route;

    final item = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, route),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          hoverColor: Colors.white.withOpacity(0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [
                        AppColors.primaryBlue.withOpacity(0.2),
                        AppColors.primaryBlue.withOpacity(0.05),
                      ],
                    )
                  : null,
              color: isActive ? null : Colors.transparent,
              border: Border.all(
                color: isActive
                    ? AppColors.primaryBlue.withOpacity(0.4)
                    : Colors.transparent,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment:
                  isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (isActive && !isCollapsed)
                  Container(
                    width: 3,
                    height: 18,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                AnimatedBuilder(
                  animation: _glowPulse,
                  builder: (context, child) {
                    final hoverStrength = isCollapsed && isHovered
                        ? 0.12 + (_glowPulse.value * 0.18)
                        : 0.0;
                    final blur = 10 + (_glowPulse.value * 8);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryBlue.withOpacity(0.18)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primaryBlue.withOpacity(0.45)
                              : Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: [
                          if (isActive || (isCollapsed && isHovered))
                            BoxShadow(
                              color: AppColors.primaryBlue
                                  .withOpacity(isActive ? 0.35 : hoverStrength),
                              blurRadius: isActive ? 12 : blur,
                              spreadRadius: isActive ? 1 : 2,
                            ),
                          if (isCollapsed && isHovered)
                            BoxShadow(
                              color: Colors.white.withOpacity(hoverStrength * 0.4),
                              blurRadius: blur + 6,
                            ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 14),
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
    );

    final wrapped = isCollapsed
        ? Tooltip(
            richMessage: TextSpan(
              text: label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: '\nTap to open',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220).withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            preferBelow: false,
            verticalOffset: 0,
            margin: const EdgeInsets.only(left: 16),
            child: item,
          )
        : item;

    final hoveredWrapper = isCollapsed
        ? MouseRegion(
            onEnter: (_) => setState(() => _hoveredRoute = route),
            onExit: (_) {
              if (_hoveredRoute == route) {
                setState(() => _hoveredRoute = null);
              }
            },
            child: wrapped,
          )
        : wrapped;

    return hoveredWrapper
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideX(
          begin: -0.2,
          end: 0,
          delay: Duration(milliseconds: delayIndex * 50),
        );
  }
}
