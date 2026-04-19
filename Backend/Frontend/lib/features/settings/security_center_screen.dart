import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class SecurityCenterScreen extends StatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  State<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends State<SecurityCenterScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dashboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final data = await api.getSecurityDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Center'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null
                      ? _buildError()
                      : _buildContent(userName: user?.name ?? 'Trader'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 40),
        const SizedBox(height: 12),
        const Text(
          'Unable to load Security Center.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          _error ?? '',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadDashboard,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Retry'),
          style: AppTheme.glassElevatedButtonStyle(
            tintColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildContent({required String userName}) {
    final dashboard = _dashboard ?? <String, dynamic>{};
    final securityStatus =
        dashboard['security_status'] as Map<String, dynamic>? ?? {};
    final apiKeys = (dashboard['api_keys'] as List?)?.cast<Map>() ?? const [];
    final legalStatus =
        dashboard['legal_status'] as Map<String, dynamic>? ?? {};
    final recentAlerts =
        (dashboard['recent_alerts'] as List?)?.cast<String>() ?? const [];

    final apiKeysActive = securityStatus['api_keys_active'] as int? ?? 0;
    final legalCompliant = legalStatus['compliant'] == true;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security overview for $userName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Before enabling live autonomous trading, make sure these safety checks are green.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildSummaryCard(
                icon: Icons.verified_user_outlined,
                title: 'Legal & Risk Acknowledgment',
                status: legalCompliant ? 'Completed' : 'Action Required',
                statusColor:
                    legalCompliant ? AppColors.primaryGreen : AppColors.errorRed,
                body: _buildLegalBody(legalStatus),
              ),
              _buildSummaryCard(
                icon: Icons.vpn_key_outlined,
                title: 'API Keys',
                status: apiKeysActive > 0 ? '$apiKeysActive Active' : 'Not Configured',
                statusColor: apiKeysActive > 0
                    ? AppColors.primaryGreen
                    : Colors.white70,
                body: _buildApiKeyBody(apiKeys),
              ),
              _buildSummaryCard(
                icon: Icons.shield_outlined,
                title: 'Recent Security Alerts',
                status: recentAlerts.isEmpty ? 'Clean' : 'Review',
                statusColor:
                    recentAlerts.isEmpty ? AppColors.primaryGreen : AppColors.errorRed,
                body: _buildAlertsBody(recentAlerts),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildExplainerCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String status,
    required Color statusColor,
    required Widget body,
  }) {
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            body,
          ],
        ),
      ),
    );
  }

  Widget _buildLegalBody(Map<String, dynamic> legalStatus) {
    final compliant = legalStatus['compliant'] == true;
    final message = (legalStatus['message'] ?? '') as String? ?? '';
    final items = legalStatus['items_accepted'] as Map<String, dynamic>? ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compliant && message.isNotEmpty)
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        if (items.isNotEmpty) ...[
          if (message.isNotEmpty) const SizedBox(height: 6),
          ...items.entries.map(
            (entry) => Row(
              children: [
                Icon(
                  entry.value == true
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  size: 14,
                  color: entry.value == true
                      ? AppColors.primaryGreen
                      : Colors.white54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.key.replaceAll('_', ' '),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!compliant) ...[
          const SizedBox(height: 8),
          const Text(
            'Complete the legal agreement from your broker onboarding panel before enabling live autonomous trading.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildApiKeyBody(List<Map> apiKeys) {
    if (apiKeys.isEmpty) {
      return const Text(
        'No broker API keys created yet. Live execution will remain blocked until you connect a broker safely.',
        style: TextStyle(color: Colors.white70, fontSize: 11),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: apiKeys.take(3).map((raw) {
        final broker = (raw['broker'] ?? '').toString();
        final active = raw['is_active'] == true;
        final lastUsed = (raw['last_used'] ?? 'Never').toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                active ? Icons.vpn_key : Icons.vpn_key_off,
                size: 14,
                color: active ? AppColors.primaryGreen : Colors.white54,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$broker • last used: $lastUsed',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlertsBody(List<String> alerts) {
    if (alerts.isEmpty) {
      return const Text(
        'No recent security alerts. Kill switch activations, key revocations and credential access will appear here.',
        style: TextStyle(color: Colors.white70, fontSize: 11),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: alerts.reversed.take(4).map((alert) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '• $alert',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExplainerCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'How Forex Companion protects you',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Live autonomous trades are gated by legal acknowledgments, subscription checks, risk guardrails, and Macro Event Shield.\n'
            '• Before any live execution, the system generates an explain‑before‑execute card and binds a one‑time execution token.\n'
            '• High‑risk actions like kill switch, API key changes, and credential access are captured in the audit log for your review.\n'
            '• You can always revoke automation or API keys to instantly disable trading access.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}


