import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/app_background.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

const _kSelectedPairs  = 'tajir_selected_pairs';
const _kLayoutMode     = 'tajir_layout_mode';

// ─────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────
class _PriceData {
  final String pair;
  final double bid;
  final double ask;
  final double change;     // absolute
  final double changePct;  // percent
  final double spread;
  final String trend;      // 'up' | 'down' | 'flat'
  final List<double> spark; // mini sparkline last 12 ticks

  const _PriceData({
    required this.pair,
    required this.bid,
    required this.ask,
    required this.change,
    required this.changePct,
    required this.spread,
    required this.trend,
    required this.spark,
  });

  factory _PriceData.fromApi(String pair, Map<String, dynamic> data) {
    final bid       = _parseDouble(data['bid'] ?? data['price'] ?? data['rate'] ?? 0);
    final ask       = _parseDouble(data['ask'] ?? (bid * 1.0002));
    final change    = _parseDouble(data['change'] ?? data['change_abs'] ?? 0);
    final changePct = _parseDouble(data['change_pct'] ?? data['change_percent'] ?? 0);
    final spread    = ((ask - bid) * 10000).roundToDouble() / 10; // pips
    final spark     = (data['sparkline'] as List?)
            ?.map((v) => _parseDouble(v))
            .toList() ??
        List.generate(12, (_) => bid);
    final trend = changePct > 0.01
        ? 'up'
        : changePct < -0.01
            ? 'down'
            : 'flat';
    return _PriceData(
      pair: pair,
      bid: bid,
      ask: ask,
      change: change,
      changePct: changePct,
      spread: spread,
      trend: trend,
      spark: spark,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class MarketWatchScreen extends StatefulWidget {
  const MarketWatchScreen({super.key});

  @override
  State<MarketWatchScreen> createState() => _MarketWatchScreenState();
}

class _MarketWatchScreenState extends State<MarketWatchScreen> {
  final ApiService _api = ApiService();

  List<String>      _pairs     = ['EUR/USD', 'GBP/USD', 'USD/JPY'];
  String            _layout    = 'grid';
  List<_PriceData>  _prices    = [];
  bool              _loading   = true;
  String?           _error;
  String            _sortField = 'pair'; // 'pair' | 'change' | 'spread'
  bool              _sortAsc   = true;
  Timer?            _timer;

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
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final pairs = prefs.getStringList(_kSelectedPairs);
    if (pairs != null && pairs.isNotEmpty) {
      setState(() {
        _pairs  = pairs;
        _layout = prefs.getString(_kLayoutMode) ?? 'grid';
      });
    }
  }

  Future<void> _fetch() async {
    try {
      // ApiService.getForexRates returns Map<String, dynamic> with pair data
      final raw = await _api.getForexRates(pairs: _pairs);
      final rates = raw['rates'] as Map<String, dynamic>? ?? raw;
      final data = <_PriceData>[];
      for (final pair in _pairs) {
        final key = pair.replaceAll('/', '');
        final entry = rates[key] ?? rates[pair];
        if (entry is Map<String, dynamic>) {
          data.add(_PriceData.fromApi(pair, entry));
        } else if (entry is num) {
          final existing = _prices.firstWhere(
            (p) => p.pair == pair,
            orElse: () => _PriceData(
              pair: pair,
              bid: 0,
              ask: 0,
              change: 0,
              changePct: 0,
              spread: 0,
              trend: 'flat',
              spark: [],
            ),
          );
          final bid = entry.toDouble();
          final prevBid = existing.bid;
          final change = prevBid == 0 ? 0.0 : bid - prevBid;
          final changePct = prevBid == 0 ? 0.0 : (change / prevBid) * 100;
          final spark = <double>[
            if (existing.spark.isNotEmpty) ...existing.spark
            else if (existing.bid != 0) ...List.filled(12, existing.bid),
          ];
          if (spark.isEmpty) {
            spark.addAll(List.filled(12, bid));
          }
          spark.add(bid);
          if (spark.length > 12) {
            spark.removeRange(0, spark.length - 12);
          }
          data.add(_PriceData.fromApi(pair, {
            'bid': bid,
            'ask': bid * 1.0002,
            'change': change,
            'change_pct': changePct,
            'sparkline': spark,
          }));
        } else {
          // graceful fallback: keep last price or placeholder
          final existing = _prices.firstWhere(
            (p) => p.pair == pair,
            orElse: () => _PriceData(
              pair: pair,
              bid: 0,
              ask: 0,
              change: 0,
              changePct: 0,
              spread: 0,
              trend: 'flat',
              spark: [],
            ),
          );
          data.add(existing);
        }
      }
      if (mounted) {
        setState(() {
          _prices  = _sorted(data);
          _loading = false;
          _error   = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = 'Failed to load rates. Pull to refresh.';
        });
      }
    }
  }

  List<_PriceData> _sorted(List<_PriceData> data) {
    final list = List<_PriceData>.from(data);
    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'change':
          cmp = a.changePct.compareTo(b.changePct);
        case 'spread':
          cmp = a.spread.compareTo(b.spread);
        default:
          cmp = a.pair.compareTo(b.pair);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _setSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc   = field == 'pair';
      }
      _prices = _sorted(_prices);
    });
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
            'Market Watch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          Text(
            '${_pairs.length} pairs · updates every 30s',
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
          icon: Icon(
            _layout == 'grid' ? Icons.view_list_rounded : Icons.grid_view_rounded,
            size: 20,
          ),
          tooltip: 'Toggle layout',
          onPressed: () => setState(() => _layout = _layout == 'grid' ? 'list' : 'grid'),
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 20),
          tooltip: 'Setup',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.customSetup),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          tooltip: 'Refresh',
          onPressed: () {
            setState(() => _loading = true);
            _fetch();
          },
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading && _prices.isEmpty) return _buildLoading();
    if (_error != null && _prices.isEmpty) return _buildError(isDark);

    return RefreshIndicator(
      color: const Color(0xFFF0A500),
      onRefresh: _fetch,
      child: Column(
        children: [
          if (_layout == 'list') _buildSortBar(isDark),
          Expanded(
            child: _layout == 'grid'
                ? _buildGrid(isDark)
                : _buildList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F4F0),
      child: Row(
        children: [
          _SortButton(label: 'Pair',   field: 'pair',   active: _sortField == 'pair',   asc: _sortAsc, onTap: () => _setSort('pair'),   isDark: isDark),
          const Spacer(),
          _SortButton(label: 'Change', field: 'change', active: _sortField == 'change', asc: _sortAsc, onTap: () => _setSort('change'), isDark: isDark),
          const SizedBox(width: 24),
          _SortButton(label: 'Spread', field: 'spread', active: _sortField == 'spread', asc: _sortAsc, onTap: () => _setSort('spread'), isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: _prices.length,
      itemBuilder: (_, i) => _PriceGridCard(data: _prices[i], isDark: isDark),
    );
  }

  Widget _buildList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _prices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _PriceListTile(data: _prices[i], isDark: isDark),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFF0A500), strokeWidth: 2),
          SizedBox(height: 16),
          Text('Loading market data…',
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
          const Icon(Icons.signal_wifi_off_rounded, color: Color(0xFF8A8880), size: 40),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Something went wrong',
            style: const TextStyle(color: Color(0xFF8A8880), fontSize: 14),
            textAlign: TextAlign.center,
          ),
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
}

// ─────────────────────────────────────────────────────────────
//  Price Grid Card
// ─────────────────────────────────────────────────────────────
class _PriceGridCard extends StatelessWidget {
  final _PriceData data;
  final bool isDark;

  const _PriceGridCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUp   = data.trend == 'up';
    final isDown = data.trend == 'down';
    final changeColor = isUp
        ? const Color(0xFF00C896)
        : isDown
            ? const Color(0xFFFF4D6D)
            : const Color(0xFF8A8880);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141619) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.pair,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _TrendBadge(trend: data.trend),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            data.bid == 0 ? '—' : data.bid.toStringAsFixed(_decimalPlaces(data.pair)),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.changePct == 0
                    ? '—'
                    : '${data.changePct >= 0 ? '+' : ''}${data.changePct.toStringAsFixed(3)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: changeColor,
                ),
              ),
              Text(
                data.spread == 0 ? '' : '${data.spread.toStringAsFixed(1)}p',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFF8A8880),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Price List Tile
// ─────────────────────────────────────────────────────────────
class _PriceListTile extends StatelessWidget {
  final _PriceData data;
  final bool isDark;

  const _PriceListTile({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUp   = data.trend == 'up';
    final isDown = data.trend == 'down';
    final changeColor = isUp
        ? const Color(0xFF00C896)
        : isDown
            ? const Color(0xFFFF4D6D)
            : const Color(0xFF8A8880);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141619) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFD3D1C7),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              data.pair,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.bid == 0
                      ? '—'
                      : data.bid.toStringAsFixed(_decimalPlaces(data.pair)),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  data.ask == 0
                      ? ''
                      : 'Ask: ${data.ask.toStringAsFixed(_decimalPlaces(data.pair))}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF8A8880),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.changePct == 0
                    ? '—'
                    : '${data.changePct >= 0 ? '+' : ''}${data.changePct.toStringAsFixed(3)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: changeColor,
                ),
              ),
              Text(
                data.spread == 0 ? '' : 'Spread ${data.spread.toStringAsFixed(1)}p',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFF8A8880),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          _TrendBadge(trend: data.trend),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helper widgets
// ─────────────────────────────────────────────────────────────
class _TrendBadge extends StatelessWidget {
  final String trend;
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend == 'flat') return const SizedBox.shrink();
    final up = trend == 'up';
    return Icon(
      up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
      color: up ? const Color(0xFF00C896) : const Color(0xFFFF4D6D),
      size: 22,
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final String field;
  final bool active;
  final bool asc;
  final VoidCallback onTap;
  final bool isDark;

  const _SortButton({
    required this.label,
    required this.field,
    required this.active,
    required this.asc,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              fontFamily: 'monospace',
              color: active ? const Color(0xFFF0A500) : const Color(0xFF8A8880),
              letterSpacing: 0.5,
            ),
          ),
          if (active) ...[
            const SizedBox(width: 2),
            Icon(
              asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 10,
              color: const Color(0xFFF0A500),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Utilities
// ─────────────────────────────────────────────────────────────
int _decimalPlaces(String pair) {
  // JPY pairs have 3 decimal places, others 5
  return pair.contains('JPY') ? 3 : 5;
}
