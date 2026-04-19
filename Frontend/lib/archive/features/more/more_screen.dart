import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../providers/notification_provider.dart';
import '../../providers/beginner_mode_provider.dart';
import '../../routes/app_routes.dart';
import '../notifications/notifications_screen.dart';
import '../automation/automation_screen.dart';
import '../social/social_screen.dart';
import '../settings/settings_screen.dart';
import '../risk/risk_simulator_screen.dart';
import 'package:forex_companion/features/auth/login_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = context.watch<NotificationProvider>().unreadCount;
    final beginner = context.watch<BeginnerModeProvider>();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: scheme.surface,
            elevation: 0,
            title: Text(
              'More',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: scheme.onSurface,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Profile card ─────────────────────────────────────────────
                _ProfileCard(scheme: scheme, beginner: beginner),
                const SizedBox(height: 24),

                // ── Beginner mode quick toggle ────────────────────────────────
                _BeginnerToggleCard(scheme: scheme, beginner: beginner),
                const SizedBox(height: 24),

                // ── Menu sections ─────────────────────────────────────────────
                _SectionLabel('Trading Tools', scheme),
                const SizedBox(height: 10),
                _MenuCard(
                  scheme: scheme,
                  items: [
                    _MenuItem(
                      icon: Icons.smart_toy_rounded,
                      iconColor: Colors.orange,
                      title: 'Automation',
                      subtitle: 'Trading modes & guardrails',
                      badge: null,
                      onTap: () => _push(context, const AutomationScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.people_alt_rounded,
                      iconColor: Colors.blue,
                      title: 'Social Trading',
                      subtitle: 'Leaderboard & copy-trading',
                      badge: null,
                      onTap: () => _push(context, const SocialScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.science_rounded,
                      iconColor: Colors.purple,
                      title: 'Risk Simulator',
                      subtitle: 'Model risk before you trade',
                      badge: null,
                      onTap: () => _push(context, const RiskSimulatorScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _SectionLabel('Account', scheme),
                const SizedBox(height: 10),
                _MenuCard(
                  scheme: scheme,
                  items: [
                    _MenuItem(
                      icon: Icons.admin_panel_settings_outlined,
                      iconColor: Colors.indigo,
                      title: 'User/Admin Dashboard',
                      subtitle: 'Profile, broker link and alert controls',
                      badge: null,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.profile),
                    ),
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      iconColor: Colors.teal,
                      title: 'Notifications',
                      subtitle: 'Alerts & activity feed',
                      badge: unread > 0 ? unread : null,
                      onTap: () => _push(context, const NotificationsScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      iconColor: Colors.grey,
                      title: 'Settings',
                      subtitle: 'Appearance, alerts & security',
                      badge: null,
                      onTap: () => _push(context, const SettingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _SectionLabel('Support', scheme),
                const SizedBox(height: 10),
                _MenuCard(
                  scheme: scheme,
                  items: [
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      iconColor: Colors.blue,
                      title: 'Help & FAQ',
                      subtitle: 'Guides and documentation',
                      badge: null,
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.bug_report_outlined,
                      iconColor: Colors.red,
                      title: 'Report an Issue',
                      subtitle: 'Send feedback to the team',
                      badge: null,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Sign out ──────────────────────────────────────────────────
                _MenuCard(
                  scheme: scheme,
                  items: [
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.red,
                      title: 'Sign Out',
                      subtitle: '',
                      badge: null,
                      destructive: true,
                      onTap: () => _confirmSignOut(context, scheme),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Tajir • AI Forex Financial OS • v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, ColorScheme scheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await firebase_auth.FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    // Navigate to LoginScreen and clear the stack.
    // onLoginSuccess wired back to AppShell via _AuthGate in main.dart.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          },
        ),
      ),
      (route) => false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile card
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final ColorScheme scheme;
  final BeginnerModeProvider beginner;

  const _ProfileCard({required this.scheme, required this.beginner});

  @override
  Widget build(BuildContext context) {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'demo@example.com';
    final displayName = user?.displayName ?? email.split('@').first;
    final initials =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.15),
            scheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Name & email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Edit button
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
            icon: Icon(
              Icons.edit_outlined,
              color: scheme.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Beginner mode quick toggle
// ─────────────────────────────────────────────────────────────────────────────

class _BeginnerToggleCard extends StatelessWidget {
  final ColorScheme scheme;
  final BeginnerModeProvider beginner;

  const _BeginnerToggleCard({required this.scheme, required this.beginner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: beginner.isEnabled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              Colors.amber.withValues(alpha: beginner.isEnabled ? 0.4 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.school_rounded, color: Colors.amber, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beginner Protection',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  beginner.isEnabled
                      ? 'Daily loss cap & leverage warnings active'
                      : 'Tap to enable safety guardrails',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: beginner.isEnabled,
            onChanged: beginner.setEnabled,
            activeColor: Colors.amber,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme scheme;

  const _SectionLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: scheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu card + item
// ─────────────────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final ColorScheme scheme;
  final List<_MenuItem> items;

  const _MenuCard({required this.scheme, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _MenuItemTile(item: items[i], scheme: scheme),
            if (i < items.length - 1)
              Divider(
                height: 1,
                color: scheme.outline.withValues(alpha: 0.1),
                indent: 66,
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int? badge;
  final bool destructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
    this.destructive = false,
  });
}

class _MenuItemTile extends StatelessWidget {
  final _MenuItem item;
  final ColorScheme scheme;

  const _MenuItemTile({required this.item, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: item.iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon, color: item.iconColor, size: 18),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: item.destructive ? Colors.red : scheme.onSurface,
        ),
      ),
      subtitle: item.subtitle.isNotEmpty
          ? Text(
              item.subtitle,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Notification badge
          if (item.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.badge! > 99 ? '99+' : '${item.badge}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurface.withValues(alpha: 0.3),
            size: 20,
          ),
        ],
      ),
    );
  }
}

