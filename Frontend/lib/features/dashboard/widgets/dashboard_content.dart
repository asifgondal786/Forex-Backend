import 'package:flutter/material.dart';
import 'package:forex_companion/config/theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/widgets/app_background.dart';
import 'task_card.dart';
import 'task_history_table.dart';
import 'forex_feed_widget.dart';
import 'performance_analytics.dart';
import 'news_sentiment_widget.dart';
import 'ai_prediction_widget.dart';
import '../../../shared/widgets/glassmorphism_card.dart';

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return AppBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header Section
              _buildHeader(context, isMobile),

              const SizedBox(height: 24),

              // Main Content Area with Tabs
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActiveTasksTab(isMobile),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) _buildTopNavBar(),
          if (!isMobile) const SizedBox(height: 18),
          _buildHeroPanel(isMobile),
          const SizedBox(height: 18),
          _buildCompanionStatus(isMobile),
          if (!isMobile) const SizedBox(height: 20),
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/create-task');
              },
              icon: const Icon(Icons.add_circle),
              label: const Text('Create New Task'),
              style: AppTheme.glassElevatedButtonStyle(
                tintColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                borderRadius: 10,
                elevation: 4,
              ),
            )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 600))
                .slideX(begin: -0.3),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.menu, color: Colors.white70, size: 18),
            ),
            const SizedBox(width: 14),
            Row(
              children: [
                Image.asset(
                  'assets/images/companion_logo.png',
                  width: 28,
                  height: 28,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Forex Companion',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _buildUserPill(),
            const SizedBox(width: 10),
            _buildBalancePill(),
            const SizedBox(width: 10),
            _buildIconPill(
              icon: Icons.power_settings_new,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return _buildIconPill(
                  icon: themeProvider.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  onTap: themeProvider.toggleTheme,
                );
              },
            ),
            const SizedBox(width: 8),
            _buildNotificationPill(),
          ],
        ),
      ],
    );
  }

  Widget _buildUserPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFF22C55E),
            child: Icon(Icons.person, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'John Doe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Available Online',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildBalancePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: const [
          Icon(Icons.account_balance_wallet, color: Color(0xFF00FFC2), size: 18),
          SizedBox(width: 8),
          Text(
            '\$5,843.21',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconPill({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }

  Widget _buildNotificationPill() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.notifications_active,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildHeroPanel(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroLeft(isMobile),
                const SizedBox(height: 20),
                Center(child: _buildHeroVisual()),
                const SizedBox(height: 18),
                _buildMarketPanel(),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _buildHeroLeft(isMobile)),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: Center(child: _buildHeroVisual())),
                const SizedBox(width: 14),
                Expanded(flex: 5, child: _buildMarketPanel()),
              ],
            ),
    );
  }

  Widget _buildHeroLeft(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Your Forex Co-Pilot',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 20 : 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fully autonomous AI: "U Sleep, I Work for U"',
          style: TextStyle(
            color: const Color(0xFF7DD3FC),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildHeroChip('Smart Triggers', Icons.bolt),
            _buildHeroChip('Realtime Charts', Icons.candlestick_chart),
            _buildHeroChip('News-Aware', Icons.newspaper),
            _buildHeroChip('Autonomous Actions', Icons.auto_awesome),
          ],
        ),
        const SizedBox(height: 16),
        _buildAccountSummaryCard(
          title: 'Welcome back, John!',
          subtitle: 'Online',
          value: '\$5,843.21',
          accent: const Color(0xFF10B981),
          wide: true,
          showValueInHeader: true,
        ),
        const SizedBox(height: 10),
        _buildAccountSummaryCard(
          title: 'Total Account Balance',
          subtitle: 'All assets',
          value: '\$3,582.44',
          accent: const Color(0xFF60A5FA),
          wide: true,
        ),
      ],
    );
  }

  Widget _buildHeroChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7DD3FC)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroVisual() {
    return Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF60A5FA).withValues(alpha: 0.2),
            blurRadius: 36,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/robo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'STOP TRADING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSummaryCard({
    required String title,
    required String subtitle,
    required String value,
    required Color accent,
    bool wide = false,
    bool showValueInHeader = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      width: wide ? double.infinity : 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showValueInHeader)
                Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              if (title.startsWith('Welcome'))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Online',
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (!showValueInHeader) ...[
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'EUR/USD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Text(
                      '1H',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEF4444).withValues(alpha: 0.9),
                      const Color(0xFFDC2626).withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Text(
                  'STOP TRADING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF60A5FA), size: 16),
              const SizedBox(width: 6),
              Text(
                '1.0923',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+0.39%',
                style: TextStyle(
                  color: const Color(0xFF10B981).withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '1.0933',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMiniTab('RERE'),
              _buildMiniTab('UVS'),
              _buildMiniTab('ECSS'),
              _buildMiniTab('TF'),
              _buildMiniTab('MAC2'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 170, child: _buildMarketChart()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMarketTag('RSI', const Color(0xFF22C55E)),
              _buildMarketTag('MACD', const Color(0xFF60A5FA)),
              _buildMarketTag('VWAP', const Color(0xFFF59E0B)),
              _buildMarketTag('News', const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniSignalCard(
                title: 'News',
                subtitle: 'USD Declines',
                badge: 'Moderate',
                value: '8h',
                color: const Color(0xFF60A5FA),
              ),
              _buildMiniSignalCard(
                title: 'Profit',
                subtitle: 'EUR/USD',
                badge: '+0.21%',
                value: '1d',
                color: const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSignalCard({
    required String title,
    required String subtitle,
    required String badge,
    required String value,
    required Color color,
  }) {
    final sparkline = title == 'News'
        ? const [
            FlSpot(0, 1.2),
            FlSpot(1, 1.35),
            FlSpot(2, 1.25),
            FlSpot(3, 1.5),
            FlSpot(4, 1.4),
            FlSpot(5, 1.6),
          ]
        : const [
            FlSpot(0, 1.0),
            FlSpot(1, 1.08),
            FlSpot(2, 1.18),
            FlSpot(3, 1.12),
            FlSpot(4, 1.25),
            FlSpot(5, 1.35),
          ];

    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: _buildTinySparkline(
              spots: sparkline,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTab(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTinySparkline({
    required List<FlSpot> spots,
    required Color color,
  }) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            color: color,
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.2),
            ),
          ),
        ],
        minX: 0,
        maxX: 5,
        minY: 0.9,
        maxY: 1.7,
      ),
    );
  }

  Widget _buildMarketTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMarketChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 1.091),
              FlSpot(1, 1.093),
              FlSpot(2, 1.092),
              FlSpot(3, 1.096),
              FlSpot(4, 1.094),
              FlSpot(5, 1.097),
              FlSpot(6, 1.095),
            ],
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
            ),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.2),
                  const Color(0xFF3B82F6).withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        minX: 0,
        maxX: 6,
        minY: 1.088,
        maxY: 1.099,
      ),
    );
  }

  Widget _buildCompanionStatus(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0B1220),
            const Color(0xFF111827).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_alt,
                  color: Color(0xFF60A5FA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Companion Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitoring charts, news, and learning signals in real time.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusRow(
            'Market Pulse',
            'Stable',
            const Color(0xFF60A5FA),
            Icons.speed,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            'News Impact',
            'Monitoring',
            const Color(0xFFF59E0B),
            Icons.newspaper,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            'Learning Feed',
            'Syncing',
            const Color(0xFF34D399),
            Icons.school_outlined,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            'Autonomy',
            isMobile ? 'Guarded' : 'Guarded Mode',
            const Color(0xFF818CF8),
            Icons.shield_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final activeTasks = taskProvider.activeTasks.length;
        final completedTasks = taskProvider.completedTasks.length;
        final totalTasks = taskProvider.tasks.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              _buildStatCard(
                label: 'Live AI Operations',
                value: activeTasks.toString(),
                icon: Icons.play_circle,
                color: const Color(0xFF3B82F6),
                delay: 0,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                label: 'Executed Successfully',
                value: completedTasks.toString(),
                icon: Icons.check_circle,
                color: const Color(0xFF10B981),
                delay: 100,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                label: 'Total Operations',
                value: totalTasks.toString(),
                icon: Icons.task,
                color: const Color(0xFF8B5CF6),
                delay: 200,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: const Duration(milliseconds: 600))
          .slideY(
            begin: 0.3,
            delay: Duration(milliseconds: delay),
          ),
    );
  }

  Widget _buildTabNavigation(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTabButton('Live AI Operations', 0, isMobile),
          const SizedBox(width: 8),
          _buildTabButton('Executed Successfully', 1, isMobile),
          const SizedBox(width: 8),
          _buildTabButton('Analytics', 2, isMobile),
          const SizedBox(width: 8),
          _buildTabButton('News', 3, isMobile),
          const SizedBox(width: 8),
          _buildTabButton('Alerts', 4, isMobile),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, bool isMobile) {
    final isSelected = _selectedTab == index;

    return GlassmorphismCard(
      padding: EdgeInsets.zero,
      borderRadius: 10,
      blur: 14,
      opacity: isSelected ? 0.18 : 0.08,
      borderColor: const Color(0xFF3B82F6),
      borderWidth: 1,
      showGlow: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: isMobile ? 12 : 13,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isMobile) {
    switch (_selectedTab) {
      case 0:
        return _buildActiveTasksTab(isMobile);
      case 1:
        return _buildCompletedTasksTab();
      case 2:
        return _buildAnalyticsTab();
      case 3:
        return _buildNewsTab();
      case 4:
        return _buildAlertsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildActiveTasksTab(bool isMobile) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading tasks...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final activeTasks = taskProvider.activeTasks;

        if (activeTasks.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ForexFeedWidget()
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 600)),
              const SizedBox(height: 24),
              _buildTasksOverviewRow(),
              const SizedBox(height: 24),
              _buildAccessHeader(),
              const SizedBox(height: 16),
              const AIPredictionWidget(),
              const SizedBox(height: 24),
              _buildSecurityAndPermissions(),
              const SizedBox(height: 24),
              const TaskHistoryTable(),
              const SizedBox(height: 20),
              _buildBottomTickerRow(),
              const SizedBox(height: 10),
              _buildFooterNote(),
            ],
          );
        }

        if (isMobile) {
          // Mobile: Stack view
          return Column(
            children: [
              // Forex Feed
              const ForexFeedWidget(),
              const SizedBox(height: 16),
              // Task Cards
              ...activeTasks
                  .map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TaskCard(task: task),
                      ))
                  .toList(),
            ],
          );
        } else {
          // Desktop: Match reference layout
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ForexFeedWidget()
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 600))
                  .slideY(begin: 0.2),
              const SizedBox(height: 24),
              _buildTasksOverviewRow(),
              const SizedBox(height: 24),
              _buildAccessHeader(),
              const SizedBox(height: 16),
              const AIPredictionWidget(),
              const SizedBox(height: 24),
              _buildSecurityAndPermissions(),
              const SizedBox(height: 24),
              const TaskHistoryTable(),
              const SizedBox(height: 20),
              _buildBottomTickerRow(),
              const SizedBox(height: 10),
              _buildFooterNote(),
            ],
          );
        }
      },
    );
  }

  Widget _buildTasksOverviewRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildMyTasksPanel()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildAIManagedTasksPanel()),
                ],
              )
            : Column(
                children: [
                  _buildMyTasksPanel(),
                  const SizedBox(height: 16),
                  _buildAIManagedTasksPanel(),
                ],
              );
      },
    );
  }

  Widget _buildMyTasksPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Tasks',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Text(
                  'Online',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$5,843.21',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Assets  \$3,582.44',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildConfidenceGauge(),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStatTag('1.3572', const Color(0xFF60A5FA)),
              _buildStatTag('3,214 EUR', const Color(0xFF10B981)),
              _buildStatTag('1.42', const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceGauge() {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 0.83,
            strokeWidth: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '83%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Confidence',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAIManagedTasksPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI-Managed Tasks',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                'learning in 14h',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Current Task',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Smart Trigger - Active',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sell USD/PKR at 289',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  '81%',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Selling \$ when USD/PKR hits 289 shortly. Confidence: 81%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTaskAction('View', const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _buildTaskAction('Pause', Colors.white.withValues(alpha: 0.1)),
              const SizedBox(width: 8),
              _buildTaskAction('Log', Colors.white.withValues(alpha: 0.1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskAction(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == const Color(0xFF3B82F6)
              ? Colors.white
              : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAccessHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Access Forex.com + Limit Tasks + 24/7 Smart Alerts',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Text(
              'Estimated',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTickerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTickerItem('EUR/USD', '+0.41%', const Color(0xFF10B981)),
            const SizedBox(width: 16),
            _buildTickerItem('GBP/USD', '-0.15%', const Color(0xFFEF4444)),
            const SizedBox(width: 16),
            _buildTickerItem('USD/JPY', '+1.31%', const Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _buildTickerItem(String label, String change, Color color) {
    final isPositive = !change.trim().startsWith('-');
    return Row(
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          change,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterNote() {
    return Center(
      child: Text(
        'Every action is logged.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildSecurityAndPermissions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return isWide
            ? Row(
                children: [
                  Expanded(child: _buildSecurityPanel()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildConnectPanel()),
                ],
              )
            : Column(
                children: [
                  _buildSecurityPanel(),
                  const SizedBox(height: 16),
                  _buildConnectPanel(),
                ],
              );
      },
    );
  }

  Widget _buildSecurityPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF7DD3FC),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Security & Permissions',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  'Protected',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSecurityRow(
            Icons.lock_outline,
            'Secure API with limited authority',
            'Active',
            const Color(0xFF10B981),
          ),
          _buildSecurityRow(
            Icons.verified_user_outlined,
            'Read & trade permissions scoped',
            'Scoped',
            const Color(0xFF60A5FA),
          ),
          _buildSecurityRow(
            Icons.emergency,
            'Emergency stop always available',
            'Ready',
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityRow(
    IconData icon,
    String label,
    String status,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0B1220),
            const Color(0xFF1D4ED8).withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Connect Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Broker API',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Link your broker to unlock autonomous execution and real-time alerts.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              _buildConnectRow(Icons.shield_outlined, 'Secure API with limited authority'),
              _buildConnectRow(Icons.link_outlined, 'Instantly link accounts to Forex.com'),
              _buildConnectRow(Icons.emergency_outlined, '24/7 emergency stop'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.link),
                  label: const Text('Connect Account'),
                  style: AppTheme.glassElevatedButtonStyle(
                    tintColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    borderRadius: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Text(
                  '+\$16.02',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectRow(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTasksTab() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            const Text(
              'Completed Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed trading tasks will appear here',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const PerformanceAnalytics()
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 600))
              .slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildNewsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const NewsSentimentWidget()
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 600))
              .slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            const Text(
              'Trading Alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time alerts and notifications for your trades',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enable alerts in the Automation Panel to receive real-time notifications',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
