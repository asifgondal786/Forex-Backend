import 'package:flutter/material.dart';
import 'package:forex_companion/config/theme.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';

class AutomationPanel extends StatefulWidget {
  const AutomationPanel({super.key});

  @override
  State<AutomationPanel> createState() => _AutomationPanelState();
}

class _AutomationPanelState extends State<AutomationPanel> {
  bool _automationEnabled = false;
  double _maxDailyLoss = 2.0;
  double _investmentPerTrade = 1000.0;
  double _riskPerTrade = 1.5;
  bool _autoTradeEUR = true;
  bool _autoTradeGBP = false;
  bool _autoTradeJPY = true;
  bool _autoTradeAUD = false;
  bool _autoTradeCAD = true;

  final List<String> _availablePairs = [
    'EUR/USD',
    'GBP/USD',
    'USD/JPY',
    'AUD/USD',
    'USD/CAD',
  ];
  bool _submittingTrade = false;
  bool _killSwitchBusy = false;
  late Future<Map<String, dynamic>> _guardrailsFuture;

  @override
  void initState() {
    super.initState();
    _guardrailsFuture = _loadGuardrails();
  }

  Future<Map<String, dynamic>> _loadGuardrails() async {
    return await context.read<ApiService>().getAutonomyGuardrails();
  }

  void _refreshGuardrails() {
    if (!mounted) {
      return;
    }
    setState(() {
      _guardrailsFuture = _loadGuardrails();
    });
  }

  String _primaryPair() {
    if (_autoTradeEUR) return 'EUR/USD';
    if (_autoTradeGBP) return 'GBP/USD';
    if (_autoTradeJPY) return 'USD/JPY';
    if (_autoTradeAUD) return 'AUD/USD';
    if (_autoTradeCAD) return 'USD/CAD';
    return _availablePairs.first;
  }

  Map<String, dynamic> _buildTradeParams() {
    final pair = _primaryPair();
    final prices = <String, double>{
      'EUR/USD': 1.1050,
      'GBP/USD': 1.2750,
      'USD/JPY': 155.20,
      'AUD/USD': 0.7350,
      'USD/CAD': 1.3450,
    };
    final entryPrice = prices[pair] ?? 1.0;
    final riskFraction = (_riskPerTrade / 100.0).clamp(0.005, 0.03);
    final stopLoss = entryPrice * (1 - riskFraction);
    final takeProfit = entryPrice * (1 + (riskFraction * 1.8));
    final positionSize = (_investmentPerTrade / entryPrice).clamp(1.0, 1000000.0);

    return {
      'pair': pair,
      'action': 'BUY',
      'entry_price': double.parse(entryPrice.toStringAsFixed(5)),
      'position_size': double.parse(positionSize.toStringAsFixed(2)),
      'stop_loss': double.parse(stopLoss.toStringAsFixed(5)),
      'take_profit': double.parse(takeProfit.toStringAsFixed(5)),
      'risk_percent': double.parse(_riskPerTrade.toStringAsFixed(2)),
      'broker_fail_safe_confirmed': true,
      'server_side_stop_loss': true,
      'server_side_take_profit': true,
      'reason': 'Automation panel signal',
      'is_paper_trade': false,
    };
  }

  Future<bool> _showExplainBeforeExecuteDialog({
    required bool guardPassed,
    required String guardReason,
    required Map<String, dynamic> card,
  }) async {
    final deepStudy = card['deep_study'] as Map<String, dynamic>? ?? {};
    final confidence = deepStudy['confidence_percent'] ?? '--';
    final recommendation = (deepStudy['recommendation'] ?? 'n/a').toString();
    final coverage = '${deepStudy['sources_analyzed'] ?? 0}/${deepStudy['sources_requested'] ?? 0}';
    final marketRisk = (deepStudy['market_risk'] ?? 'unknown').toString();

    final decision = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: Text(
            guardPassed ? 'Explain Before Execute' : 'Execution Blocked',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardReason,
                  style: TextStyle(
                    color: guardPassed ? const Color(0xFF9AE6B4) : const Color(0xFFFCA5A5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Confidence: $confidence%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Recommendation: $recommendation',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Source Coverage: $coverage',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Market Risk: $marketRisk',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            if (guardPassed)
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: AppTheme.glassElevatedButtonStyle(
                  tintColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  borderRadius: 10,
                ),
                child: const Text('Execute'),
              ),
          ],
        );
      },
    );
    return decision == true;
  }

  Future<void> _startTrading() async {
    if (_submittingTrade) {
      return;
    }
    setState(() {
      _submittingTrade = true;
    });
    try {
      final api = context.read<ApiService>();
      final tradeParams = _buildTradeParams();
      await api.configureAutonomyGuardrails(
        level: 'guarded_auto',
        riskBudget: {
          'max_risk_per_trade_percent': _riskPerTrade,
          'daily_loss_limit_percent': _maxDailyLoss,
        },
      );
      final explain = await api.explainBeforeExecute(tradeParams: tradeParams);
      final guardPassed = explain['guard_passed'] == true;
      final guardReason = (explain['guard_reason'] ?? 'No guardrail reason provided').toString();
      final card = explain['card'] is Map<String, dynamic>
          ? explain['card'] as Map<String, dynamic>
          : <String, dynamic>{};

      final confirmed = await _showExplainBeforeExecuteDialog(
        guardPassed: guardPassed,
        guardReason: guardReason,
        card: card,
      );

      if (!guardPassed || !confirmed) {
        _refreshGuardrails();
        return;
      }

      final result = await api.executeAutonomousTrade(tradeParams: tradeParams);
      if (!mounted) {
        return;
      }
      final success = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Autonomous trade executed successfully.'
                : (result['error'] ?? 'Trade execution failed').toString(),
          ),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      _refreshGuardrails();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to execute autonomous trade: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingTrade = false;
        });
      }
    }
  }

  Future<void> _pauseTrading() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _automationEnabled = false;
    });
    try {
      await context.read<ApiService>().configureAutonomyGuardrails(level: 'assisted');
      _refreshGuardrails();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autonomous level downgraded to assisted mode.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pause update failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _activateKillSwitch() async {
    if (_killSwitchBusy) {
      return;
    }
    setState(() {
      _killSwitchBusy = true;
    });
    try {
      final result = await context.read<ApiService>().activateKillSwitch();
      if (!mounted) {
        return;
      }
      setState(() {
        _automationEnabled = false;
      });
      final message = (result['message'] ?? 'Kill switch activated').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      _refreshGuardrails();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kill switch failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _killSwitchBusy = false;
        });
      }
    }
  }

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
                    '⚙️ Automation Control',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure AI trading parameters',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              // Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _automationEnabled
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : const Color(0xFF6B7280).withOpacity(0.15),
                  border: Border.all(
                    color: _automationEnabled
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF6B7280).withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _automationEnabled
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _automationEnabled ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: _automationEnabled
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Master Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.15),
                  const Color(0xFF3B82F6).withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enable Automation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start AI-powered trading',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: _automationEnabled,
                    onChanged: (value) {
                      setState(() => _automationEnabled = value);
                    },
                    activeThumbColor: const Color(0xFF10B981),
                    activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildAutonomyGuardrailsCard(),
          const SizedBox(height: 24),

          // Risk Settings Section
          _buildSectionHeader('Risk Settings'),
          const SizedBox(height: 12),

          // Max Daily Loss
          _buildSliderInput(
            label: 'Max Daily Loss (%)',
            value: _maxDailyLoss,
            min: 0.5,
            max: 10.0,
            division: 19,
            onChanged: (value) =>
                setState(() => _maxDailyLoss = value),
            icon: Icons.trending_down,
            warning: _maxDailyLoss > 5.0,
          ),
          const SizedBox(height: 16),

          // Investment Per Trade
          _buildSliderInput(
            label: 'Investment Per Trade (\$)',
            value: _investmentPerTrade,
            min: 100.0,
            max: 5000.0,
            division: 49,
            onChanged: (value) =>
                setState(() => _investmentPerTrade = value),
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 16),

          // Risk Per Trade
          _buildSliderInput(
            label: 'Risk Per Trade (%)',
            value: _riskPerTrade,
            min: 0.5,
            max: 5.0,
            division: 9,
            onChanged: (value) =>
                setState(() => _riskPerTrade = value),
            icon: Icons.shield,
          ),
          const SizedBox(height: 24),

          // Trading Pairs Section
          _buildSectionHeader('Trading Pairs'),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: isMobile ? 2 : 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPairToggle('EUR/USD', _autoTradeEUR, (v) {
                setState(() => _autoTradeEUR = v);
              }),
              _buildPairToggle('GBP/USD', _autoTradeGBP, (v) {
                setState(() => _autoTradeGBP = v);
              }),
              _buildPairToggle('USD/JPY', _autoTradeJPY, (v) {
                setState(() => _autoTradeJPY = v);
              }),
              _buildPairToggle('AUD/USD', _autoTradeAUD, (v) {
                setState(() => _autoTradeAUD = v);
              }),
              _buildPairToggle('USD/CAD', _autoTradeCAD, (v) {
                setState(() => _autoTradeCAD = v);
              }),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _automationEnabled && !_submittingTrade
                      ? _startTrading
                      : null,
                  icon: _submittingTrade
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_submittingTrade ? 'Checking Guardrails...' : 'Start Trading'),
                  style: AppTheme.glassElevatedButtonStyle(
                    tintColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _automationEnabled ? _pauseTrading : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                  style: AppTheme.glassElevatedButtonStyle(
                    tintColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _killSwitchBusy ? null : _activateKillSwitch,
                  icon: _killSwitchBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.stop_circle),
                  label: Text(_killSwitchBusy ? 'Stopping...' : 'Stop'),
                  style: AppTheme.glassElevatedButtonStyle(
                    tintColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: 10,
                    fillOpacity: 0.18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutonomyGuardrailsCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _guardrailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Loading autonomy guardrails...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unable to load guardrails: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: _refreshGuardrails,
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data ?? <String, dynamic>{};
        final state = data['autonomy_state'] as Map<String, dynamic>? ?? {};
        final budget = data['risk_budget'] as Map<String, dynamic>? ?? {};
        final level = (state['level'] ?? 'assisted').toString();
        final paused = state['paused'] == true;
        final probationPassed = state['probation_passed'] == true;
        final pauseReason = (state['pause_reason'] ?? '').toString();
        final maxRiskPerTrade = (budget['max_risk_per_trade_percent'] ?? '--').toString();
        final dailyLoss = (budget['daily_loss_limit_percent'] ?? '--').toString();
        final weeklyLoss = (budget['weekly_loss_limit_percent'] ?? '--').toString();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: paused
                  ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                  : const Color(0xFF10B981).withValues(alpha: 0.35),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    paused ? Icons.pause_circle : Icons.shield_outlined,
                    color: paused ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Autonomy Guardrails',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refreshGuardrails,
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                paused
                    ? 'Paused: ${pauseReason.isEmpty ? 'Guardrails triggered' : pauseReason}'
                    : 'Active level: $level',
                style: TextStyle(
                  color: paused ? const Color(0xFFFCA5A5) : const Color(0xFF9AE6B4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag(
                    probationPassed ? 'Probation Passed' : 'Probation Pending',
                    probationPassed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                  _buildTag('Risk/Trade ${maxRiskPerTrade}%', const Color(0xFF3B82F6)),
                  _buildTag('Daily Loss ${dailyLoss}%', const Color(0xFFEF4444)),
                  _buildTag('Weekly Loss ${weeklyLoss}%', const Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
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

  Widget _buildSliderInput({
    required String label,
    required double value,
    required double min,
    required double max,
    required int division,
    required ValueChanged<double> onChanged,
    required IconData icon,
    bool warning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: warning
              ? const Color(0xFFF59E0B).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: division,
            onChanged: onChanged,
            activeColor: warning
                ? const Color(0xFFF59E0B)
                : const Color(0xFF3B82F6),
            inactiveColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildPairToggle(String pair, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: value
              ? [
                  const Color(0xFF10B981).withOpacity(0.15),
                  const Color(0xFF10B981).withOpacity(0.05),
                ]
              : [
                  Colors.white.withOpacity(0.04),
                  Colors.white.withOpacity(0.02),
                ],
        ),
        border: Border.all(
          color: value
              ? const Color(0xFF10B981).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pair,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Transform.scale(
            scale: 0.9,
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

}
