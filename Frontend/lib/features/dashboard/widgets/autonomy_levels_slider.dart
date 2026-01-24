import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Autonomy Levels Slider - Allows users to control AI independence
/// Spectrum: Manual → Assisted → Semi-Auto → Full Auto
class AutonomyLevelsSlider extends StatefulWidget {
  final String currentLevel; // 'Manual' | 'Assisted' | 'Semi-Auto' | 'Full Auto'
  final ValueChanged<String> onLevelChanged;
  final VoidCallback? onInfoTapped;

  const AutonomyLevelsSlider({
    Key? key,
    required this.currentLevel,
    required this.onLevelChanged,
    this.onInfoTapped,
  }) : super(key: key);

  @override
  State<AutonomyLevelsSlider> createState() => _AutonomyLevelsSliderState();
}

class _AutonomyLevelsSliderState extends State<AutonomyLevelsSlider> {
  final List<String> _levels = ['Manual', 'Assisted', 'Semi-Auto', 'Full Auto'];
  late String _selectedLevel;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.currentLevel;
  }

  double _getLevelValue(String level) {
    return _levels.indexOf(level).toDouble();
  }

  String _getLevelFromValue(double value) {
    return _levels[value.toInt()];
  }

  String _getLevelDescription(String level) {
    switch (level) {
      case 'Manual':
        return 'You decide all trades. AI provides analysis only.';
      case 'Assisted':
        return 'AI suggests trades. You approve each one.';
      case 'Semi-Auto':
        return 'AI trades within limits. You monitor actively.';
      case 'Full Auto':
        return 'AI trades fully autonomous. You can stop anytime.';
      default:
        return '';
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Manual':
        return Icons.person;
      case 'Assisted':
        return Icons.person_add;
      case 'Semi-Auto':
        return Icons.smart_toy;
      case 'Full Auto':
        return Icons.auto_awesome;
      default:
        return Icons.help;
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Manual':
        return const Color(0xFF3B82F6); // Blue
      case 'Assisted':
        return const Color(0xFF10B981); // Green
      case 'Semi-Auto':
        return const Color(0xFFF59E0B); // Amber
      case 'Full Auto':
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI Autonomy Level',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: widget.onInfoTapped,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _getLevelColor(_selectedLevel),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: _getLevelColor(_selectedLevel),
              overlayColor: _getLevelColor(_selectedLevel).withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _getLevelValue(_selectedLevel),
              min: 0,
              max: 3,
              divisions: 3,
              onChanged: (value) {
                final newLevel = _getLevelFromValue(value);
                setState(() => _selectedLevel = newLevel);
                widget.onLevelChanged(newLevel);
              },
            ),
          ),
          const SizedBox(height: 12),

          // Level Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _levels
                .map((level) => _LevelIndicator(
                      level: level,
                      isActive: _selectedLevel == level,
                      color: _getLevelColor(level),
                      icon: _getLevelIcon(level),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Description & Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getLevelColor(_selectedLevel).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getLevelColor(_selectedLevel).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Level
                Row(
                  children: [
                    Icon(
                      _getLevelIcon(_selectedLevel),
                      size: 18,
                      color: _getLevelColor(_selectedLevel),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedLevel,
                      style: TextStyle(
                        color: _getLevelColor(_selectedLevel),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  _getLevelDescription(_selectedLevel),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Capabilities for each level
                ..._buildCapabilities(_selectedLevel),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Warning for Full Auto
          if (_selectedLevel == 'Full Auto')
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Full autonomy enabled. Emergency stop always available.',
                      style: TextStyle(
                        color: const Color(0xFFEF4444).withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCapabilities(String level) {
    final Map<String, List<String>> capabilities = {
      'Manual': [
        '✓ View AI analysis & signals',
        '✓ Make all trading decisions',
        '✗ No automated trades',
      ],
      'Assisted': [
        '✓ AI suggests trades',
        '✓ You approve each trade',
        '✓ Real-time notifications',
      ],
      'Semi-Auto': [
        '✓ AI trades up to limit',
        '✓ Active monitoring required',
        '✓ You set risk parameters',
      ],
      'Full Auto': [
        '✓ Complete AI autonomy',
        '✓ Trade within risk limits',
        '✓ Emergency stop always ready',
      ],
    };

    return [
      Text(
        'This level enables:',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      ...capabilities[level]?.map(
            (cap) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                cap,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ),
          ) ??
          [],
    ];
  }
}

class _LevelIndicator extends StatelessWidget {
  final String level;
  final bool isActive;
  final Color color;
  final IconData icon;

  const _LevelIndicator({
    required this.level,
    required this.isActive,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: isActive ? color : Colors.white.withOpacity(0.2),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? color : Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            level,
            style: TextStyle(
              color: isActive ? color : Colors.white.withOpacity(0.4),
              fontSize: 9,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
