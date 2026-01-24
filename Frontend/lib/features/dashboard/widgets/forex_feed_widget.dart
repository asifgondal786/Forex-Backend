import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ForexFeedWidget extends StatefulWidget {
  const ForexFeedWidget({super.key});

  @override
  State<ForexFeedWidget> createState() => _ForexFeedWidgetState();
}

class _ForexFeedWidgetState extends State<ForexFeedWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<ForexPair> _pairs = [
    ForexPair(
      pair: 'EUR/USD',
      price: 1.0950,
      change: 0.0045,
      changePercent: 0.41,
      trend: 'UP',
    ),
    ForexPair(
      pair: 'GBP/USD',
      price: 1.2745,
      change: -0.0025,
      changePercent: -0.20,
      trend: 'DOWN',
    ),
    ForexPair(
      pair: 'USD/JPY',
      price: 149.85,
      change: 0.15,
      changePercent: 0.10,
      trend: 'UP',
    ),
    ForexPair(
      pair: 'AUD/USD',
      price: 0.6580,
      change: -0.0012,
      changePercent: -0.18,
      trend: 'DOWN',
    ),
    ForexPair(
      pair: 'USD/CAD',
      price: 1.3425,
      change: 0.0032,
      changePercent: 0.24,
      trend: 'UP',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.45);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                    '📈 Live Forex Rates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time market data',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live',
                      style: TextStyle(
                        color: Color(0xFF10B981),
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

          // Forex Cards Carousel
          if (isMobile)
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pairs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildForexCard(_pairs[index], index),
                  );
                },
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pairs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 220,
                      child: _buildForexCard(_pairs[index], index),
                    ),
                  );
                },
              ),
            ),

          if (isMobile) ...[
            const SizedBox(height: 12),
            // Page Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pairs.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF3B82F6)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForexCard(ForexPair pair, int index) {
    final isPositive = pair.changePercent >= 0;
    final trendColor =
        isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            trendColor.withOpacity(0.15),
            trendColor.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: trendColor.withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: trendColor.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair.pair,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pair.trend == 'UP' ? '▲ Bullish' : '▼ Bearish',
                      style: TextStyle(
                        fontSize: 10,
                        color: trendColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: trendColor,
                size: 24,
              ),
            ],
          ),

          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pair.price.toStringAsFixed(4)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${pair.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: trendColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isPositive ? '+' : ''}${pair.change.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Trade Now',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: trendColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 11,
                    color: trendColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideX(
          begin: 0.2,
          delay: Duration(milliseconds: index * 100),
        );
  }
}

class ForexPair {
  final String pair;
  final double price;
  final double change;
  final double changePercent;
  final String trend;

  ForexPair({
    required this.pair,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.trend,
  });
}
