import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Emergency STOP Button - Red, unmistakable kill switch
/// Always visible, sticky position
/// Builds trust instantly by showing user has control
class EmergencyStopButton extends StatefulWidget {
  final VoidCallback onStop;
  final bool isStopped;

  const EmergencyStopButton({
    Key? key,
    required this.onStop,
    this.isStopped = false,
  }) : super(key: key);

  @override
  State<EmergencyStopButton> createState() => _EmergencyStopButtonState();
}

class _EmergencyStopButtonState extends State<EmergencyStopButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: GestureDetector(
        onTap: _isPressed ? null : _handleStop,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tooltip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '⛔ STOP ALL AI ACTIONS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Button with Pulse Effect
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing background
                    if (!widget.isStopped)
                      Container(
                        width: 64 + (12 * _pulseController.value),
                        height: 64 + (12 * _pulseController.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444).withOpacity(
                            0.2 * (1 - _pulseController.value),
                          ),
                        ),
                      ),
                    // Main button
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: widget.isStopped
                              ? [
                                  const Color(0xFF6B7280),
                                  const Color(0xFF4B5563),
                                ]
                              : [
                                  const Color(0xFFEF4444),
                                  const Color(0xFFDC2626),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(
                              widget.isStopped ? 0 : 0.5,
                            ),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isPressed ? null : _handleStop,
                          borderRadius: BorderRadius.circular(32),
                          child: Center(
                            child: Transform.scale(
                              scale: _isPressed ? 0.9 : 1.0,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.isStopped ? '✓' : '⛔',
                                    style: const TextStyle(
                                      fontSize: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.isStopped ? 'STOPPED' : 'STOP',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleStop() {
    if (!widget.isStopped) {
      // Confirm dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text(
            '⛔ Stop All AI Actions?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'This will immediately halt all autonomous AI trading and monitoring.\n\nAre you sure?',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onStop();
              },
              child: const Text(
                'Yes, Stop Now',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
