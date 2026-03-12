import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/mode_provider.dart';
import '../../routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  AppMode? _selectedMode;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  static const List<_ModeOption> _modes = [
    _ModeOption(
      mode: AppMode.marketWatch,
      icon: Icons.candlestick_chart_rounded,
      label: 'Market Watch',
      description: 'Live Forex prices, pair movements & rate feeds in real time.',
      color: Color(0xFF00C896),
      available: true,
    ),
    _ModeOption(
      mode: AppMode.aiChat,
      icon: Icons.chat_bubble_rounded,
      label: 'AI Chat',
      description: 'Ask anything about Forex – raw, direct answers from Gemini AI.',
      color: Color(0xFF6C63FF),
      available: true,
    ),
    _ModeOption(
      mode: AppMode.aiCopilot,
      icon: Icons.auto_awesome_rounded,
      label: 'AI Copilot',
      description: 'Step-by-step guided trading assistant built for beginners.',
      color: Color(0xFF3DB9FF),
      available: true,
    ),
    _ModeOption(
      mode: AppMode.tradeSignals,
      icon: Icons.trending_up_rounded,
      label: 'Trade Signals',
      description: 'AI-generated buy/sell recommendations with confidence scores.',
      color: Color(0xFFFF8C42),
      available: true,
    ),
    _ModeOption(
      mode: AppMode.newsEvents,
      icon: Icons.newspaper_rounded,
      label: 'News & Events',
      description: 'Market sentiment, economic calendar & news that moves prices.',
      color: Color(0xFFFF4F7B),
      available: true,
    ),
    _ModeOption(
      mode: AppMode.customSetup,
      icon: Icons.tune_rounded,
      label: 'Custom Setup',
      description: 'Configure your own dashboard – pick what matters to you.',
      color: Color(0xFFB8860B),
      available: true,
    ),
  ];

  void _onConfirm() {
    if (_selectedMode == null) return;
    context.read<ModeProvider>().setMode(_selectedMode!);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  Future<void> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text('Exit App?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Please select a mode to continue using Tajir.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay', style: TextStyle(color: Color(0xFF00C896))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (shouldExit == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F7FA),
        body: FadeTransition(
          opacity: _fadeIn,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),
                _buildHeader(),
                const SizedBox(height: 28),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _modes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ModeCard(
                      option: _modes[i],
                      selected: _selectedMode == _modes[i].mode,
                      onTap: () => setState(() => _selectedMode = _modes[i].mode),
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C896), Color(0xFF6C63FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.currency_exchange, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome to Tajir',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'How would you like to start?\nYou can change this anytime in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final ready = _selectedMode != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: AnimatedOpacity(
        opacity: ready ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 250),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: ready ? _onConfirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C896),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              ready
                  ? 'Start with ${_modes.firstWhere((m) => m.mode == _selectedMode).label}'
                  : 'Select a mode to continue',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final _ModeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? option.color.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? const Color(0xFF181B22) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? option.color : Colors.transparent, width: 1.8),
          boxShadow: selected
              ? [BoxShadow(color: option.color.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon, color: option.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? option.color : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.description,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? option.color : Colors.transparent,
                border: Border.all(color: selected ? option.color : Colors.grey.shade400, width: 2),
              ),
              child: selected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption {
  final AppMode mode;
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool available;

  const _ModeOption({
    required this.mode,
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.available,
  });
}
