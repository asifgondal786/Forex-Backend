import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Market Events Timeline - Shows upcoming economic events that impact forex
class MarketEventsTimeline extends StatelessWidget {
  final List<MarketEvent> events;
  final VoidCallback? onEventTapped;

  const MarketEventsTimeline({
    Key? key,
    required this.events,
    this.onEventTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📅 Market Events',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Next ${events.length}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Timeline
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withOpacity(0.05),
              height: 1,
            ),
            itemBuilder: (context, index) => _TimelineEvent(
              event: events[index],
              isLast: index == events.length - 1,
              onTap: onEventTapped,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final MarketEvent event;
  final bool isLast;
  final VoidCallback? onTap;

  const _TimelineEvent({
    required this.event,
    required this.isLast,
    this.onTap,
  });

  Color _getImpactColor(String impact) {
    switch (impact.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF6B7280);
      default:
        return Colors.grey;
    }
  }

  String _getTimeUntil(DateTime eventTime) {
    final now = DateTime.now();
    final difference = eventTime.difference(now);

    if (difference.isNegative) {
      return 'Happened';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final days = difference.inDays;

    if (days > 0) {
      return '${days}d away';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Dot + Line
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getImpactColor(event.impact),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.white.withOpacity(0.1),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Event Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Title + Impact
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getImpactColor(event.impact)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getImpactColor(event.impact)
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          event.impact.toUpperCase(),
                          style: TextStyle(
                            color: _getImpactColor(event.impact),
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Country + Time
                  Row(
                    children: [
                      Text(
                        '🌍 ${event.country}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _getTimeUntil(event.time),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Time + Forecast
                  Row(
                    children: [
                      Text(
                        '⏰ ${DateFormat('MMM dd, HH:mm').format(event.time)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (event.forecast != null) ...[
                        Text(
                          'Forecast: ${event.forecast}',
                          style: TextStyle(
                            color: const Color(0xFF3B82F6),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Affected Pairs
                  if (event.affectedPairs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: event.affectedPairs
                          .map(
                            (pair) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              child: Text(
                                pair,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Market Event Data Model
class MarketEvent {
  final String title; // e.g., 'CPI Release', 'Fed Decision'
  final String country; // e.g., 'USA', 'EUR'
  final DateTime time;
  final String impact; // 'High' | 'Medium' | 'Low'
  final String? forecast; // e.g., '2.1%' or null
  final String? previous; // Previous value
  final List<String> affectedPairs; // e.g., ['EUR/USD', 'GBP/USD']
  final String? description;

  MarketEvent({
    required this.title,
    required this.country,
    required this.time,
    required this.impact,
    this.forecast,
    this.previous,
    this.affectedPairs = const [],
    this.description,
  });

  factory MarketEvent.example() {
    return MarketEvent(
      title: 'CPI Release',
      country: 'USA',
      time: DateTime.now().add(const Duration(hours: 2)),
      impact: 'High',
      forecast: '2.1%',
      previous: '2.0%',
      affectedPairs: ['EUR/USD', 'GBP/USD', 'USD/JPY'],
      description: 'Consumer Price Index measures inflation',
    );
  }
}
