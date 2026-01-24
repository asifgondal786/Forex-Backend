import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NewsSentimentWidget extends StatefulWidget {
  const NewsSentimentWidget({super.key});

  @override
  State<NewsSentimentWidget> createState() => _NewsSentimentWidgetState();
}

class _NewsSentimentWidgetState extends State<NewsSentimentWidget> {
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
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final filteredNews = _selectedCategory == 0
        ? _newsList
        : _newsList
            .where((news) => news['category'] == _categories[_selectedCategory])
            .toList();

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
                  const Text(
                    '📰 Market News & Sentiment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Financial news with market sentiment analysis',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                _categories.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedCategory == index
                            ? const Color(0xFF3B82F6)
                            : Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: _selectedCategory == index
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withOpacity(0.1),
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
          const SizedBox(height: 24),

          // News List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredNews.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                color: Colors.white.withOpacity(0.05),
                height: 1,
              ),
            ),
            itemBuilder: (context, index) {
              final news = filteredNews[index];
              return _buildNewsItem(news, index, isMobile);
            },
          ),
          const SizedBox(height: 16),

          // Market Sentiment Gauge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
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
                                  const Color(0xFFEF4444).withOpacity(0.3),
                                  const Color(0xFFF59E0B).withOpacity(0.3),
                                  const Color(0xFF3B82F6).withOpacity(0.3),
                                  const Color(0xFF10B981).withOpacity(0.3),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.62,
                                backgroundColor: Colors.transparent,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
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
                            color:
                                const Color(0xFF10B981).withOpacity(0.15),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
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
          ),
        ],
      ),
    );
  }

  Widget _buildNewsItem(Map<String, dynamic> news, int index, bool isMobile) {
    return GestureDetector(
      onTap: () {
        // Handle news item tap
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
          color: Colors.white.withOpacity(0.03),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Badges
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      news['title'],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      _buildSentimentBadge(
                        news['sentiment'],
                        news['sentimentColor'],
                      ),
                      const SizedBox(width: 8),
                      _buildImpactBadge(
                        news['impact'],
                        news['impactColor'],
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news['title'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildSentimentBadge(
                        news['sentiment'],
                        news['sentimentColor'],
                      ),
                      const SizedBox(width: 8),
                      _buildImpactBadge(
                        news['impact'],
                        news['impactColor'],
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Excerpt
            Text(
              news['excerpt'],
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Related Pairs and Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: (news['relatedPairs'] as List<String>)
                        .map((pair) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          border: Border.all(
                            color:
                                const Color(0xFF3B82F6).withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pair,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      news['source'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    Text(
                      news['time'],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideY(
          begin: 0.1,
          delay: Duration(milliseconds: index * 50),
        );
  }

  Widget _buildSentimentBadge(String sentiment, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(
          color: color.withOpacity(0.3),
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
        color: color.withOpacity(0.15),
        border: Border.all(
          color: color.withOpacity(0.3),
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
