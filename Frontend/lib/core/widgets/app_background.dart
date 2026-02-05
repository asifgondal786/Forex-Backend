import 'dart:math';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF050A1A),
                Color(0xFF0B1630),
                Color(0xFF0F1E3A),
                Color(0xFF162B4F),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _StarFieldPainter(),
          ),
        ),
        Positioned(
          top: -120,
          left: -60,
          child: _GlowOrb(
            size: 220,
            color: const Color(0xFF1D4ED8),
            opacity: 0.25,
          ),
        ),
        Positioned(
          right: -90,
          top: 120,
          child: _GlowOrb(
            size: 240,
            color: const Color(0xFF60A5FA),
            opacity: 0.2,
          ),
        ),
        Positioned(
          left: 60,
          bottom: -120,
          child: _GlowOrb(
            size: 260,
            color: const Color(0xFF10B981),
            opacity: 0.15,
          ),
        ),
        child,
      ],
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final List<_Star> _stars;

  _StarFieldPainter() : _stars = _generateStars();

  static List<_Star> _generateStars() {
    final random = Random(42);
    return List.generate(140, (index) {
      return _Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: random.nextDouble() * 1.4 + 0.4,
        opacity: random.nextDouble() * 0.6 + 0.2,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final star in _stars) {
      paint.color = Colors.white.withValues(alpha: star.opacity);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double opacity;

  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
  });
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
