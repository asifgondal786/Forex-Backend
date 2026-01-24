import 'package:flutter/material.dart';

/// Trust Bar Widget - Displays user permissions and security status
/// Shows read-only access, withdrawal permissions, and trade limits
class TrustBar extends StatelessWidget {
  final bool readOnlyMode;
  final bool withdrawalEnabled;
  final bool tradesWithinLimits;
  final String? riskLevel;

  const TrustBar({
    Key? key,
    required this.readOnlyMode,
    required this.withdrawalEnabled,
    required this.tradesWithinLimits,
    this.riskLevel = 'Moderate',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Read-Only Access
            _TrustIndicator(
              icon: Icons.lock,
              label: readOnlyMode
                  ? 'Read-Only Access Enabled'
                  : 'Read & Write Access',
              isActive: readOnlyMode,
              color: readOnlyMode
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 24),

            // Withdrawal Permission
            _TrustIndicator(
              icon: Icons.security,
              label: withdrawalEnabled
                  ? 'Withdrawals Enabled'
                  : 'No Withdrawal Permission',
              isActive: !withdrawalEnabled,
              color: withdrawalEnabled
                  ? const Color(0xFF10B981)
                  : const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 24),

            // Trade Limits
            _TrustIndicator(
              icon: Icons.trending_up,
              label: tradesWithinLimits
                  ? 'Trades Executed Within Limits'
                  : 'Warning: Trades Exceeding Limits',
              isActive: tradesWithinLimits,
              color: tradesWithinLimits
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;

  const _TrustIndicator({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isActive)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.check_circle,
              size: 12,
              color: color,
            ),
          ),
      ],
    );
  }
}
