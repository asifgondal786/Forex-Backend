// lib/features/automation/automation_screen.dart
//
// Tajir — Investment Control & Autonomous Trading Screen
// Two modes: Semi-Autonomous (user approves) + Fully Autonomous (AI executes)
// Kill-switch always visible. Risk guardian stats always shown.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/automation_provider.dart';
import '../../providers/account_connection_provider.dart';
import '../../providers/risk_provider.dart';
import '../../core/models/account_connection.dart';

// ── palette (matches trade_signals_screen dark theme) ──────────────────────
const _kBg       = Color(0xFF0A0E1A);
const _kSurface  = Color(0xFF111827);
const _kCard     = Color(0xFF161D2E);
const _kBorder   = Color(0xFF1E2A3D);
const _kGold     = Color(0xFFD4A853);
const _kGreen    = Color(0xFF00C896);
const _kGreenDim = Color(0xFF003D2E);
const _kRed      = Color(0xFFFF4560);
const _kRedDim   = Color(0xFF3D0010);
const _kAmber    = Color(0xFFF59E0B);
const _kAmberDim = Color(0xFF3D2600);
const _kBlue     = Color(0xFF3B82F6);
const _kBlueDim  = Color(0xFF0D1F4A);
const _kText     = Color(0xFFE2E8F0);
const _kSubtext  = Color(0xFF64748B);
const _kDivider  = Color(0xFF1E2A3D);

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AutomationProvider>().refreshStatus();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AutomationProvider, AccountConnectionProvider, RiskProvider>(
      builder: (ctx, auto, accounts, risk, _) {
        final account      = accounts.selectedAccount;
        final isConnected  = account?.status == AccountConnectionStatus.connected;

        return Scaffold(
          backgroundColor: _kBg,
          body: FadeTransition(
            opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(auto),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Broker connection gate ──────────────────────
                        if (!isConnected) ...[
                          _BrokerGateBanner(onConnect: () =>
                              Navigator.pushNamed(context, '/settings')),
                          const SizedBox(height: 20),
                        ],

                        // ── Agent status strip ──────────────────────────
                        _AgentStatusStrip(provider: auto),
                        const SizedBox(height: 16),

                        // ── Mode cards ─────────────────────────────────
                        _ModeCard(
                          icon: Icons.person_rounded,
                          iconColor: _kBlue,
                          iconBg: _kBlueDim,
                          title: 'Semi-Autonomous',
                          subtitle: 'AI generates signals • You approve each trade',
                          description:
                              'The AI analyses the market and delivers trade signals '
                              'with entry, stop-loss, take-profit, and confidence score. '
                              'You review and tap Approve to execute — nothing trades without your tap.',
                          enabled: auto.semiEnabled,
                          isLoading: auto.isSemiLoading,
                          canEnable: isConnected || auto.semiEnabled,
                          onToggle: (val) => _toggleSemi(ctx, auto, val),
                        ),
                        const SizedBox(height: 12),

                        _ModeCard(
                          icon: Icons.smart_toy_rounded,
                          iconColor: _kGold,
                          iconBg: const Color(0xFF2D2200),
                          title: 'Fully Autonomous',
                          subtitle: 'AI executes trades within your risk limits',
                          description:
                              'The AI continuously monitors the market, generates signals, '
                              'validates each one against your risk limits, and places orders '
                              'through your connected broker — no approval needed per trade. '
                              'Daily loss cap and per-trade risk limit are enforced before every order.',
                          enabled: auto.fullyEnabled,
                          isLoading: auto.isFullyLoading,
                          canEnable: isConnected,
                          warningBeforeEnable: true,
                          onToggle: (val) => _toggleFully(ctx, auto, val),
                        ),
                        const SizedBox(height: 20),

                        // ── Kill-switch ────────────────────────────────
                        _KillSwitchButton(
                          active: auto.semiEnabled || auto.fullyEnabled,
                          isLoading: auto.isKillLoading,
                          onPressed: () => _confirmKillSwitch(ctx, auto),
                        ),
                        const SizedBox(height: 20),

                        // ── Risk guardian panel ────────────────────────
                        _RiskGuardianPanel(risk: risk, account: account),
                        const SizedBox(height: 20),

                        // ── Today's stats ──────────────────────────────
                        _TodayStatsPanel(provider: auto),
                        const SizedBox(height: 20),

                        // ── Disclaimer ─────────────────────────────────
                        _DisclaimerBanner(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────
  Widget _buildAppBar(AutomationProvider auto) => SliverAppBar(
        pinned: true,
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            _AgentDot(running: auto.fullyEnabled || auto.semiEnabled),
            const SizedBox(width: 10),
            const Text(
              'Agent',
              style: TextStyle(
                color: _kText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kSubtext, size: 20),
            onPressed: auto.refreshStatus,
            tooltip: 'Refresh agent status',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kDivider),
        ),
      );

  // ── Toggle handlers ──────────────────────────────────────────────────────
  Future<void> _toggleSemi(
      BuildContext ctx, AutomationProvider auto, bool val) async {
    if (!val) {
      await auto.disableSemiAutonomous();
      return;
    }
    await auto.enableSemiAutonomous();
    if (auto.lastError != null && ctx.mounted) {
      _showError(ctx, auto.lastError!);
    }
  }

  Future<void> _toggleFully(
      BuildContext ctx, AutomationProvider auto, bool val) async {
    if (!val) {
      await auto.disableFullyAutonomous();
      return;
    }
    // Require explicit confirmation before enabling fully autonomous
    final confirmed = await _showFullyAutonomousWarning(ctx);
    if (!confirmed) return;
    await auto.enableFullyAutonomous();
    if (auto.lastError != null && ctx.mounted) {
      _showError(ctx, auto.lastError!);
    }
  }

  Future<bool> _showFullyAutonomousWarning(BuildContext ctx) async {
    return await showDialog<bool>(
          context: ctx,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: _kCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _kBorder),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _kAmber, size: 22),
                SizedBox(width: 10),
                Text(
                  'Enable Fully Autonomous?',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: const Text(
              'The AI will place real trades using your connected broker account, '
              'within your configured risk limits.\n\n'
              'Your daily loss cap and per-trade risk limit will be enforced before '
              'every order. The kill-switch stops all activity instantly.\n\n'
              'This is AI-generated trading — not financial advice. '
              'Only enable if you understand and accept the risk.',
              style: TextStyle(color: _kSubtext, fontSize: 13, height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: _kSubtext)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: _kAmber),
                child: const Text('I understand, enable',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _confirmKillSwitch(
      BuildContext ctx, AutomationProvider auto) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _kRed.withValues(alpha: 0.4)),
        ),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new_rounded, color: _kRed, size: 22),
            SizedBox(width: 10),
            Text(
              'Activate Kill-Switch?',
              style: TextStyle(
                color: _kText,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'This will immediately:\n\n'
          '• Stop all autonomous agent activity\n'
          '• Cancel any pending orders\n'
          '• Close all open positions\n\n'
          'This action cannot be undone. You will need to re-enable a mode manually.',
          style: TextStyle(color: _kSubtext, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _kSubtext)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Kill all activity',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !ctx.mounted) return;
    await auto.activateKillSwitch();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          backgroundColor: _kGreenDim,
          content: const Text(
            'Kill-switch activated — all activity stopped.',
            style: TextStyle(color: _kGreen, fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showError(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        backgroundColor: _kRedDim,
        content: Text(
          msg,
          style: const TextStyle(color: _kRed, fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Animated agent dot ────────────────────────────────────────────────────
class _AgentDot extends StatefulWidget {
  final bool running;
  const _AgentDot({required this.running});

  @override
  State<_AgentDot> createState() => _AgentDotState();
}

class _AgentDotState extends State<_AgentDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.running) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AgentDot old) {
    super.didUpdateWidget(old);
    if (widget.running && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.running && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.running ? _kGreen : _kSubtext;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.running
              ? color.withValues(alpha: 0.4 + _ctrl.value * 0.6)
              : color,
        ),
      ),
    );
  }
}

// ── Broker gate banner ────────────────────────────────────────────────────
class _BrokerGateBanner extends StatelessWidget {
  final VoidCallback onConnect;
  const _BrokerGateBanner({required this.onConnect});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onConnect,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kAmberDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_off_rounded, color: _kAmber, size: 18),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Connect your broker in Settings to enable trading modes.',
                  style: TextStyle(
                    color: _kAmber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: _kAmber, size: 18),
            ],
          ),
        ),
      );
}

// ── Agent status strip ────────────────────────────────────────────────────
class _AgentStatusStrip extends StatelessWidget {
  final AutomationProvider provider;
  const _AgentStatusStrip({required this.provider});

  String get _modeLabel {
    if (provider.fullyEnabled) return 'Fully Autonomous';
    if (provider.semiEnabled) return 'Semi-Autonomous';
    return 'Idle';
  }

  Color get _modeColor {
    if (provider.fullyEnabled) return _kGold;
    if (provider.semiEnabled) return _kBlue;
    return _kSubtext;
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            _StatCell('Mode', _modeLabel, _modeColor),
            _vDivider(),
            _StatCell(
              'Trades today',
              '${provider.tradesToday}',
              _kText,
            ),
            _vDivider(),
            _StatCell(
              'P&L today',
              provider.pnlToday >= 0
                  ? '+\$${provider.pnlToday.toStringAsFixed(2)}'
                  : '-\$${provider.pnlToday.abs().toStringAsFixed(2)}',
              provider.pnlToday >= 0 ? _kGreen : _kRed,
            ),
            _vDivider(),
            _StatCell(
              'Open positions',
              '${provider.openPositions}',
              _kText,
            ),
          ],
        ),
      );

  Widget _vDivider() => Container(
        width: 1,
        height: 28,
        color: _kDivider,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );
}

class _StatCell extends StatelessWidget {
  const _StatCell(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _kSubtext,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ── Mode card ─────────────────────────────────────────────────────────────
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String description;
  final bool enabled;
  final bool isLoading;
  final bool canEnable;
  final bool warningBeforeEnable;
  final ValueChanged<bool> onToggle;

  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.enabled,
    required this.isLoading,
    required this.canEnable,
    required this.onToggle,
    this.warningBeforeEnable = false,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? iconColor.withValues(alpha: 0.4)
                : _kBorder,
            width: enabled ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _kText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: _kSubtext,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kGold,
                      ),
                    )
                  else
                    Switch(
                      value: enabled,
                      onChanged: canEnable ? onToggle : null,
                      activeColor: iconColor,
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return iconColor.withValues(alpha: 0.25);
                        }
                        return _kBorder;
                      }),
                    ),
                ],
              ),
            ),

            // Description
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                description,
                style: const TextStyle(
                  color: _kSubtext,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ),

            // Active indicator
            if (enabled) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Locked hint
            if (!canEnable && !enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: const [
                    Icon(Icons.lock_outline_rounded,
                        color: _kSubtext, size: 12),
                    SizedBox(width: 6),
                    Text(
                      'Requires connected broker account',
                      style: TextStyle(color: _kSubtext, fontSize: 11),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      );
}

// ── Kill-switch button ────────────────────────────────────────────────────
class _KillSwitchButton extends StatelessWidget {
  final bool active;
  final bool isLoading;
  final VoidCallback onPressed;

  const _KillSwitchButton({
    required this.active,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active ? _kRedDim : _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? _kRed.withValues(alpha: 0.5) : _kBorder,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kRed,
                  ),
                )
              else
                const Icon(
                  Icons.power_settings_new_rounded,
                  color: _kRed,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Text(
                isLoading ? 'Stopping all activity…' : 'Kill-Switch — Stop All Activity',
                style: TextStyle(
                  color: active ? _kRed : _kSubtext,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Risk guardian panel ───────────────────────────────────────────────────
class _RiskGuardianPanel extends StatelessWidget {
  final RiskProvider risk;
  final AccountConnection? account;

  const _RiskGuardianPanel({required this.risk, required this.account});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: const [
                  Icon(Icons.shield_rounded, color: _kGold, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Risk Guardian',
                    style: TextStyle(
                      color: _kText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: _kDivider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _RiskRow(
                    label: 'Daily loss cap',
                    value: '${risk.dailyLimitPct.toStringAsFixed(1)}% of account',
                    color: _kAmber,
                  ),
                  const SizedBox(height: 10),
                  _RiskRow(
                    label: 'Max open trades',
                    value: '${risk.maxOpenTrades} simultaneous',
                    color: _kBlue,
                  ),
                  const SizedBox(height: 10),
                  _RiskRow(
                    label: 'Risk per trade',
                    value: '${risk.riskPerTradePct.toStringAsFixed(1)}% of balance',
                    color: _kGold,
                  ),
                  if (account != null) ...[
                    const SizedBox(height: 10),
                    _RiskRow(
                      label: 'Available balance',
                      value:
                          '${account!.currency} ${account!.balance.toStringAsFixed(2)}',
                      color: _kGreen,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'All orders are validated against these limits before execution. '
                'Signals that exceed any limit are blocked automatically.',
                style: const TextStyle(
                  color: _kSubtext,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
}

class _RiskRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RiskRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _kSubtext, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}

// ── Today's stats panel ───────────────────────────────────────────────────
class _TodayStatsPanel extends StatelessWidget {
  final AutomationProvider provider;
  const _TodayStatsPanel({required this.provider});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                "Today's Activity",
                style: TextStyle(
                  color: _kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(height: 1, color: _kDivider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _ActivityCell(
                    label: 'Signals generated',
                    value: '${provider.signalsToday}',
                    color: _kBlue,
                  ),
                  _ActivityCell(
                    label: 'Trades executed',
                    value: '${provider.tradesToday}',
                    color: _kGold,
                  ),
                  _ActivityCell(
                    label: 'Blocked by guardian',
                    value: '${provider.blockedToday}',
                    color: _kRed,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActivityCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ActivityCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _kSubtext,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ── Disclaimer banner ─────────────────────────────────────────────────────
class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: _kSubtext, size: 14),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI-generated analysis — not financial advice. '
                'Trading involves significant risk. Past signal performance '
                'does not guarantee future results. Only trade with capital '
                'you can afford to lose.',
                style: TextStyle(
                  color: _kSubtext,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
}