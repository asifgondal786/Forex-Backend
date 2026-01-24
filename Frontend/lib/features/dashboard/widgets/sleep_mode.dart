import 'package:flutter/material.dart';
import 'dart:async';

/// Sleep Mode - User can set "sleeping" mode where AI trades conservatively
/// Features:
/// - Toggle sleep mode on/off
/// - Shows when AI will wake up
/// - Displays changes in trading strategy during sleep
/// - Visual indicator of active protection
class SleepMode extends StatefulWidget {
  final bool isActive;
  final Duration sleepDuration;
  final VoidCallback onToggle;
  final VoidCallback? onWakeup;

  const SleepMode({
    Key? key,
    required this.isActive,
    required this.sleepDuration,
    required this.onToggle,
    this.onWakeup,
  }) : super(key: key);

  @override
  State<SleepMode> createState() => _SleepModeState();
}

class _SleepModeState extends State<SleepMode> with TickerProviderStateMixin {
  late Timer _countdownTimer;
  late Duration _remainingTime;
  late AnimationController _pulseController;
  late AnimationController _sleepIconController;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.sleepDuration;
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _sleepIconController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    if (widget.isActive) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted) {
          setState(() {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
            if (_remainingTime.inSeconds <= 0) {
              timer.cancel();
              _wakeup();
            }
          });
        }
      },
    );
  }

  void _wakeup() {
    widget.onWakeup?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wb_sunny, color: Colors.white),
              SizedBox(width: 12),
              Text('AI woke up! Ready to trade again.'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(SleepMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _remainingTime = widget.sleepDuration;
      _startCountdown();
    } else if (!widget.isActive && oldWidget.isActive) {
      _countdownTimer.cancel();
    }
  }

  @override
  void dispose() {
    if (widget.isActive) {
      _countdownTimer.cancel();
    }
    _pulseController.dispose();
    _sleepIconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isActive
              ? [
                  const Color(0xFF1E3A8A).withOpacity(0.9),
                  const Color(0xFF1E293B),
                ]
              : [
                  const Color(0xFF1F2937),
                  const Color(0xFF111827),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isActive
              ? const Color(0xFF3B82F6).withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: widget.isActive ? 2 : 1,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Stack(
        children: [
          // Animated background glow
          if (widget.isActive)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6)
                              .withOpacity(0.3 * _pulseController.value),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header with toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _sleepIconController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _sleepIconController.value * 0.2,
                              child: Opacity(
                                opacity: 0.7 +
                                    (_sleepIconController.value * 0.3),
                                child: const Text(
                                  '😴',
                                  style: TextStyle(fontSize: 28),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sleep Mode',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              widget.isActive
                                  ? 'AI trades conservatively'
                                  : 'Tap to enable protection',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildToggleButton(),
                  ],
                ),
                const SizedBox(height: 12),

                // Status and timer
                if (widget.isActive) ...[
                  _buildTimerDisplay(),
                  const SizedBox(height: 12),
                  _buildStrategyChanges(),
                ],

                // Features during sleep
                if (widget.isActive) ...[
                  const SizedBox(height: 12),
                  _buildSleepFeatures(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isActive
              ? const Color(0xFF3B82F6)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.isActive
                ? const Color(0xFF3B82F6)
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          widget.isActive ? 'AWAKEN' : 'SLEEP',
          style: TextStyle(
            color: widget.isActive ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final hours = _remainingTime.inHours;
    final minutes = _remainingTime.inMinutes.remainder(60);
    final seconds = _remainingTime.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.schedule,
            color: Color(0xFF3B82F6),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Waking up in: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyChanges() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Strategy Changes',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _StrategyChange(
            before: 'Risk: 2% per trade',
            after: 'Risk: 0.5% per trade',
            status: '🛡️ Protected',
          ),
          const SizedBox(height: 6),
          _StrategyChange(
            before: 'Aggressive trend following',
            after: 'Conservative range trading',
            status: '💤 Calm',
          ),
          const SizedBox(height: 6),
          _StrategyChange(
            before: 'News-driven trades allowed',
            after: 'No news trades',
            status: '🔇 Silent',
          ),
        ],
      ),
    );
  }

  Widget _buildSleepFeatures() {
    return Column(
      children: [
        _SleepFeatureRow(
          icon: Icons.trending_down,
          label: 'Position Sizes',
          value: 'Reduced by 75%',
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 8),
        _SleepFeatureRow(
          icon: Icons.stop,
          label: 'Stop Loss',
          value: 'Tightened to 15 pips',
          color: const Color(0xFF10B981),
        ),
        const SizedBox(height: 8),
        _SleepFeatureRow(
          icon: Icons.lock,
          label: 'New Signals',
          value: 'Ignored until wake',
          color: const Color(0xFFEC4899),
        ),
      ],
    );
  }
}

class _StrategyChange extends StatelessWidget {
  final String before;
  final String after;
  final String status;

  const _StrategyChange({
    required this.before,
    required this.after,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            before,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.arrow_forward,
          size: 12,
          color: Color(0xFF3B82F6),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            after,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          status,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _SleepFeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SleepFeatureRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
