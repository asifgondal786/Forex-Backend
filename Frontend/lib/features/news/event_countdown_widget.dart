import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_events_provider.dart';
import '../../routes/app_routes.dart';

// Palette — matches news_events_screen.dart
const _kBg      = Color(0xFF0A0E1A);
const _kCard    = Color(0xFF161D2E);
const _kBorder  = Color(0xFF1E2A3D);
const _kGold    = Color(0xFFD4A853);
const _kRed     = Color(0xFFFF4560);
const _kRedDim  = Color(0xFF3D0010);
const _kAmber   = Color(0xFFF59E0B);
const _kGreen   = Color(0xFF00C896);
const _kBlue    = Color(0xFF3B82F6);
const _kText    = Color(0xFFE2E8F0);
const _kSubtext = Color(0xFF64748B);

/// Compact banner shown on the dashboard.
/// Shows live countdown to the next high-impact event.
/// Turns red when shield is active (< 30 min).
class EventCountdownWidget extends StatefulWidget {
  const EventCountdownWidget({super.key});

  @override
  State<EventCountdownWidget> createState() => _EventCountdownWidgetState();
}

class _EventCountdownWidgetState extends State<EventCountdownWidget> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  String _eventTitle = '';
  String _eventCategory = '';
  bool _shieldActive = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Tick every second to update countdown
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _sync() {
    final provider = context.read<NewsEventsProvider>();
    _updateFromProvider(provider);
  }

  void _tick() {
    if (!mounted) return;
    if (_remaining.inSeconds > 0) {
      setState(() => _remaining -= const Duration(seconds: 1));
    } else {
      // Re-sync from provider when countdown hits zero
      _sync();
    }
  }

  void _updateFromProvider(NewsEventsProvider provider) {
    if (!mounted) return;
    final events = provider.upcomingEvents;
    if (events.isEmpty) {
      setState(() {
        _initialized = true;
        _eventTitle = 'No events scheduled';
        _eventCategory = '';
        _remaining = Duration.zero;
        _shieldActive = false;
      });
      return;
    }

    // Find next high-impact event
    final highImpact = events.where(
      (e) => e.impact == NewsImpact.high && e.isUpcoming,
    ).toList();

    final next = highImpact.isNotEmpty ? highImpact.first : events.first;
    final diff = next.scheduledAt.difference(DateTime.now());
    final remaining = diff.isNegative ? Duration.zero : diff;
    final shieldActive = remaining.inMinutes <= 30 && remaining.inMinutes >= 0;

    setState(() {
      _initialized = true;
      _eventTitle = next.title;
      _eventCategory = next.currency;
      _remaining = remaining;
      _shieldActive = shieldActive;
    });
  }

  String _fmt(Duration d) {
    if (d.inSeconds <= 0) return 'NOW';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsEventsProvider>(
      builder: (ctx, provider, _) {
        // Sync when provider updates
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateFromProvider(provider);
        });

        if (!_initialized || provider.upcomingEvents.isEmpty) {
          return const SizedBox.shrink();
        }

        final accent = _shieldActive ? _kRed : _kGold;
        final accentDim = _shieldActive ? _kRedDim : const Color(0xFF3D2800);

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.home),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _shieldActive
                  ? _kRedDim.withOpacity(0.6)
                  : _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withOpacity(0.4),
                width: _shieldActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Shield / clock icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Icon(
                    _shieldActive
                        ? Icons.shield_rounded
                        : Icons.schedule_rounded,
                    color: accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),

                // Event info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (_shieldActive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kRedDim,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: _kRed.withOpacity(0.4)),
                            ),
                            child: const Text('SHIELD ACTIVE',
                                style: TextStyle(
                                    color: _kRed,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (_eventCategory.isNotEmpty)
                          Text(_eventCategory,
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        _eventTitle,
                        style: const TextStyle(
                            color: _kText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Countdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmt(_remaining),
                      style: TextStyle(
                          color: accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ]),
                    ),
                    Text(
                      _shieldActive ? 'pause trading' : 'until event',
                      style: const TextStyle(
                          color: _kSubtext,
                          fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

