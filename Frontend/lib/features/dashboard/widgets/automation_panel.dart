import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AutomationPanel extends StatefulWidget {
  const AutomationPanel({super.key});

  @override
  State<AutomationPanel> createState() => _AutomationPanelState();
}

class _AutomationPanelState extends State<AutomationPanel> {
  bool _automationEnabled = false;
  double _maxDailyLoss = 2.0;
  double _investmentPerTrade = 1000.0;
  double _riskPerTrade = 1.5;
  bool _autoTradeEUR = true;
  bool _autoTradeGBP = false;
  bool _autoTradeJPY = true;
  bool _autoTradeAUD = false;
  bool _autoTradeCAD = true;

  final List<String> _availablePairs = [
    'EUR/USD',
    'GBP/USD',
    'USD/JPY',
    'AUD/USD',
    'USD/CAD',
  ];

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
                    '⚙️ Automation Control',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure AI trading parameters',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              // Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _automationEnabled
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : const Color(0xFF6B7280).withOpacity(0.15),
                  border: Border.all(
                    color: _automationEnabled
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF6B7280).withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _automationEnabled
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _automationEnabled ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: _automationEnabled
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
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

          // Master Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.15),
                  const Color(0xFF3B82F6).withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enable Automation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start AI-powered trading',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: _automationEnabled,
                    onChanged: (value) {
                      setState(() => _automationEnabled = value);
                    },
                    activeThumbColor: const Color(0xFF10B981),
                    activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Risk Settings Section
          _buildSectionHeader('Risk Settings'),
          const SizedBox(height: 12),

          // Max Daily Loss
          _buildSliderInput(
            label: 'Max Daily Loss (%)',
            value: _maxDailyLoss,
            min: 0.5,
            max: 10.0,
            division: 19,
            onChanged: (value) =>
                setState(() => _maxDailyLoss = value),
            icon: Icons.trending_down,
            warning: _maxDailyLoss > 5.0,
          ),
          const SizedBox(height: 16),

          // Investment Per Trade
          _buildSliderInput(
            label: 'Investment Per Trade (\$)',
            value: _investmentPerTrade,
            min: 100.0,
            max: 5000.0,
            division: 49,
            onChanged: (value) =>
                setState(() => _investmentPerTrade = value),
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 16),

          // Risk Per Trade
          _buildSliderInput(
            label: 'Risk Per Trade (%)',
            value: _riskPerTrade,
            min: 0.5,
            max: 5.0,
            division: 9,
            onChanged: (value) =>
                setState(() => _riskPerTrade = value),
            icon: Icons.shield,
          ),
          const SizedBox(height: 24),

          // Trading Pairs Section
          _buildSectionHeader('Trading Pairs'),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: isMobile ? 2 : 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPairToggle('EUR/USD', _autoTradeEUR, (v) {
                setState(() => _autoTradeEUR = v);
              }),
              _buildPairToggle('GBP/USD', _autoTradeGBP, (v) {
                setState(() => _autoTradeGBP = v);
              }),
              _buildPairToggle('USD/JPY', _autoTradeJPY, (v) {
                setState(() => _autoTradeJPY = v);
              }),
              _buildPairToggle('AUD/USD', _autoTradeAUD, (v) {
                setState(() => _autoTradeAUD = v);
              }),
              _buildPairToggle('USD/CAD', _autoTradeCAD, (v) {
                setState(() => _autoTradeCAD = v);
              }),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _automationEnabled
                      ? () {
                          _showConfirmationDialog('Start Trading');
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Trading'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    disabledBackgroundColor:
                        const Color(0xFF10B981).withOpacity(0.5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _automationEnabled
                      ? () {
                          _showConfirmationDialog('Pause Trading');
                        }
                      : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    disabledBackgroundColor:
                        const Color(0xFFF59E0B).withOpacity(0.5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showConfirmationDialog('Emergency Stop');
                  },
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[400],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSliderInput({
    required String label,
    required double value,
    required double min,
    required double max,
    required int division,
    required ValueChanged<double> onChanged,
    required IconData icon,
    bool warning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: warning
              ? const Color(0xFFF59E0B).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: division,
            onChanged: onChanged,
            activeColor: warning
                ? const Color(0xFFF59E0B)
                : const Color(0xFF3B82F6),
            inactiveColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildPairToggle(String pair, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: value
              ? [
                  const Color(0xFF10B981).withOpacity(0.15),
                  const Color(0xFF10B981).withOpacity(0.05),
                ]
              : [
                  Colors.white.withOpacity(0.04),
                  Colors.white.withOpacity(0.02),
                ],
        ),
        border: Border.all(
          color: value
              ? const Color(0xFF10B981).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pair,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF10B981),
              activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
              inactiveThumbColor: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        title: Text(
          action,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to $action?',
          style: TextStyle(
            color: Colors.grey[300],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$action initiated successfully'),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
