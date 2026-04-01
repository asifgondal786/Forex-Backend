import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/beginner_mode_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification preferences
  bool _emailAlerts = true;
  bool _pushAlerts = true;
  bool _whatsappAlerts = false;
  bool _tradeAlerts = true;
  bool _riskAlerts = true;
  bool _marketAlerts = false;
  bool _aiAlerts = true;

  // Theme
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'Appearance',
            scheme: scheme,
            children: [
              _ThemeSelector(
                mode: _themeMode,
                onChanged: (m) => setState(() => _themeMode = m),
                scheme: scheme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Notification Channels',
            scheme: scheme,
            children: [
              _ToggleTile(
                icon: Icons.email_outlined,
                iconColor: Colors.blue,
                title: 'Email Alerts',
                subtitle: 'Receive alerts via email',
                value: _emailAlerts,
                onChanged: (v) => setState(() => _emailAlerts = v),
                scheme: scheme,
              ),
              _Divider(scheme),
              _ToggleTile(
                icon: Icons.notifications_outlined,
                iconColor: Colors.orange,
                title: 'Push Notifications',
                subtitle: 'Mobile & web push alerts',
                value: _pushAlerts,
                onChanged: (v) => setState(() => _pushAlerts = v),
                scheme: scheme,
              ),
              _Divider(scheme),
              _ToggleTile(
                icon: Icons.chat_outlined,
                iconColor: Colors.green,
                title: 'WhatsApp Alerts',
                subtitle: 'Send alerts to WhatsApp',
                value: _whatsappAlerts,
                onChanged: (v) => setState(() => _whatsappAlerts = v),
                scheme: scheme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Alert Types',
            scheme: scheme,
            children: [
              _ToggleTile(
                icon: Icons.trending_up_rounded,
                iconColor: Colors.green,
                title: 'Trade Signals',
                subtitle: 'New AI trade opportunities',
                value: _tradeAlerts,
                onChanged: (v) => setState(() => _tradeAlerts = v),
                scheme: scheme,
              ),
              _Divider(scheme),
              _ToggleTile(
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.red,
                title: 'Risk Alerts',
                subtitle: 'Drawdown and loss cap warnings',
                value: _riskAlerts,
                onChanged: (v) => setState(() => _riskAlerts = v),
                scheme: scheme,
              ),
              _Divider(scheme),
              _ToggleTile(
                icon: Icons.candlestick_chart_rounded,
                iconColor: Colors.purple,
                title: 'Market Events',
                subtitle: 'Major price movements & news',
                value: _marketAlerts,
                onChanged: (v) => setState(() => _marketAlerts = v),
                scheme: scheme,
              ),
              _Divider(scheme),
              _ToggleTile(
                icon: Icons.auto_awesome_rounded,
                iconColor: Colors.teal,
                title: 'AI Insights',
                subtitle: 'Weekly performance reports',
                value: _aiAlerts,
                onChanged: (v) => setState(() => _aiAlerts = v),
                scheme: scheme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Safety',
            scheme: scheme,
            children: [
              Consumer<BeginnerModeProvider>(
                builder: (context, bm, _) => _ToggleTile(
                  icon: Icons.school_rounded,
                  iconColor: Colors.amber,
                  title: 'Beginner Protection Mode',
                  subtitle:
                      'Daily loss cap, leverage warnings, guided tooltips',
                  value: bm.isEnabled,
                  onChanged: bm.setEnabled,
                  scheme: scheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Account',
            scheme: scheme,
            children: [
              _NavTile(
                icon: Icons.security_rounded,
                iconColor: Colors.red,
                title: 'Security Center',
                subtitle: 'Two-factor auth, active sessions',
                onTap: () {},
                scheme: scheme,
              ),
              _Divider(scheme),
              _NavTile(
                icon: Icons.person_outline_rounded,
                iconColor: Colors.blue,
                title: 'Profile',
                subtitle: 'Edit your trading profile',
                onTap: () {},
                scheme: scheme,
              ),
              _Divider(scheme),
              _NavTile(
                icon: Icons.logout_rounded,
                iconColor: Colors.red,
                title: 'Sign Out',
                subtitle: '',
                onTap: () => _confirmSignOut(context, scheme),
                scheme: scheme,
                destructive: true,
              ),
            ],
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Tajir v1.0.0 • Phase 12',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext ctx, ColorScheme scheme) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Handle sign out
    }
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  final ColorScheme scheme;

  const _ThemeSelector({
    required this.mode,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.palette_outlined,
                    color: Colors.indigo, size: 18),
              ),
              const SizedBox(width: 14),
              Text(
                'Theme',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ThemeOption(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                selected: mode == ThemeMode.light,
                onTap: () => onChanged(ThemeMode.light),
                scheme: scheme,
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                selected: mode == ThemeMode.dark,
                onTap: () => onChanged(ThemeMode.dark),
                scheme: scheme,
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                label: 'System',
                icon: Icons.brightness_auto_rounded,
                selected: mode == ThemeMode.system,
                onTap: () => onChanged(ThemeMode.system),
                scheme: scheme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? scheme.onPrimary
                      : scheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final ColorScheme scheme;

  const _SettingsSection({
    required this.title,
    required this.children,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme scheme;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: scheme.primary,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final bool destructive;

  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.scheme,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: destructive ? Colors.red : scheme.onSurface,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withOpacity(0.5),
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurface.withOpacity(0.3),
        size: 20,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final ColorScheme scheme;
  const _Divider(this.scheme);

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: scheme.outline.withOpacity(0.1),
      indent: 66,
    );
  }
}
