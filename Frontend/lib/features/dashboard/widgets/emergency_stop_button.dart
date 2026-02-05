import 'package:flutter/material.dart';
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

class _EmergencyStopButtonState extends State<EmergencyStopButton> {
  @override
  Widget build(BuildContext context) {
    final Color buttonColor = widget.isStopped
        ? const Color(0xFF93C5FD) // light blue, slightly dimmed
        : const Color(0xFF60A5FA); // light blue

    return Positioned(
      bottom: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isStopped ? null : _handleStop,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: buttonColor,
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withOpacity(0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.isStopped ? '✓' : '⛔',
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
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
