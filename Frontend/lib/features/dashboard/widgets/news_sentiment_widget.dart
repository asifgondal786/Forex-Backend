import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NewsSentimentWidget extends StatefulWidget {
  const NewsSentimentWidget({super.key});

  @override
  State<NewsSentimentWidget> createState() => _NewsSentimentWidgetState();
}

class _NewsSentimentWidgetState extends State<NewsSentimentWidget> {
  static const Duration _marqueeTick = Duration(milliseconds: 16);
  static const Duration _latestBlinkPeriod = Duration(milliseconds: 520);
  static const Duration _hotBlinkPeriod = Duration(milliseconds: 760);
  static const double _marqueeStepDesktop = 0.65;
  static const double _marqueeStepMobile = 0.48;

  final ScrollController _marqueeController = ScrollController();
  Timer? _marqueeTimer;
  Timer? _latestBlinkTimer;
  Timer? _hotBlinkTimer;
  bool _showLatestBlink = true;
  bool _showHotBlink = true;
  bool _pauseMarquee = false;
  double _marqueeStep = _marqueeStepDesktop;

  int _selectedCategory = 0;
  final List<String> _categories = ['All', 'Economic', 'Company', 'Market'];

  final List<Map<String, dynamic>> _newsList = [
    {
      'title': 'ECB Maintains Interest Rates at 4.25%',
      'source': 'Reuters',
      'time': '2h ago',
      'category': 'Economic',
      'sentiment': 'Neutral',
      'sentimentColor': const Color(0xFF3B82F6),
      'impact': 'HIGH',
      'impactColor': const Color(0xFFF59E0B),
      'excerpt':
          'European Central Bank decision came as expected, maintaining stability in eurozone.',
      'relatedPairs': ['EUR/USD', 'GBP/EUR'],
      'focus': 'Eurozone rates guidance and EUR crosses',
      'isLatest': true,
    },
    {
      'title': 'USD Strengthens Against Major Currencies',
      'source': 'Bloomberg',
      'time': '4h ago',
      'category': 'Market',
      'sentiment': 'Bullish',
      'sentimentColor': const Color(0xFF10B981),
      'impact': 'CRITICAL',
      'impactColor': const Color(0xFFEF4444),
      'excerpt':
          'Dollar index reached 6-month high amid broader risk-off sentiment in markets.',
      'relatedPairs': ['USD/JPY', 'USD/CAD', 'AUD/USD'],
      'focus': 'Dollar momentum and broad USD pair volatility',
      'isLatest': false,
    },
    {
      'title': 'Bank of Japan Signals Gradual Policy Shift',
      'source': 'Financial Times',
      'time': '6h ago',
      'category': 'Economic',
      'sentiment': 'Bearish',
      'sentimentColor': const Color(0xFFEF4444),
      'impact': 'HIGH',
      'impactColor': const Color(0xFFF59E0B),
      'excerpt':
          'BOJ Governor hints at possible tightening cycle beginning in Q2 2024.',
      'relatedPairs': ['USD/JPY', 'EUR/JPY'],
      'focus': 'Japan yield outlook and JPY reaction zones',
      'isLatest': false,
    },
    {
      'title': 'Oil Prices Rally on Supply Concerns',
      'source': 'CNBC',
      'time': '8h ago',
      'category': 'Market',
      'sentiment': 'Bullish',
      'sentimentColor': const Color(0xFF10B981),
      'impact': 'MEDIUM',
      'impactColor': const Color(0xFF06B6D4),
      'excerpt':
          'Crude prices surge as OPEC+ production cuts extend beyond expectations.',
      'relatedPairs': ['USD/CAD', 'AUD/USD'],
      'focus': 'Commodity FX flow and oil-sensitive pairs',
      'isLatest': false,
    },
    {
      'title': 'UK Inflation Data Beats Forecast',
      'source': 'Reuters',
      'time': '10h ago',
      'category': 'Economic',
      'sentiment': 'Bullish',
      'sentimentColor': const Color(0xFF10B981),
      'impact': 'HIGH',
      'impactColor': const Color(0xFFF59E0B),
      'excerpt':
          'UK CPI comes in at 4.2%, higher than expected, strengthening GBP outlook.',
      'relatedPairs': ['GBP/USD', 'EUR/GBP'],
      'focus': 'Sterling repricing around inflation surprises',
      'isLatest': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _startRibbonBlink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  void _startRibbonBlink() {
    _latestBlinkTimer?.cancel();
    _hotBlinkTimer?.cancel();

    _latestBlinkTimer = Timer.periodic(_latestBlinkPeriod, (_) {
      if (!mounted) return;
      setState(() {
        _showLatestBlink = !_showLatestBlink;
      });
    });

    _hotBlinkTimer = Timer.periodic(_hotBlinkPeriod, (_) {
      if (!mounted) return;
      setState(() {
        _showHotBlink = !_showHotBlink;
      });
    });
  }

  void _startMarquee() {
    _marqueeTimer?.cancel();
    _marqueeTimer = Timer.periodic(_marqueeTick, (_) {
      if (!_marqueeController.hasClients) return;
      if (_pauseMarquee) return;

      final maxScrollExtent = _marqueeController.position.maxScrollExtent;
      if (maxScrollExtent <= 0) return;

      final nextOffset = _marqueeController.offset + _marqueeStep;
      if (nextOffset >= maxScrollExtent) {
        _marqueeController.jumpTo(0);
      } else {
        _marqueeController.jumpTo(nextOffset);
      }
    });
  }

  void _restartMarqueeAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  bool _isHotNews(Map<String, dynamic> news) {
    final impact = news['impact'] as String? ?? '';
    return impact == 'HIGH' || impact == 'CRITICAL';
  }

  @override
  void dispose() {
    _marqueeTimer?.cancel();
    _latestBlinkTimer?.cancel();
    _hotBlinkTimer?.cancel();
    _marqueeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final targetStep = isMobile ? _marqueeStepMobile : _marqueeStepDesktop;
    if (_marqueeStep != targetStep) {
      _marqueeStep = targetStep;
      _restartMarqueeAfterLayout();
    }

    final filteredNews = _selectedCategory == 0
        ? _newsList
        : _newsList
            .where((news) => news['category'] == _categories[_selectedCategory])
            .toList();
    final displayNews = filteredNews.isEmpty ? _newsList : filteredNews;
    final loopedNews = [...displayNews, ...displayNews];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Forex News Marquee',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Right-to-left stream with latest/hot ribbons. Hover to pause.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                _categories.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = index);
                      _restartMarqueeAfterLayout();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedCategory == index
                            ? const Color(0xFF3B82F6)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: _selectedCategory == index
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _selectedCategory == index
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildNewsMarquee(loopedNews, isMobile),
          const SizedBox(height: 16),
          _buildSentimentGauge(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideY(begin: 0.1);
  }

  Widget _buildNewsMarquee(
      List<Map<String, dynamic>> loopedNews, bool isMobile) {
    return MouseRegion(
      onEnter: (_) => _pauseMarquee = true,
      onExit: (_) => _pauseMarquee = false,
      child: Container(
        height: isMobile ? 210 : 198,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            controller: _marqueeController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: List.generate(loopedNews.length, (index) {
                final news = loopedNews[index];
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 12 : 0,
                    right: 12,
                    top: 12,
                    bottom: 12,
                  ),
                  child: _buildMarqueeNewsItem(news, isMobile),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarqueeNewsItem(Map<String, dynamic> news, bool isMobile) {
    final isLatest = news['isLatest'] as bool? ?? false;
    final isHot = _isHotNews(news);

    return SizedBox(
      width: isMobile ? 320 : 440,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opened: ${news['title']}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isLatest)
                      _buildBlinkingRibbon(
                        'LATEST',
                        const Color(0xFFEF4444),
                        isVisible: _showLatestBlink,
                      ),
                    if (isLatest) const SizedBox(width: 6),
                    if (isHot)
                      _buildBlinkingRibbon(
                        'HOT',
                        const Color(0xFFF59E0B),
                        isVisible: _showHotBlink,
                      ),
                    const Spacer(),
                    _buildSentimentBadge(
                      news['sentiment'] as String,
                      news['sentimentColor'] as Color,
                    ),
                    const SizedBox(width: 6),
                    _buildImpactBadge(
                      news['impact'] as String,
                      news['impactColor'] as Color,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  news['title'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  news['excerpt'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Forex relevance: ${news['focus']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF93C5FD),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (news['relatedPairs'] as List<String>).map((pair) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        border: Border.all(
                          color:
                              const Color(0xFF3B82F6).withValues(alpha: 0.35),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pair,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      news['category'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      news['source'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[300],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      news['time'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlinkingRibbon(
    String label,
    Color color, {
    required bool isVisible,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: isVisible ? 1 : 0.28,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color.withValues(alpha: 0.9), width: 1.2),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentGauge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Market Sentiment',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFEF4444).withValues(alpha: 0.3),
                            const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            const Color(0xFF10B981).withValues(alpha: 0.3),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          value: 0.62,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Very Bearish',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Very Bullish',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Moderately',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Bullish',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '+62%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentBadge(String sentiment, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        sentiment,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildImpactBadge(String impact, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        impact,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
