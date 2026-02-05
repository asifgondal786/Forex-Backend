import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedCurrencyPair = 'EUR/USD';
  String selectedTimeframe = '1H';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF1A2742),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 1200) {
                          return _buildDesktopLayout();
                        } else if (constraints.maxWidth > 800) {
                          return _buildTabletLayout();
                        } else {
                          return _buildMobileLayout();
                        }
                      },
                    ),
                  ),
                ),
              ),
              _buildBottomTicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00D9FF).withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.currency_exchange,
              color: Color(0xFF00D9FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Forex Companion',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _buildCurrencyPairSelector(),
          const SizedBox(width: 16),
          _buildTimeframeSelector(),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00D9FF).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xFF00FFC2),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '\$5,843.21',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildUserProfile(),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPairSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.3),
        ),
      ),
      child: DropdownButton<String>(
        value: selectedCurrencyPair,
        dropdownColor: const Color(0xFF1E2A3E),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: ['EUR/USD', 'GBP/USD', 'USD/JPY', 'USD/CHF']
            .map((pair) => DropdownMenuItem(
                  value: pair,
                  child: Text(pair),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            selectedCurrencyPair = value ?? selectedCurrencyPair;
          });
        },
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: ['1M', '5M', '15M', '1H', '4H', '1D'].map((tf) {
          final isSelected = tf == selectedTimeframe;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedTimeframe = tf;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00D9FF).withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(color: const Color(0xFF00D9FF))
                    : null,
              ),
              child: Text(
                tf,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00FFC2) : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserProfile() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00D9FF), Color(0xFF00FFC2)],
            ),
            border: Border.all(color: const Color(0xFF00FF88), width: 2),
          ),
          child: const Center(
            child: Text(
              'JD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'John Doe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: const [
                Icon(Icons.circle, color: Color(0xFF00FF88), size: 8),
                SizedBox(width: 4),
                Text(
                  'Available Online',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildLeftPanel(),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _buildCenterPanel(),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: _buildRightPanel(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildLeftPanel(),
              const SizedBox(height: 16),
              _buildCenterPanel(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRightPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildLeftPanel(),
        const SizedBox(height: 16),
        _buildCenterPanel(),
        const SizedBox(height: 16),
        _buildRightPanel(),
      ],
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      children: [
        _buildWelcomeHeader(),
        const SizedBox(height: 16),
        _buildAccountBalanceCard(),
        const SizedBox(height: 16),
        _buildConfidenceSection(),
      ],
    );
  }

  Widget _buildCenterPanel() {
    return Column(
      children: [
        _buildAiTasksPanel(),
        const SizedBox(height: 16),
        _buildAiPredictionsList(),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Column(
      children: [
        _buildChartWidget(),
        const SizedBox(height: 16),
        _buildNewsPanel(),
        const SizedBox(height: 16),
        _buildSecurityPanel(),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2742), Color(0xFF2A3F5F)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Welcome to Your Forex Co-Pilot',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fully autonomous AI: "U Sleep, I Work for U"',
            style: TextStyle(
              color: Color(0xFF00D9FF),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Tasks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Current Balance:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '\$5,843.21',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Assets',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            '\$3,582.44 USD',
            style: TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: const Center(
        child: Text(
          'Confidence Gauge (83%) - Use ConfidenceGauge widget here',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAiTasksPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: const Center(
        child: Text(
          'AI-Managed Tasks Panel',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAiPredictionsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: const Center(
        child: Text(
          'AI Predictions List',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildChartWidget() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: const Center(
        child: Text(
          'Candlestick Chart - Use fl_chart or syncfusion',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildNewsPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: const Center(
        child: Text(
          'News & Market Updates',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSecurityPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security & Permissions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSecurityItem(
            'Instantly Link accounts to Forex.com',
            '\$16.02',
            true,
          ),
          _buildSecurityItem(
            'Secure API with limited authority',
            '',
            true,
          ),
          _buildSecurityItem(
            'Emergency Stop',
            '24/7 monitoring',
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(String title, String subtitle, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF00FF88).withOpacity(0.2)
                  : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(
              enabled ? Icons.check_circle : Icons.circle_outlined,
              color: enabled ? const Color(0xFF00FF88) : Colors.white30,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTicker() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3E).withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00D9FF).withOpacity(0.2),
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildTickerItem('EUR/USD', '0.41%', true),
          _buildTickerItem('GBP/USD', '-0.15%', false),
          _buildTickerItem('USD/JPY', '+31.3%', true),
          _buildTickerItem('USD/CHF', '-0.23%', false),
        ],
      ),
    );
  }

  Widget _buildTickerItem(String pair, String change, bool isPositive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF253447),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.currency_exchange,
            color: isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3B30),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            pair,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3B30))
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3B30),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    color: isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3B30),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
