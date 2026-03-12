import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/app_background.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

const _kSelectedPairs = 'tajir_selected_pairs';
const _kRiskPreset    = 'tajir_risk_preset';

// ─────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────
enum _SignalType { buy, sell, hold, wait }

extension _SignalTypeExt on _SignalType {
  String get label => name.toUpperCase();
  Color get color {
    switch (this) {
      case _SignalType.buy:  return const Color(0xFF00C896);
      case _SignalType.sell: return const Color(0xFFFF4D6D);
      case _SignalType.hold: return const Color(0xFFF0A500);
      case _SignalType.wait: return const Color(0xFF8A8880);
    }
  }
  Color get bgColor {
    switch (this) {
      case _SignalType.buy:  return const Color(0xFF001F17);
      case _SignalType.sell: return const Color(0xFF1F0008);
      case _SignalType.hold: return const Color(0xFF1A1200);
      case _SignalType.wait: return const Color(0xFF141619);
    }
  }
  IconData get icon {
    switch (this) {
      case _SignalType.buy:  return Icons.trending_up_rounded;
      case _SignalType.sell: return Icons.trending_down_rounded;
      case _SignalType.hold: return Icons.pause_circle_outline_rounded;
      case _SignalType.wait: return Icons.schedule_rounded;
    }
  }
}

class _Signal {
  final String pair;
  final _SignalType type;
  final double confidence;  // 0.0 – 1.0
  final String reason;
  final String? entryPrice;
  final String? tp;
  final String? sl;
  final String timeframe;
  final DateTime generatedAt;
  final List<String> tags;

  const _Signal({
    required this.pair,
    required this.type,
    required this.confidence,
    required this.reason,
    this.entryPrice,
    this.tp,
    this.sl,
    required this.timeframe,
    required this.generatedAt,
    this.tags = const [],
  });

  factory _Signal.fromApi(Map<String, dynamic> data) {
    final typeStr = (data['signal'] ?? data['type'] ?? 'wait').toString().toLowerCase();
    final type = typeStr.contains('buy')
        ? _SignalType.buy
        : typeStr.contains('sell')
            ? _SignalType.sell
            : typeStr.contains('hold')
                ? _SignalType.hold
                : _SignalType.wait;

    final rawConf = data['confidence'] ?? data['confidence_score'] ?? 0.5;
    final conf    = rawConf is num ? rawConf.toDouble().clamp(0.0, 1.0) : 0.5;

    final tags = (data['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];

    return _Signal(
      pair:        data['pair'] ?? data['symbol'] ?? 'UNKNOWN',
      type:        type,
      confidence:  conf,
      reason:      data['reason'] ?? data['reasoning'] ?? data['explanation'] ?? 'AI analysis in progress.',
      entryPrice:  data['entry_price']?.toString(),
      tp:          data['take_profit']?.toString() ?? data['tp']?.toString(),
      sl:          data['stop_loss']?.toString()   ?? data['sl']?.toString(),
      timeframe:   data['timeframe'] ?? 'H1',
      generatedAt: DateTime.tryParse(data['generated_at'] ?? '') ?? DateTime.now(),
      tags:        tags,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class TradeSignalsScreen extends StatefulWidget {
  const TradeSignalsScreen({super.key});

  @override
  State<TradeSignalsScreen> createState() => _TradeSignalsScreenState();
}

class _TradeSignalsScreenState extends State<TradeSignalsScreen> {
  final ApiService _api = ApiService();

  List<String>  _pairs      = ['EUR/USD', 'GBP/USD', 'USD/JPY'];
  String        _riskPreset = 'Balanced';
  List<_Signal> _signals    = [];
  bool          _loading    = true;
  String?       _error;
  String        _filter     = 'all'; // 'all' | 'buy' | 'sell' | 'strong'
  Timer?        _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadPrefs();
    await _fetch();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final pairs = prefs.getStringList(_kSelectedPairs);
    setState(() {
      if (pairs != null && pairs.isNotEmpty) _pairs = pairs;
      _riskPreset = prefs.getString(_kRiskPreset) ?? 'Balanced';
    });
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = _signals.isEmpty);
    try {
      // Calls the existing signal/analysis endpoint
      final raw = await _api.getTradeSignals(pairs: _pairs);
      final list = (raw['signals'] as List?) ?? [];
      final signals = list
          .map((s) => _Signal.fromApi(s as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _signals = signals;
          _loading = false;
          _error   = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_signals.isEmpty) _error = 'Could not load signals. Pull to refresh.';
        });
      }
    }
  }

  List<_Signal> get _filtered {
    switch (_filter) {
      case 'buy':    return _signals.where((s) => s.type == _SignalType.buy).toList();
      case 'sell':   return _signals.where((s) => s.type == _SignalType.sell).toList();
      case 'strong': return _signals.where((s) => s.confidence >= 0.75).toList();
      default:       return _signals;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(isDark),
        body: _buildBody(isDark),
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
            'Trade Signals',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          Text(
            '${_signals.length} signals · refreshes every 5 min',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8A8880),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 20),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.customSetup),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: () {
            setState(() { _loading = true; });
            _fetch();
          },
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading && _signals.isEmpty) return _buildLoading();
    if (_error != null && _signals.isEmpty) return _buildError(isDark);

    return RefreshIndicator(
      color: const Color(0xFFF0A500),
      onRefresh: _fetch,
      child: Column(
        children: [
          _buildFilterBar(isDark),
          Expanded(
            child: _filtered.isEmpty
                ? _buildEmpty(isDark)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _SignalCard(
                      signal: _filtered[i],
                      riskPreset: _riskPreset,
                      isDark: isDark,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    final filters = [
      ('all',    'All'),
      ('buy',    'Buy'),
      ('sell',   'Sell'),
      ('strong', 'Strong ≥75%'),
    ];
    return Container(
      height: 48,
      color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F4F0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: filters.map((f) {
          final active = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFF0A500)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? const Color(0xFFF0A500)
                        : (isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7)),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.black
                        : (isDark ? const Color(0xFF8A8880) : const Color(0xFF888780)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFF0A500), strokeWidth: 2),
          SizedBox(height: 16),
          Text('Generating signals…',
              style: TextStyle(color: Color(0xFF8A8880), fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.analytics_outlined, color: Color(0xFF8A8880), size: 40),
          const SizedBox(height: 16),
          Text(_error ?? 'Something went wrong',
              style: const TextStyle(color: Color(0xFF8A8880)), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              setState(() { _loading = true; _error = null; });
              _fetch();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF0A500),
              side: const BorderSide(color: Color(0xFFF0A500), width: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, color: Color(0xFF8A8880), size: 36),
          const SizedBox(height: 12),
          Text(
            'No $_filter signals right now',
            style: const TextStyle(color: Color(0xFF8A8880), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Signal Card
// ─────────────────────────────────────────────────────────────
class _SignalCard extends StatefulWidget {
  final _Signal signal;
  final String riskPreset;
  final bool isDark;

  const _SignalCard({
    required this.signal,
    required this.riskPreset,
    required this.isDark,
  });

  @override
  State<_SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<_SignalCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s      = widget.signal;
    final isDark = widget.isDark;
    final ageMin = DateTime.now().difference(s.generatedAt).inMinutes;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141619) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? s.type.color.withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7)),
          width: _expanded ? 1 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── Header row ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                children: [
                  // Signal badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.type.bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: s.type.color.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.type.icon, color: s.type.color, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          s.type.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: s.type.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.pair,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${s.timeframe} · ${ageMin < 1 ? 'just now' : '${ageMin}m ago'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A8880),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Confidence ring
                  _ConfidenceRing(confidence: s.confidence, color: s.type.color),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8A8880),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Reason (always visible, truncated) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              s.reason,
              maxLines: _expanded ? 6 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? const Color(0xFF9E9C95) : const Color(0xFF5F5E5A),
              ),
            ),
          ),

          // ── Expanded: levels + tags + action ──
          if (_expanded) ...[
            Divider(
              height: 0.5,
              color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.entryPrice != null || s.tp != null || s.sl != null)
                    _LevelsRow(
                      entry: s.entryPrice,
                      tp: s.tp,
                      sl: s.sl,
                      isDark: isDark,
                    ),
                  if (s.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: s.tags.map((tag) => _TagChip(tag: tag, isDark: isDark)).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.dashboard),
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Open Copilot'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF0A500),
                            side: const BorderSide(color: Color(0xFFF0A500), width: 0.5),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Confidence Ring (simple linear progress bar style)
// ─────────────────────────────────────────────────────────────
class _ConfidenceRing extends StatelessWidget {
  final double confidence;
  final Color color;
  const _ConfidenceRing({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    return Column(
      children: [
        Text(
          '$pct%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 36,
          child: LinearProgressIndicator(
            value: confidence,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _LevelsRow extends StatelessWidget {
  final String? entry;
  final String? tp;
  final String? sl;
  final bool isDark;
  const _LevelsRow({this.entry, this.tp, this.sl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (entry != null) _Level(label: 'Entry', value: entry!, color: const Color(0xFF8A8880), isDark: isDark),
        if (entry != null && (tp != null || sl != null)) const SizedBox(width: 12),
        if (tp != null)    _Level(label: 'TP',    value: tp!,    color: const Color(0xFF00C896), isDark: isDark),
        if (tp != null && sl != null) const SizedBox(width: 12),
        if (sl != null)    _Level(label: 'SL',    value: sl!,    color: const Color(0xFFFF4D6D), isDark: isDark),
      ],
    );
  }
}

class _Level extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _Level({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          Text(value, style: TextStyle(fontSize: 12, color: color, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final bool isDark;
  const _TagChip({required this.tag, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : const Color(0xFFF0EEE8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: isDark ? const Color(0xFF8A8880) : const Color(0xFF5F5E5A),
        ),
      ),
    );
  }
}
