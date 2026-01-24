import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AlertsRiskPanel extends StatefulWidget {
  const AlertsRiskPanel({super.key});

  @override
  State<AlertsRiskPanel> createState() => _AlertsRiskPanelState();
}

class _AlertsRiskPanelState extends State<AlertsRiskPanel> {
  bool _pushNotifications = true;
  bool _emailAlerts = false;
  bool _tradingAlerts = true;
  bool _riskAlerts = true;

  final List<AlertItem> _alerts = [
    AlertItem(
      type: 'Critical',
      message: 'Daily loss limit reached: -2.0%',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      severity: AlertSeverity.critical,
      icon: Icons.warning_amber_rounded,
    ),
    AlertItem(
      type: 'Warning',
      message: 'Position size exceeds recommended limit',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      severity: AlertSeverity.warning,
      icon: Icons.notifications_active,
    ),
    AlertItem(
      type: 'Info',
      message: 'EUR/USD trade executed: BUY @ 1.0950',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      severity: AlertSeverity.info,
      icon: Icons.info_rounded,
    ),
    AlertItem(
      type: 'Success',
      message: 'GBP/USD trade closed with +125 pips profit',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      severity: AlertSeverity.success,
      icon: Icons.check_circle_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
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
                  Text(
                    '🚨 Alerts & Risk',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time notifications & risk monitoring',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              // Risk Level Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Medium Risk',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Risk Level Indicator
          _buildRiskIndicator(),
          const SizedBox(height: 24),

          // Notification Preferences
          _buildSectionHeader('Notification Preferences'),
          const SizedBox(height: 12),

          _buildToggleSetting(
            'Push Notifications',
            'Receive instant push alerts',
            _pushNotifications,
            (value) => setState(() => _pushNotifications = value),
            Icons.notifications,
          ),
          const SizedBox(height: 10),

          _buildToggleSetting(
            'Email Alerts',
            'Send daily summary emails',
            _emailAlerts,
            (value) => setState(() => _emailAlerts = value),
            Icons.email,
          ),
          const SizedBox(height: 10),

          _buildToggleSetting(
            'Trading Alerts',
            'Notify on trade execution',
            _tradingAlerts,
            (value) => setState(() => _tradingAlerts = value),
            Icons.trending_up,
          ),
          const SizedBox(height: 10),

          _buildToggleSetting(
            'Risk Alerts',
            'Alert when limits approached',
            _riskAlerts,
            (value) => setState(() => _riskAlerts = value),
            Icons.shield,
          ),
          const SizedBox(height: 24),

          // Recent Alerts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Recent Alerts'),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'View All →',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Alerts List
          ...List.generate(
            _alerts.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildAlertItem(_alerts[index], index),
            ),
          ),

          const SizedBox(height: 16),

          // Clear All Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All alerts cleared'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(16),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.08),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              child: const Text('Clear All Alerts'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.15),
            const Color(0xFFF59E0B).withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Risk Level',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '45%',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.45,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFF59E0B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRiskMetric('Daily Loss', '-1.2%', '/ -2.0%'),
              _buildRiskMetric('Positions', '3', '/ 5'),
              _buildRiskMetric('Drawdown', '-8.5%', '/ -10%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskMetric(String label, String value, String limit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          limit,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[400],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildToggleSetting(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF10B981),
              activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
              inactiveThumbColor: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(AlertItem alert, int index) {
    final backgroundColor = _getAlertBackgroundColor(alert.severity);
    final borderColor = _getAlertBorderColor(alert.severity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.1),
        border: Border.all(
          color: borderColor.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            alert.icon,
            color: borderColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      alert.type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: borderColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      _formatTime(alert.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[300],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideX(
          begin: 0.2,
          delay: Duration(milliseconds: index * 50),
        );
  }

  Color _getAlertBackgroundColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFEF4444);
      case AlertSeverity.warning:
        return const Color(0xFFF59E0B);
      case AlertSeverity.info:
        return const Color(0xFF3B82F6);
      case AlertSeverity.success:
        return const Color(0xFF10B981);
    }
  }

  Color _getAlertBorderColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFEF4444);
      case AlertSeverity.warning:
        return const Color(0xFFF59E0B);
      case AlertSeverity.info:
        return const Color(0xFF3B82F6);
      case AlertSeverity.success:
        return const Color(0xFF10B981);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class AlertItem {
  final String type;
  final String message;
  final DateTime timestamp;
  final AlertSeverity severity;
  final IconData icon;

  AlertItem({
    required this.type,
    required this.message,
    required this.timestamp,
    required this.severity,
    required this.icon,
  });
}

enum AlertSeverity { critical, warning, info, success }
