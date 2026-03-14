// STEP 1: Add import at top
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/app_background.dart';
import '../../routes/app_routes.dart';

// ─────────────────────────────────────────────────────────────
//  Persistence keys
// ─────────────────────────────────────────────────────────────
const _kSelectedPairs      = 'tajir_selected_pairs';
const _kSelectedIndicators = 'tajir_selected_indicators';
const _kLayoutMode         = 'tajir_layout_mode';
const _kRiskPreset         = 'tajir_risk_preset';
const _kChartInterval      = 'tajir_chart_interval';

// ─────────────────────────────────────────────────────────────
//  Static catalogs
// ─────────────────────────────────────────────────────────────
const _majorPairs = [
  'EUR/USD', 'GBP/USD', 'USD/JPY', 'AUD/USD',
  'USD/CHF', 'NZD/USD', 'USD/CAD', 'EUR/GBP',
];
const _minorPairs = [
  'EUR/JPY', 'GBP/JPY', 'EUR/AUD', 'GBP/AUD',
  'AUD/JPY', 'CHF/JPY', 'EUR/CAD', 'GBP/CAD',
];
const _exoticPairs = [
  'USD/TRY', 'USD/ZAR', 'USD/MXN', 'USD/SGD',
  'EUR/TRY', 'USD/HKD', 'USD/SEK', 'USD/NOK',
];
const _indicators = [
  ('MA 20',    'Moving Average 20'),
  ('MA 50',    'Moving Average 50'),
  ('RSI',      'Relative Strength Index'),
  ('MACD',     'MACD Histogram'),
  ('BB',       'Bollinger Bands'),
  ('ATR',      'Average True Range'),
  ('EMA 9',    'EMA 9-period'),
  ('Stoch',    'Stochastic Oscillator'),
];
const _riskPresets = [
  ('Conservative', 'Max 1% per trade · Daily 2% cap',   0xFFEAF3DE, 0xFF3B6D11),
  ('Balanced',     'Max 2% per trade · Daily 4% cap',   0xFFFAEEDA, 0xFF854F0B),
  ('Aggressive',   'Max 5% per trade · Daily 10% cap',  0xFFFCEBEB, 0xFFA32D2D),
];
const _intervals = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1'];

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class CustomSetupScreen extends StatefulWidget {
  const CustomSetupScreen({super.key});

  @override
  State<CustomSetupScreen> createState() => _CustomSetupScreenState();
}

class _CustomSetupScreenState extends State<CustomSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Set<String> _selectedPairs      = {'EUR/USD', 'GBP/USD', 'USD/JPY'};
  Set<String> _selectedIndicators = {'MA 20', 'RSI'};
  String      _layoutMode         = 'grid';
  String      _riskPreset         = 'Balanced';
  String      _chartInterval      = 'H1';
  bool        _saving             = false;
  bool        _loaded             = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPrefs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final pairs = prefs.getStringList(_kSelectedPairs);
      if (pairs != null && pairs.isNotEmpty) _selectedPairs = pairs.toSet();
      final inds = prefs.getStringList(_kSelectedIndicators);
      if (inds != null && inds.isNotEmpty) _selectedIndicators = inds.toSet();
      _layoutMode     = prefs.getString(_kLayoutMode)    ?? 'grid';
      _riskPreset     = prefs.getString(_kRiskPreset)    ?? 'Balanced';
      _chartInterval  = prefs.getString(_kChartInterval) ?? 'H1';
      _loaded         = true;
    });
  }

  Future<void> _save() async {
    if (_selectedPairs.isEmpty) {
      _showSnack('Select at least one currency pair.', isError: true);
      return;
    }
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedPairs,      _selectedPairs.toList());
    await prefs.setStringList(_kSelectedIndicators, _selectedIndicators.toList());
    await prefs.setString(_kLayoutMode,    _layoutMode);
    await prefs.setString(_kRiskPreset,    _riskPreset);
    await prefs.setString(_kChartInterval, _chartInterval);
    setState(() => _saving = false);
    if (mounted) {
      _showSnack('Setup saved — ${_selectedPairs.length} pairs, ${_selectedIndicators.length} indicators');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (_) => false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        backgroundColor: isError ? const Color(0xFFA32D2D) : const Color(0xFF0F6E56),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _togglePair(String pair) {
    setState(() {
      if (_selectedPairs.contains(pair)) {
        if (_selectedPairs.length > 1) _selectedPairs.remove(pair);
      } else {
        _selectedPairs.add(pair);
      }
    });
  }

  void _toggleIndicator(String ind) {
    setState(() {
      if (_selectedIndicators.contains(ind)) {
        _selectedIndicators.remove(ind);
      } else {
        _selectedIndicators.add(ind);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(isDark),
        body: _loaded ? _buildBody(isDark) : _buildLoading(),
        bottomNavigationBar: _buildSaveBar(isDark),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0A0C10) : Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Setup',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            '${_selectedPairs.length} pairs · ${_selectedIndicators.length} indicators',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF8A8880) : const Color(0xFF888780),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFF0A500),
        indicatorWeight: 2,
        labelColor: const Color(0xFFF0A500),
        unselectedLabelColor: isDark ? const Color(0xFF8A8880) : const Color(0xFF888780),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(text: 'PAIRS'),
          Tab(text: 'INDICATORS'),
          Tab(text: 'DISPLAY'),
          Tab(text: 'RISK'),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: [
        _PairsTab(
          selectedPairs: _selectedPairs,
          onToggle: _togglePair,
          isDark: isDark,
        ),
        _IndicatorsTab(
          selectedIndicators: _selectedIndicators,
          onToggle: _toggleIndicator,
          isDark: isDark,
        ),
        _DisplayTab(
          layoutMode: _layoutMode,
          chartInterval: _chartInterval,
          onLayoutChanged: (v) => setState(() => _layoutMode = v),
          onIntervalChanged: (v) => setState(() => _chartInterval = v),
          isDark: isDark,
        ),
        _RiskTab(
          riskPreset: _riskPreset,
          onChanged: (v) => setState(() => _riskPreset = v),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFF0A500),
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildSaveBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0C10) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E2028) : const Color(0xFFE8E6E0),
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF0A500),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : const Text('SAVE & GO TO DASHBOARD'),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tab: Pairs
// ─────────────────────────────────────────────────────────────
class _PairsTab extends StatelessWidget {
  final Set<String> selectedPairs;
  final void Function(String) onToggle;
  final bool isDark;

  const _PairsTab({
    required this.selectedPairs,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pairSection('Major Pairs', _majorPairs),
        const SizedBox(height: 20),
        _pairSection('Minor Pairs', _minorPairs),
        const SizedBox(height: 20),
        _pairSection('Exotic Pairs', _exoticPairs),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${selectedPairs.length} pair${selectedPairs.length == 1 ? '' : 's'} selected',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF8A8880) : const Color(0xFF888780),
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _pairSection(String title, List<String> pairs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Color(0xFF8A8880),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: pairs.map((pair) {
            final selected = selectedPairs.contains(pair);
            return _PairChip(
              pair: pair,
              selected: selected,
              onTap: () => onToggle(pair),
              isDark: isDark,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PairChip extends StatelessWidget {
  final String pair;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _PairChip({
    required this.pair,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF0A500)
              : (isDark ? const Color(0xFF141619) : const Color(0xFFF5F4F0)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFFF0A500)
                : (isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7)),
            width: 0.5,
          ),
        ),
        child: Text(
          pair,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            color: selected
                ? Colors.black
                : (isDark ? const Color(0xFFCECBC4) : const Color(0xFF444441)),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tab: Indicators
// ─────────────────────────────────────────────────────────────
class _IndicatorsTab extends StatelessWidget {
  final Set<String> selectedIndicators;
  final void Function(String) onToggle;
  final bool isDark;

  const _IndicatorsTab({
    required this.selectedIndicators,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'TECHNICAL INDICATORS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: isDark ? const Color(0xFF8A8880) : const Color(0xFF888780),
          ),
        ),
        const SizedBox(height: 12),
        ..._indicators.map((ind) {
          final selected = selectedIndicators.contains(ind.$1);
          return _IndicatorTile(
            code: ind.$1,
            description: ind.$2,
            selected: selected,
            onTap: () => onToggle(ind.$1),
            isDark: isDark,
          );
        }),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F4F0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF8A8880)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Selected indicators appear on all chart views. Keep to 3–4 for clarity.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8A8880) : const Color(0xFF888780),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  final String code;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _IndicatorTile({
    required this.code,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1A1600)
                : (isDark ? const Color(0xFF141619) : const Color(0xFFFAF9F6)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF0A500)
                  : (isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7)),
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF0A500)
                      : (isDark ? const Color(0xFF2A2D35) : const Color(0xFFE8E6E0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: selected
                        ? Colors.black
                        : (isDark ? const Color(0xFFCECBC4) : const Color(0xFF444441)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFFCECBC4) : const Color(0xFF3D3D3A),
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFFF0A500), size: 18)
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: isDark ? const Color(0xFF4A4D56) : const Color(0xFFB4B2A9),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tab: Display
// ─────────────────────────────────────────────────────────────
class _DisplayTab extends StatelessWidget {
  final String layoutMode;
  final String chartInterval;
  final void Function(String) onLayoutChanged;
  final void Function(String) onIntervalChanged;
  final bool isDark;

  const _DisplayTab({
    required this.layoutMode,
    required this.chartInterval,
    required this.onLayoutChanged,
    required this.onIntervalChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('MARKET WATCH LAYOUT'),
        const SizedBox(height: 12),
        Row(
          children: [
            _LayoutOption(
              icon: Icons.grid_view_rounded,
              label: 'Grid',
              value: 'grid',
              selected: layoutMode == 'grid',
              onTap: () => onLayoutChanged('grid'),
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _LayoutOption(
              icon: Icons.view_list_rounded,
              label: 'List',
              value: 'list',
              selected: layoutMode == 'list',
              onTap: () => onLayoutChanged('list'),
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 28),
        _sectionLabel('DEFAULT CHART INTERVAL'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _intervals.map((interval) {
            final selected = chartInterval == interval;
            return GestureDetector(
              onTap: () => onIntervalChanged(interval),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 58,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF0A500)
                      : (isDark ? const Color(0xFF141619) : const Color(0xFFF5F4F0)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFF0A500)
                        : (isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7)),
                    width: 0.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  interval,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: selected
                        ? Colors.black
                        : (isDark ? const Color(0xFFCECBC4) : const Color(0xFF444441)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        _sectionLabel('CHART APPEARANCE'),
        const SizedBox(height: 12),
        _InfoTile(
          isDark: isDark,
          icon: Icons.candlestick_chart_outlined,
          title: 'Candlestick charts',
          subtitle: 'TradingView integration coming in a future update',
          badge: 'Soon',
          badgeColor: const Color(0xFFFAEEDA),
          badgeTextColor: const Color(0xFF854F0B),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Color(0xFF8A8880),
        ),
      );
}

class _LayoutOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _LayoutOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 80,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1A1600)
                : (isDark ? const Color(0xFF141619) : const Color(0xFFFAF9F6)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF0A500)
                  : (isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7)),
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFFF0A500) : const Color(0xFF8A8880),
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFFF0A500)
                      : (isDark ? const Color(0xFFCECBC4) : const Color(0xFF444441)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeTextColor;

  const _InfoTile({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141619) : const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8A8880), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFCECBC4) : const Color(0xFF3D3D3A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A8880)),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tab: Risk
// ─────────────────────────────────────────────────────────────
class _RiskTab extends StatelessWidget {
  final String riskPreset;
  final void Function(String) onChanged;
  final bool isDark;

  const _RiskTab({
    required this.riskPreset,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'RISK PRESET',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Color(0xFF8A8880),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This sets your default risk budget. You can fine-tune sliders in the AI Copilot.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF8A8880) : const Color(0xFF888780),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ..._riskPresets.map((preset) {
          final selected = riskPreset == preset.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => onChanged(preset.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? Color(preset.$3)
                      : (isDark ? const Color(0xFF141619) : const Color(0xFFFAF9F6)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? Color(preset.$4)
                        : (isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7)),
                    width: selected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.$1,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Color(preset.$4)
                                  : (isDark
                                      ? const Color(0xFFCECBC4)
                                      : const Color(0xFF3D3D3A)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preset.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: selected
                                  ? Color(preset.$4).withValues(alpha: 0.7)
                                  : const Color(0xFF8A8880),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          color: Color(preset.$4), size: 22)
                    else
                      Icon(
                        Icons.radio_button_unchecked_rounded,
                        color: isDark
                            ? const Color(0xFF4A4D56)
                            : const Color(0xFFB4B2A9),
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F4F0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF8A8880)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Risk presets sync with the AI Risk Guardian. Conservative mode enforces paper trading until probation passes.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8880),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
