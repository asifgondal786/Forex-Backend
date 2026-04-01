import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

class TajirBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const TajirBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = context.watch<NotificationProvider>().unreadCount;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                onTap: onTap,
                scheme: scheme,
              ),
              _NavItem(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.candlestick_chart_outlined,
                activeIcon: Icons.candlestick_chart_rounded,
                label: 'Markets',
                onTap: onTap,
                scheme: scheme,
              ),
              _NavItem(
                index: 2,
                currentIndex: currentIndex,
                icon: Icons.trending_up_outlined,
                activeIcon: Icons.trending_up_rounded,
                label: 'Trade',
                onTap: onTap,
                scheme: scheme,
              ),
              _NavItem(
                index: 3,
                currentIndex: currentIndex,
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: 'Portfolio',
                onTap: onTap,
                scheme: scheme,
              ),
              _NavItem(
                index: 4,
                currentIndex: currentIndex,
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'More',
                badge: unread > 0 ? unread : null,
                onTap: onTap,
                scheme: scheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;
  final ValueChanged<int> onTap;
  final ColorScheme scheme;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    selected ? activeIcon : icon,
                    key: ValueKey(selected),
                    color: selected
                        ? scheme.primary
                        : scheme.onSurface.withOpacity(0.4),
                    size: 24,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withOpacity(0.4),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
