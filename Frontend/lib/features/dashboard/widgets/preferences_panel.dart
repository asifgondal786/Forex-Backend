import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/user_preferences_service.dart';

class PreferencesPanel extends StatefulWidget {
  const PreferencesPanel({super.key});

  @override
  State<PreferencesPanel> createState() => _PreferencesPanelState();
}

class _PreferencesPanelState extends State<PreferencesPanel> {
  late UserPreferencesService _preferencesService;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _autoTradeEnabled = false;
  String _riskLevel = 'medium';

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    _preferencesService = UserPreferencesService();
    await _preferencesService.initialize();
    setState(() {
      _notificationsEnabled = _preferencesService.isNotificationsEnabled();
      _soundEnabled = _preferencesService.isSoundEnabled();
      _autoTradeEnabled = _preferencesService.isAutoTradeEnabled();
      _riskLevel = _preferencesService.getRiskLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚙️ Preferences & Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize your trading experience',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Theme Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  themeProvider.isDarkMode
                                      ? Icons.brightness_2
                                      : Icons.brightness_7,
                                  color: Colors.grey[400],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Dark Mode',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[300],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              themeProvider.isDarkMode
                                  ? 'Currently enabled'
                                  : 'Currently disabled',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                          activeThumbColor: const Color(0xFF10B981),
                          activeTrackColor:
                              const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notifications Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildToggleSetting(
                  'Enable Notifications',
                  'Receive trading alerts and updates',
                  _notificationsEnabled,
                  (value) async {
                    setState(() => _notificationsEnabled = value);
                    await _preferencesService
                        .setNotificationsEnabled(value);
                  },
                ),
                const SizedBox(height: 12),
                _buildToggleSetting(
                  'Sound Effects',
                  'Play sounds for trade notifications',
                  _soundEnabled,
                  (value) async {
                    setState(() => _soundEnabled = value);
                    await _preferencesService.setSoundEnabled(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Trading Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trading Preferences',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildToggleSetting(
                  'Auto Trading',
                  'Enable automated trading features',
                  _autoTradeEnabled,
                  (value) async {
                    setState(() => _autoTradeEnabled = value);
                    await _preferencesService.setAutoTradeEnabled(value);
                  },
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Risk Level',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Set your preferred risk tolerance',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _riskLevel,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: const Color(0xFF1A1F2E),
                        items: ['low', 'medium', 'high'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: value == 'low'
                                          ? const Color(0xFF10B981)
                                          : value == 'medium'
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    value.capitalize(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      textBaseline:
                                          TextBaseline.alphabetic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value != null) {
                            setState(() => _riskLevel = value);
                            await _preferencesService.setRiskLevel(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preferences saved successfully!'),
                    backgroundColor: Color(0xFF10B981),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check),
              label: const Text(
                'Save Preferences',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideY(begin: 0.2);
  }

  Widget _buildToggleSetting(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF10B981),
          activeTrackColor:
              const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
