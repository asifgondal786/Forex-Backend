import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Slim banner rendered at the very top of [AppShell].
/// Polls the backend health endpoint every 10 seconds.
/// Shows automatically when the backend is unreachable and
/// dismisses itself as soon as connectivity is restored.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner>
    with SingleTickerProviderStateMixin {
  // Connection state
  _Status _status = _Status.checking;
  Timer? _pollTimer;

  // Smooth show/hide animation
  late final AnimationController _animCtrl;
  late final Animation<double> _heightAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // First check immediately, then poll every 10 s.
    _check();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final healthy = await ApiService.isHealthy();
      if (!mounted) return;
      _setStatus(healthy ? _Status.online : _Status.offline);
    } catch (_) {
      if (mounted) _setStatus(_Status.offline);
    }
  }

  void _setStatus(_Status next) {
    if (_status == next) return;
    setState(() => _status = next);

    // Show banner only when offline.
    if (next == _Status.offline) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // When fully online and animation is complete, render nothing at all
    // so the banner takes up zero space in the layout.
    return SizeTransition(
      sizeFactor: _heightAnim,
      axisAlignment: -1,
      child: _BannerContent(
        status: _status,
        onRetry: _check,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner content
// ─────────────────────────────────────────────────────────────────────────────

class _BannerContent extends StatelessWidget {
  final _Status status;
  final VoidCallback onRetry;

  const _BannerContent({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isOffline = status == _Status.offline;
    final isChecking = status == _Status.checking;

    final bgColor = isOffline ? const Color(0xFFB91C1C) : const Color(0xFF059669);
    final icon = isOffline
        ? Icons.cloud_off_rounded
        : isChecking
            ? Icons.cloud_sync_rounded
            : Icons.cloud_done_rounded;
    final message = isOffline
        ? 'Backend unreachable — working in offline mode'
        : isChecking
            ? 'Checking connection…'
            : 'Connected';

    return Material(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              // Icon / spinner
              if (isChecking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 16),

              const SizedBox(width: 10),

              // Message
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Retry button — only shown when offline
              if (isOffline)
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Status { checking, online, offline }

