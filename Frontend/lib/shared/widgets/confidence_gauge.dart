import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConfidenceGauge extends StatefulWidget {
  final double confidence;
  final double size;

  const ConfidenceGauge({
    Key? key,
    required this.confidence,
    this.size = 200,
  }) : super(key: key);

  @override
  State<ConfidenceGauge> createState() => _ConfidenceGaugeState();
}

class _ConfidenceGaugeState extends State<ConfidenceGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0,
      end: widget.confidence / 100,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: ConfidenceGaugePainter(
            confidence: _animation.value,
            backgroundColor: const Color(0xFF1E2A3E),
            progressColor: const Color(0xFF00FFC2),
            glowColor: const Color(0xFF00D9FF),
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(widget.confidence * _animation.value).toInt()}%',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Color(0xFF00FFC2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FFC2).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00FFC2).withOpacity(0.5),
                      ),
                    ),
                    child: const Text(
                      'AI CONFIDENCE SCORE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00FFC2),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ConfidenceGaugePainter extends CustomPainter {
  final double confidence;
  final Color backgroundColor;
  final Color progressColor;
  final Color glowColor;

  ConfidenceGaugePainter({
    required this.confidence,
    required this.backgroundColor,
    required this.progressColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final strokeWidth = 15.0;

    final backgroundPaint = Paint()
      ..color = backgroundColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final progressAngle = 2 * math.pi * confidence;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progressAngle,
      false,
      glowPaint,
    );

    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          progressColor,
          glowColor,
          progressColor,
        ],
        stops: const [0.0, 0.5, 1.0],
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + progressAngle,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progressAngle,
      false,
      progressPaint,
    );

    final innerCirclePaint = Paint()
      ..color = const Color(0xFF0A1628)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius - strokeWidth - 5, innerCirclePaint);
  }

  @override
  bool shouldRepaint(ConfidenceGaugePainter oldDelegate) {
    return oldDelegate.confidence != confidence;
  }
}
