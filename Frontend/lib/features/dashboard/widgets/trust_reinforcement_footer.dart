import 'package:flutter/material.dart';

/// Trust Reinforcement Footer - Rotating trust statements and contextual messaging
/// Builds confidence through transparency and accountability
class TrustReinforcementFooter extends StatefulWidget {
  final bool isAIActive;
  final String? userEmail;

  const TrustReinforcementFooter({
    Key? key,
    required this.isAIActive,
    this.userEmail,
  }) : super(key: key);

  @override
  State<TrustReinforcementFooter> createState() =>
      _TrustReinforcementFooterState();
}

class _TrustReinforcementFooterState extends State<TrustReinforcementFooter>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  int _currentStatementIndex = 0;

  final List<_TrustStatement> _statements = [
    _TrustStatement(
      emoji: '🔐',
      text: 'AI never exceeds your limits.',
      tooltip: 'Every trade respects your risk parameters',
    ),
    _TrustStatement(
      emoji: '📋',
      text: 'Every action is logged.',
      tooltip: 'Full audit trail available for review',
    ),
    _TrustStatement(
      emoji: '🚫',
      text: 'No withdrawal authority granted.',
      tooltip: 'Only you can move your funds',
    ),
    _TrustStatement(
      emoji: '⚖️',
      text: 'You control all trading parameters.',
      tooltip: 'Change limits anytime, immediately',
    ),
    _TrustStatement(
      emoji: '✨',
      text: 'Inaction is intelligent.',
      tooltip: 'No trade is better than a bad trade',
    ),
    _TrustStatement(
      emoji: '🧠',
      text: 'AI learns from your feedback.',
      tooltip: 'System adapts to your preferences',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    // Rotate statements every 6 seconds
    Future.delayed(const Duration(seconds: 6), _rotateStatement);
  }

  void _rotateStatement() {
    if (!mounted) return;

    _fadeController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentStatementIndex =
              (_currentStatementIndex + 1) % _statements.length;
        });
        _fadeController.forward();
      }
    });

    Future.delayed(const Duration(seconds: 6), _rotateStatement);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statement = _statements[_currentStatementIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.6),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Main trust statement (animated)
          FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
            ),
            child: Tooltip(
              message: statement.tooltip,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    statement.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statement.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Status indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Statement counter
              Text(
                '${_currentStatementIndex + 1}/${_statements.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),

              // Live status
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.isAIActive
                          ? const Color(0xFF10B981)
                          : Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isAIActive ? 'Live' : 'Standby',
                    style: TextStyle(
                      color: widget.isAIActive
                          ? const Color(0xFF10B981)
                          : Colors.white.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Logged in status
              if (widget.userEmail != null)
                Text(
                  widget.userEmail!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),

          // Progress dots
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _statements.length,
              (index) => Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: index == _currentStatementIndex
                      ? const Color(0xFF3B82F6)
                      : Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustStatement {
  final String emoji;
  final String text;
  final String tooltip;

  _TrustStatement({
    required this.emoji,
    required this.text,
    required this.tooltip,
  });
}
