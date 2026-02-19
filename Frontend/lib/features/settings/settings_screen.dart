import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forex_companion/config/theme.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _notificationPairController = TextEditingController(text: 'EUR/USD');
  final _emailRecipientController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  bool _isEditing = false;
  bool _loadingNotificationPrefs = false;
  bool _savingNotificationPrefs = false;
  bool _sendingAutonomousTest = false;
  String? _notificationPrefsError;
  Timer? _notificationSaveDebounce;
  final _telegramChatIdController = TextEditingController();
  final _discordWebhookController = TextEditingController();
  final _xWebhookController = TextEditingController();
  final _genericWebhookController = TextEditingController();
  final _smsWebhookController = TextEditingController();
  final _whatsappWebhookController = TextEditingController();
  bool _autonomousModeEnabled = true;
  String _autonomousProfile = 'balanced';
  double _autonomousMinConfidence = 0.62;
  Map<String, bool> _notificationChannels = {
    'in_app': true,
    'email': true,
    'sms': false,
    'whatsapp': false,
    'telegram': false,
    'discord': false,
    'x': false,
    'webhook': false,
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _emailRecipientController.text = user.email;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationPreferences();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _notificationPairController.dispose();
    _emailRecipientController.dispose();
    _phoneNumberController.dispose();
    _whatsappNumberController.dispose();
    _telegramChatIdController.dispose();
    _discordWebhookController.dispose();
    _xWebhookController.dispose();
    _genericWebhookController.dispose();
    _smsWebhookController.dispose();
    _whatsappWebhookController.dispose();
    _notificationSaveDebounce?.cancel();
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

  Future<void> _loadNotificationPreferences() async {
    if (!mounted) return;
    setState(() {
      _loadingNotificationPrefs = true;
      _notificationPrefsError = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getNotificationPreferences();
      final channelsRaw = response['channels'];
      final autonomousMode = response['autonomous_mode'] == true;
      final autonomousProfile =
          _normalizeAutonomousProfile(_readString(response['autonomous_profile']));
      final autonomousMinConfidence = _readDouble(
        response['autonomous_min_confidence'],
        _autonomousMinConfidence,
      ).clamp(0.4, 0.95);
      if (channelsRaw is Map) {
        final updated = Map<String, bool>.from(_notificationChannels);
        for (final key in updated.keys) {
          updated[key] = channelsRaw[key] == true;
        }
        if (!mounted) return;
        setState(() {
          _notificationChannels = updated;
          _autonomousModeEnabled = autonomousMode;
          _autonomousProfile = autonomousProfile;
          _autonomousMinConfidence = autonomousMinConfidence;
        });
        _setChannelSettingsFromServer(response['channel_settings']);
      } else if (response['error'] != null) {
        await apiService.setNotificationPreferences(
          enabledChannels: _enabledNotificationChannels(),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationPrefsError = 'Unable to load notification channels.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingNotificationPrefs = false;
        });
      }
    }
  }

  void _onNotificationChannelChanged(String channel, bool enabled) {
    setState(() {
      _notificationChannels[channel] = enabled;
      _notificationPrefsError = null;
    });
    _scheduleNotificationPreferencesSave();
  }

  void _scheduleNotificationPreferencesSave() {
    _notificationSaveDebounce?.cancel();
    _notificationSaveDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        _saveNotificationPreferences(showSuccessSnack: false);
      },
    );
  }

  Future<void> _saveNotificationPreferences({bool showSuccessSnack = false}) async {
    if (!mounted) return;
    setState(() {
      _savingNotificationPrefs = true;
    });

    try {
      final apiService = context.read<ApiService>();
      await apiService.setNotificationPreferences(
            enabledChannels: _enabledNotificationChannels(),
            autonomousMode: _autonomousModeEnabled,
            autonomousProfile: _autonomousProfile,
            autonomousMinConfidence: _autonomousMinConfidence,
            channelSettings: _currentChannelSettings(),
          );
      await apiService.configureAutonomyGuardrails(
        level: _autonomousModeEnabled ? _autonomyLevelForProfile() : 'assisted',
        probation: _probationPolicyForProfile(),
        riskBudget: _riskBudgetForProfile(),
      );
      if (!mounted) return;
      if (showSuccessSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings updated'),
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationPrefsError = 'Unable to save notification settings.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update notification settings'),
          backgroundColor: AppColors.stopButton,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingNotificationPrefs = false;
        });
      }
    }
  }

  List<String> _enabledNotificationChannels() {
    final enabled = <String>[];
    _notificationChannels.forEach((key, value) {
      if (value) enabled.add(key);
    });
    return enabled;
  }

  void _setChannelSettingsFromServer(dynamic raw) {
    if (raw is! Map) return;
    _emailRecipientController.text = _readString(raw['email_to']);
    if (_emailRecipientController.text.isEmpty) {
      _emailRecipientController.text = _emailController.text.trim();
    }
    _phoneNumberController.text = _readString(raw['phone_number']);
    _whatsappNumberController.text = _readString(raw['whatsapp_number']);
    _telegramChatIdController.text = _readString(raw['telegram_chat_id']);
    _discordWebhookController.text = _readString(raw['discord_webhook_url']);
    _xWebhookController.text = _readString(raw['x_webhook_url']);
    _genericWebhookController.text = _readString(raw['webhook_url']);
    _smsWebhookController.text = _readString(raw['sms_webhook_url']);
    _whatsappWebhookController.text = _readString(raw['whatsapp_webhook_url']);
  }

  String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  double _readDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  String _normalizeAutonomousProfile(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'conservative') return normalized;
    if (normalized == 'aggressive') return normalized;
    return 'balanced';
  }

  Map<String, dynamic> _currentChannelSettings() {
    return {
      'email_to': _emailRecipientController.text.trim(),
      'phone_number': _phoneNumberController.text.trim(),
      'whatsapp_number': _whatsappNumberController.text.trim(),
      'telegram_chat_id': _telegramChatIdController.text.trim(),
      'discord_webhook_url': _discordWebhookController.text.trim(),
      'x_webhook_url': _xWebhookController.text.trim(),
      'webhook_url': _genericWebhookController.text.trim(),
      'sms_webhook_url': _smsWebhookController.text.trim(),
      'whatsapp_webhook_url': _whatsappWebhookController.text.trim(),
    };
  }

  void _onAutonomousModeChanged(bool enabled) {
    setState(() {
      _autonomousModeEnabled = enabled;
      _notificationPrefsError = null;
    });
    _scheduleNotificationPreferencesSave();
  }

  void _onAutonomousProfileChanged(String profile) {
    setState(() {
      _autonomousProfile = _normalizeAutonomousProfile(profile);
      _notificationPrefsError = null;
    });
    _scheduleNotificationPreferencesSave();
  }

  void _onAutonomousConfidenceChanged(double value) {
    setState(() {
      _autonomousMinConfidence = value.clamp(0.4, 0.95);
      _notificationPrefsError = null;
    });
    _scheduleNotificationPreferencesSave();
  }

  String _autonomyLevelForProfile() {
    switch (_autonomousProfile) {
      case 'conservative':
        return 'assisted';
      case 'aggressive':
        return 'full_auto';
      default:
        return 'guarded_auto';
    }
  }

  Map<String, dynamic> _riskBudgetForProfile() {
    if (_autonomousProfile == 'conservative') {
      return {
        'max_risk_per_trade_percent': 0.5,
        'daily_loss_limit_percent': 2.0,
        'weekly_loss_limit_percent': 5.0,
        'max_drawdown_percent': 8.0,
      };
    }
    if (_autonomousProfile == 'aggressive') {
      return {
        'max_risk_per_trade_percent': 1.5,
        'daily_loss_limit_percent': 4.0,
        'weekly_loss_limit_percent': 10.0,
        'max_drawdown_percent': 15.0,
      };
    }
    return {
      'max_risk_per_trade_percent': 1.0,
      'daily_loss_limit_percent': 3.0,
      'weekly_loss_limit_percent': 8.0,
      'max_drawdown_percent': 12.0,
    };
  }

  Map<String, dynamic> _probationPolicyForProfile() {
    if (_autonomousProfile == 'conservative') {
      return {
        'min_paper_trades': 30,
        'min_win_rate_percent': 60.0,
        'max_drawdown_percent': 10.0,
        'min_active_days': 7,
      };
    }
    if (_autonomousProfile == 'aggressive') {
      return {
        'min_paper_trades': 15,
        'min_win_rate_percent': 52.0,
        'max_drawdown_percent': 14.0,
        'min_active_days': 4,
      };
    }
    return {
      'min_paper_trades': 20,
      'min_win_rate_percent': 55.0,
      'max_drawdown_percent': 12.0,
      'min_active_days': 5,
    };
  }

  Future<void> _sendAutonomousTestAlert() async {
    final pair = _notificationPairController.text.trim().toUpperCase();
    if (pair.isEmpty || !pair.contains('/')) {
      setState(() {
        _notificationPrefsError = 'Enter pair like EUR/USD for autonomous test.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _sendingAutonomousTest = true;
      _notificationPrefsError = null;
    });
    try {
      final response = await context.read<ApiService>().sendAutonomousStudyAlert(
            pair: pair,
            userInstruction: 'Autonomous safety test',
          );
      if (!mounted) return;
      final success = response['success'] == true;
      final reason = _readString(response['reason']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Autonomous alert sent for $pair'
                : (reason.isNotEmpty ? reason : 'Autonomous alert was skipped'),
          ),
          backgroundColor: success ? AppColors.primaryGreen : AppColors.stopButton,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationPrefsError = 'Unable to send autonomous test alert.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingAutonomousTest = false;
        });
      }
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
                            _buildNotificationChannelsPanel(),
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

  Widget _buildNotificationChannelsPanel() {
    final busy = _loadingNotificationPrefs || _savingNotificationPrefs || _sendingAutonomousTest;
    final confidencePercent = (_autonomousMinConfidence * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active,
                color: AppColors.primaryBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Notification Channels',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_loadingNotificationPrefs)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: busy ? null : _loadNotificationPreferences,
                  tooltip: 'Refresh channels',
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Autonomous Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: _autonomousModeEnabled,
                      onChanged: busy ? null : _onAutonomousModeChanged,
                      activeThumbColor: AppColors.primaryGreen,
                      activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.35),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _autonomousModeEnabled
                      ? 'Deep-study safety gates are active for autonomous alerts.'
                      : 'Autonomous safety gates are disabled.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _autonomousProfile,
                  isDense: true,
                  dropdownColor: const Color(0xFF1F2937),
                  decoration: InputDecoration(
                    labelText: 'Safety Profile',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'conservative',
                      child: Text('Conservative', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 'balanced',
                      child: Text('Balanced', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 'aggressive',
                      child: Text('Aggressive', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          _onAutonomousProfileChanged(value);
                        },
                ),
                const SizedBox(height: 10),
                Text(
                  'Minimum Deep-Study Confidence: $confidencePercent%',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Slider(
                  value: _autonomousMinConfidence,
                  min: 0.4,
                  max: 0.95,
                  divisions: 11,
                  label: '$confidencePercent%',
                  onChanged: busy ? null : _onAutonomousConfidenceChanged,
                  activeColor: AppColors.primaryBlue,
                  inactiveColor: Colors.white24,
                ),
                _buildChannelSettingField(
                  controller: _notificationPairController,
                  label: 'Autonomous Test Pair',
                  hint: 'EUR/USD',
                  icon: Icons.show_chart,
                  busy: busy,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: busy ? null : _sendAutonomousTestAlert,
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: Text(_sendingAutonomousTest ? 'Sending...' : 'Send Test Alert'),
                    style: AppTheme.glassTextButtonStyle(
                      tintColor: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildNotificationChannelToggle(
            keyName: 'in_app',
            icon: Icons.phone_iphone,
            title: 'In-App',
            subtitle: 'Show alerts in app',
            enabled: busy,
          ),
          _buildNotificationChannelToggle(
            keyName: 'email',
            icon: Icons.email_outlined,
            title: 'Email (Gmail)',
            subtitle: 'Send deep-study alerts to email',
            enabled: busy,
          ),
          _buildNotificationChannelToggle(
            keyName: 'sms',
            icon: Icons.sms_outlined,
            title: 'SMS',
            subtitle: 'Send urgent alerts to phone SMS',
            enabled: busy,
          ),
          _buildNotificationChannelToggle(
            keyName: 'whatsapp',
            icon: Icons.chat_bubble_outline,
            title: 'WhatsApp',
            subtitle: 'Send concise alerts to WhatsApp',
            enabled: busy,
          ),
          _buildNotificationChannelToggle(
            keyName: 'telegram',
            icon: Icons.telegram,
            title: 'Telegram',
            subtitle: 'Send alerts to Telegram bot',
            enabled: busy,
          ),
          _buildNotificationChannelToggle(
            keyName: 'discord',
            icon: Icons.forum_outlined,
            title: 'Discord',
            subtitle: 'Send alerts to Discord webhook',
            enabled: busy,
          ),
          _buildNotificationChannelToggle(
            keyName: 'x',
            icon: Icons.alternate_email,
            title: 'X',
            subtitle: 'Send alerts to X integration',
            enabled: busy,
          ),
          _buildNotificationChannelToggle(
            keyName: 'webhook',
            icon: Icons.link,
            title: 'Webhook',
            subtitle: 'Send full payload to external automations',
            enabled: busy,
          ),
          const SizedBox(height: 6),
          _buildChannelSettingField(
            controller: _emailRecipientController,
            label: 'Email Recipient',
            hint: 'yourname@gmail.com',
            icon: Icons.email_outlined,
            busy: busy,
          ),
          _buildChannelSettingField(
            controller: _phoneNumberController,
            label: 'SMS Phone Number',
            hint: '+1234567890',
            icon: Icons.sms_outlined,
            busy: busy,
          ),
          _buildChannelSettingField(
            controller: _whatsappNumberController,
            label: 'WhatsApp Number',
            hint: '+1234567890',
            icon: Icons.chat_bubble_outline,
            busy: busy,
          ),
          _buildChannelSettingField(
            controller: _telegramChatIdController,
            label: 'Telegram Chat ID',
            hint: 'e.g. 123456789',
            icon: Icons.telegram,
            busy: busy,
          ),
          _buildChannelSettingField(
            controller: _discordWebhookController,
            label: 'Discord Webhook URL',
            hint: 'https://discord.com/api/webhooks/...',
            icon: Icons.forum_outlined,
            busy: busy,
          ),
          _buildChannelSettingField(
            controller: _xWebhookController,
            label: 'X Integration Webhook URL',
            hint: 'https://your-x-service.example.com/post',
            icon: Icons.alternate_email,
            busy: busy,
          ),
          _buildChannelSettingField(
            controller: _genericWebhookController,
            label: 'Generic Webhook URL',
            hint: 'https://your-webhook.example.com/notify',
            icon: Icons.link,
            busy: busy,
          ),
          _buildChannelSettingField(
            controller: _smsWebhookController,
            label: 'SMS Gateway Webhook URL',
            hint: 'https://your-sms-gateway.example.com/send',
            icon: Icons.sms_outlined,
            busy: busy,
          ),
          _buildChannelSettingField(
            controller: _whatsappWebhookController,
            label: 'WhatsApp Gateway Webhook URL',
            hint: 'https://your-whatsapp-gateway.example.com/send',
            icon: Icons.chat_bubble_outline,
            busy: busy,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: busy
                  ? null
                  : () => _saveNotificationPreferences(showSuccessSnack: true),
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save Autonomous Settings'),
              style: AppTheme.glassTextButtonStyle(
                tintColor: AppColors.primaryBlue,
              ),
            ),
          ),
          if (_savingNotificationPrefs) ...[
            const SizedBox(height: 8),
            Row(
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Saving channels...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          if (_notificationPrefsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _notificationPrefsError!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationChannelToggle({
    required String keyName,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
  }) {
    final selected = _notificationChannels[keyName] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: selected,
            onChanged: enabled
                ? null
                : (value) => _onNotificationChannelChanged(keyName, value),
            activeThumbColor: AppColors.primaryGreen,
            activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSettingField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool busy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        enabled: !busy,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
          prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 16),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          ),
          isDense: true,
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
