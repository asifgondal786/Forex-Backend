// lib/features/settings/settings_screen.dart
//
// 4-section Settings: Broker (OANDA), Risk Limits, Security, Account.
// ConnectBrokerSheet is the gate for both trading modes.

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/account_connection.dart';
import '../../providers/account_connection_provider.dart';
import '../../providers/risk_provider.dart';
import '../../routes/app_routes.dart';
import 'connect_broker_sheet.dart';

// palette — matches the rest of the app
const _kBg      = Color(0xFF0A0E1A);
const _kCard    = Color(0xFF161D2E);
const _kBorder  = Color(0xFF1E2A3D);
const _kGold    = Color(0xFFD4A853);
const _kGreen   = Color(0xFF00C896);
const _kRed     = Color(0xFFFF4560);
const _kAmber   = Color(0xFFF59E0B);
const _kBlue    = Color(0xFF3B82F6);
const _kText    = Color(0xFFE2E8F0);
const _kSubtext = Color(0xFF64748B);
const _kDivider = Color(0xFF1E2A3D);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountConnectionProvider>();
    final riskProvider    = context.watch<RiskProvider>();
    final account         = accountProvider.selectedAccount;
    final isConnected     = account?.status == AccountConnectionStatus.connected;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: _kText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kDivider),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Section 1: Broker ──────────────────────────────────────────
          _SectionHeader(
            icon: Icons.account_balance_rounded,
            label: 'Broker Connection',
            iconColor: _kGold,
          ),
          const SizedBox(height: 8),
          _BrokerConnectionTile(
            account: account,
            isConnected: isConnected,
            isLoading: accountProvider.isLoading,
            onTap: () => ConnectBrokerSheet.show(context),
            onDisconnect: account != null
                ? () => _confirmDisconnect(context, accountProvider, account.id)
                : null,
          ),
          if (accountProvider.lastError != null) ...[
            const SizedBox(height: 8),
            _ErrorBanner(accountProvider.lastError!),
          ],
          const SizedBox(height: 20),

          // ── Section 2: Risk Limits ─────────────────────────────────────
          _SectionHeader(
            icon: Icons.shield_rounded,
            label: 'Risk Guardian Limits',
            iconColor: _kAmber,
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.shield_outlined,
            iconColor: _kAmber,
            title: 'Configure limits',
            subtitle:
                'Daily loss ${riskProvider.dailyLimitPct.toStringAsFixed(1)}% '
                '· Max trades ${riskProvider.maxOpenTrades} '
                '· Risk/trade ${riskProvider.riskPerTradePct.toStringAsFixed(1)}%',
            onTap: () => _showRiskSheet(context, riskProvider),
          ),
          const SizedBox(height: 20),

          // ── Section 3: Security ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.lock_rounded,
            label: 'Security',
            iconColor: _kBlue,
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.security_rounded,
            iconColor: _kBlue,
            title: 'Security centre',
            subtitle: '2FA and session controls',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Security features coming soon')),
            ),
          ),
          const SizedBox(height: 20),

          // ── Section 4: Account ─────────────────────────────────────────
          _SectionHeader(
            icon: Icons.person_rounded,
            label: 'Account',
            iconColor: _kSubtext,
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.logout_rounded,
            iconColor: _kRed,
            title: 'Log out',
            subtitle: 'Sign out of Tajir on this device',
            destructive: true,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  // ── Disconnect confirm ─────────────────────────────────────────────────
  Future<void> _confirmDisconnect(
    BuildContext context,
    AccountConnectionProvider provider,
    String accountId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _kRed.withValues(alpha: 0.3)),
        ),
        title: const Text(
          'Disconnect broker?',
          style: TextStyle(color: _kText, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will disable both trading modes. '
          'Any running agent will be stopped first.',
          style: TextStyle(color: _kSubtext, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _kSubtext)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await provider.disconnect(accountId);
  }

  // ── Risk sheet ─────────────────────────────────────────────────────────
  Future<void> _showRiskSheet(
      BuildContext context, RiskProvider riskProvider) async {
    var dailyLimit    = riskProvider.dailyLimitPct;
    var maxTrades     = riskProvider.maxOpenTrades.toDouble();
    var riskPerTrade  = riskProvider.riskPerTradePct;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Risk Guardian Limits',
                style: TextStyle(
                  color: _kText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The guardian blocks any order that exceeds these limits.',
                style: TextStyle(color: _kSubtext, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Daily loss cap
              _SliderRow(
                label: 'Daily loss cap',
                value: dailyLimit,
                display: '${dailyLimit.toStringAsFixed(1)}%',
                min: 1,
                max: 10,
                divisions: 18,
                color: _kAmber,
                onChanged: (v) => setModal(() => dailyLimit = v),
              ),
              const SizedBox(height: 16),

              // Max open trades
              _SliderRow(
                label: 'Max open trades',
                value: maxTrades,
                display: '${maxTrades.round()}',
                min: 1,
                max: 10,
                divisions: 9,
                color: _kBlue,
                onChanged: (v) => setModal(() => maxTrades = v),
              ),
              const SizedBox(height: 16),

              // Risk per trade
              _SliderRow(
                label: 'Risk per trade',
                value: riskPerTrade,
                display: '${riskPerTrade.toStringAsFixed(1)}%',
                min: 0.5,
                max: 5,
                divisions: 9,
                color: _kGold,
                onChanged: (v) => setModal(() => riskPerTrade = v),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    riskProvider.updateDailyLimit(dailyLimit);
                    riskProvider.updateMaxOpenTrades(maxTrades.round());
                    riskProvider.updateRiskPerTrade(riskPerTrade);
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save limits',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────
  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _kBorder),
        ),
        title: const Text('Log out',
            style: TextStyle(color: _kText, fontWeight: FontWeight.w700)),
        content: const Text('Sign out of Tajir on this device?',
            style: TextStyle(color: _kSubtext)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kSubtext)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      if (Firebase.apps.isNotEmpty) {
        await firebase_auth.FirebaseAuth.instance.signOut();
      }
    } catch (_) {}

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.root, (route) => false);
    }
  }
}

// ── Broker connection tile ─────────────────────────────────────────────────
class _BrokerConnectionTile extends StatelessWidget {
  final AccountConnection? account;
  final bool isConnected;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onDisconnect;

  const _BrokerConnectionTile({
    required this.account,
    required this.isConnected,
    required this.isLoading,
    required this.onTap,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConnected
                ? _kGreen.withValues(alpha: 0.3)
                : _kBorder,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF003D2E)
                      : const Color(0xFF2D2200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: isConnected ? _kGreen : _kGold,
                  size: 20,
                ),
              ),
              title: Text(
                isConnected
                    ? account?.broker ?? 'Broker connected'
                    : 'Connect OANDA account',
                style: const TextStyle(
                  color: _kText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                isConnected
                    ? '${account?.currency} ${account?.balance.toStringAsFixed(2)} '
                      '· Acct ${account?.accountNumber}'
                    : 'Required for both trading modes',
                style: const TextStyle(color: _kSubtext, fontSize: 12),
              ),
              trailing: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kGold),
                    )
                  : Icon(
                      isConnected
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      color: isConnected ? _kGreen : _kGold,
                      size: 22,
                    ),
              onTap: isLoading ? null : onTap,
            ),
            if (isConnected && onDisconnect != null) ...[
              Container(height: 1, color: _kDivider),
              TextButton(
                onPressed: onDisconnect,
                child: const Text(
                  'Disconnect broker',
                  style: TextStyle(color: _kRed, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      );
}

// ── Reusable components ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: _kSubtext,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: destructive
                  ? const Color(0xFF3D0010)
                  : iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: destructive ? _kRed : _kText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: _kSubtext, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: _kSubtext, size: 18),
          onTap: onTap,
        ),
      );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final String display;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.display,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(color: _kSubtext, fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Text(
                  display,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: color,
            inactiveColor: color.withValues(alpha: 0.15),
            onChanged: onChanged,
          ),
        ],
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF3D0010),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kRed.withValues(alpha: 0.3)),
        ),
        child: Text(
          message,
          style: const TextStyle(
              color: _kRed, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}