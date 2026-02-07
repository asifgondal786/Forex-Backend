import 'package:flutter/material.dart';
import 'package:forex_companion/config/theme.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../providers/user_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.updateUser(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isEditing = false);

    if (userProvider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${userProvider.error}'),
          backgroundColor: AppColors.stopButton,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AppBackground(
        child: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final user = userProvider.user;

            if (user == null) {
              return const Center(
                child: Text(
                  'No user data available',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      _buildSectionCard(
                        title: 'Profile Information',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                if (!_isEditing)
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _isEditing = true),
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit'),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Avatar
                            Center(
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.primaryBlue,
                                child: Text(
                                  user.initials,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Name Field
                            _buildField(
                              controller: _nameController,
                              enabled: _isEditing,
                              label: 'Name',
                              icon: Icons.person,
                            ),

                            const SizedBox(height: 16),

                            // Email Field
                            _buildField(
                              controller: _emailController,
                              enabled: _isEditing,
                              label: 'Email',
                              icon: Icons.email,
                            ),

                            const SizedBox(height: 16),

                            // Plan
                            _buildField(
                              controller: TextEditingController(
                                text: user.plan.displayName,
                              ),
                              enabled: false,
                              label: 'Plan',
                              icon: Icons.star,
                            ),

                            if (_isEditing) ...[
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() => _isEditing = false);
                                        _nameController.text = user.name;
                                        _emailController.text = user.email;
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: userProvider.isLoading
                                          ? null
                                          : _saveProfile,
                                      style: AppTheme.glassElevatedButtonStyle(
                                        tintColor: AppColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: userProvider.isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Save'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Preferences Section
                      _buildSectionCard(
                        title: 'Preferences',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SettingsTile(
                              icon: Icons.notifications,
                              title: 'Notifications',
                              subtitle: 'Manage notification preferences',
                              onTap: () {},
                            ),
                            const Divider(height: 32, color: Colors.white24),
                            _SettingsTile(
                              icon: Icons.language,
                              title: 'Language',
                              subtitle: 'English (US)',
                              onTap: () {},
                            ),
                            const Divider(height: 32, color: Colors.white24),
                            _SettingsTile(
                              icon: Icons.dark_mode,
                              title: 'Theme',
                              subtitle: 'Dark mode',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // About Section
                      _buildSectionCard(
                        title: 'About',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SettingsTile(
                              icon: Icons.info,
                              title: 'Version',
                              subtitle: '1.0.0',
                              onTap: null,
                            ),
                            const Divider(height: 32, color: Colors.white24),
                            _SettingsTile(
                              icon: Icons.privacy_tip,
                              title: 'Privacy Policy',
                              subtitle: 'View our privacy policy',
                              onTap: () {},
                            ),
                            const Divider(height: 32, color: Colors.white24),
                            _SettingsTile(
                              icon: Icons.description,
                              title: 'Terms of Service',
                              subtitle: 'View terms of service',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Danger Zone
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Danger Zone',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _SettingsTile(
                              icon: Icons.logout,
                              title: 'Log Out',
                              subtitle: 'Sign out of your account',
                              iconColor: Colors.redAccent,
                              onTap: () {
                                _showLogoutDialog();
                              },
                            ),
                            const Divider(height: 32, color: Colors.white24),
                            _SettingsTile(
                              icon: Icons.delete_forever,
                              title: 'Delete Account',
                              subtitle: 'Permanently delete your account',
                              iconColor: Colors.redAccent,
                              onTap: () {
                                _showDeleteAccountDialog();
                              },
                            ),
                          ],
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

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required bool enabled,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<UserProvider>().clearUser();
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
            style: AppTheme.glassElevatedButtonStyle(
              tintColor: Colors.red,
              foregroundColor: Colors.white,
              fillOpacity: 0.18,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement account deletion
              Navigator.pop(context);
            },
            style: AppTheme.glassElevatedButtonStyle(
              tintColor: Colors.red,
              foregroundColor: Colors.white,
              fillOpacity: 0.18,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primaryBlue).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: Colors.white38,
              ),
          ],
        ),
      ),
    );
  }
}
