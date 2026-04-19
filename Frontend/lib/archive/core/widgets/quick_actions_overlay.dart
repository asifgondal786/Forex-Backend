// lib/core/widgets/quick_actions_overlay.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/quick_actions_provider.dart';

// -- colours (shared palette) -------------------------------------------------
// const _kBg      = Color(0xFF0A0E1A);
const _kCard    = Color(0xFF161D2E);
// const _kBorder  = Color(0xFF1E2A3D);
const _kGold    = Color(0xFFD4A853);
// const _kText    = Color(0xFFE2E8F0);
const _kSubtext = Color(0xFF64748B);

/// Drop this widget at the top of any mode screen's scroll view.
///
/// [modeKey]     — matches keys in _kActionsByMode (e.g. 'marketWatch')
/// [onAction]    — callback with the action's routeOrAction string
/// [accentColor] — tint colour for this mode's card border + icon ring
class QuickActionsOverlay extends StatefulWidget {
  const QuickActionsOverlay({
    super.key,
    required this.modeKey,
    required this.onAction,
    this.accentColor = _kGold,
    this.title = 'Quick Actions',
  });

  final String modeKey;
  final void Function(QuickAction action) onAction;
  final Color accentColor;
  final String title;

  @override
  State<QuickActionsOverlay> createState() => _QuickActionsOverlayState();
}

class _QuickActionsOverlayState extends State<QuickActionsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim =
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _slideCtrl.reverse().then((_) {
      if (mounted) {
        context.read<QuickActionsProvider>().dismiss(widget.modeKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuickActionsProvider>(
      builder: (ctx, provider, _) {
        if (!provider.isVisible(widget.modeKey)) {
          return const SizedBox.shrink();
        }
        final actions = provider.actionsFor(widget.modeKey);
        if (actions.isEmpty) return const SizedBox.shrink();

        return SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.25),
                    width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Header -----------------------------------------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
                    child: Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: widget.accentColor,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
                      // Dismiss
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded,
                              color: _kSubtext, size: 14),
                        ),
                      ),
                    ]),
                  ),
                  // -- Action cards row --------------------------------
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: actions.length,
                      itemBuilder: (_, i) => _ActionCard(
                        action: actions[i],
                        accentColor: widget.accentColor,
                        onTap: () => widget.onAction(actions[i]),
                      ),
                    ),
                  ),
                  // -- Hint --------------------------------------------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(children: [
                      Icon(Icons.touch_app_rounded,
                          color: _kSubtext, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'Tap a card to jump straight in  •  × to hide',
                        style: const TextStyle(
                            color: _kSubtext, fontSize: 9),
                      ),
                    ]),
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

// -----------------------------------------------------------------------------
// Individual action card
// -----------------------------------------------------------------------------
class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.action,
    required this.accentColor,
    required this.onTap,
  });
  final QuickAction action;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100),
        lowerBound: 0.93, upperBound: 1.0, value: 1.0);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) {
        _pressCtrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.forward(),
      child: ScaleTransition(
        scale: _pressCtrl,
        child: Container(
          width: 130,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.2)),
          ),
          child: ClipRect(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // emoji icon in a ring
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(widget.action.icon,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                widget.action.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kSubtext,
                  fontSize: 9,
                  height: 1.3,
                ),
              ),
            ],
          )),
        ),
      ),
    );
  }
}

