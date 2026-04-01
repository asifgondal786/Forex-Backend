import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/automation_provider.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AutomationProvider>().loadLog('demo_token');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Text(
          'Automation',
          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
      ),
      body: Consumer<AutomationProvider>(
        builder: (context, prov, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('Trading Mode', scheme),
              const SizedBox(height: 10),
              _ModeSelector(prov: prov, scheme: scheme),
              const SizedBox(height: 24),
              _SectionLabel('Risk Guardrails', scheme),
              const SizedBox(height: 10),
              _GuardrailsCard(prov: prov, scheme: scheme),
              const SizedBox(height: 24),
              _SectionLabel('Auto-Follow Settings', scheme),
              const SizedBox(height: 10),
              _AutoFollowCard(prov: prov, scheme: scheme),
              const SizedBox(height: 24),
              _SectionLabel('Execution Log', scheme),
              const SizedBox(height: 10),
              _ExecutionLog(prov: prov, scheme: scheme),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme scheme;

  const _SectionLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: scheme.onSurface.withOpacity(0.5),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final AutomationProvider prov;
  final ColorScheme scheme;

  const _ModeSelector({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final modes = [
      _ModeInfo(
        mode: AutoMode.manual,
        icon: Icons.touch_app_rounded,
        label: 'Manual',
        desc: 'You decide everything. No automation.',
        color: Colors.grey,
      ),
      _ModeInfo(
        mode: AutoMode.assisted,
        icon: Icons.assistant_rounded,
        label: 'Assisted',
        desc: 'AI suggests. You approve each trade.',
        color: Colors.blue,
      ),
      _ModeInfo(
        mode: AutoMode.semiAuto,
        icon: Icons.settings_suggest_rounded,
        label: 'Semi-Auto',
        desc: 'Auto-executes within your guardrails.',
        color: Colors.orange,
      ),
      _ModeInfo(
        mode: AutoMode.fullyAuto,
        icon: Icons.smart_toy_rounded,
        label: 'Fully Auto',
        desc: 'AI trades autonomously 24/7.',
        color: Colors.green,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: modes.map((m) {
        final selected = prov.mode == m.mode;
        return GestureDetector(
          onTap: () => prov.setMode(m.mode, 'demo_token'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? m.color.withOpacity(0.15)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? m.color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(m.icon,
                    color: selected ? m.color : scheme.onSurface.withOpacity(0.4),
                    size: 22),
                const Spacer(),
                Text(
                  m.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: selected ? m.color : scheme.onSurface,
                  ),
                ),
                Text(
                  m.desc,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurface.withOpacity(0.5),
                    height: 1.3,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModeInfo {
  final AutoMode mode;
  final IconData icon;
  final String label;
  final String desc;
  final Color color;

  const _ModeInfo({
    required this.mode,
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
  });
}

class _GuardrailsCard extends StatelessWidget {
  final AutomationProvider prov;
  final ColorScheme scheme;

  const _GuardrailsCard({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _SliderRow(
            label: 'Max Drawdown',
            value: prov.maxDrawdown,
            min: 1,
            max: 50,
            suffix: '%',
            color: Colors.orange,
            onChanged: prov.setMaxDrawdown,
            scheme: scheme,
          ),
          const Divider(height: 24),
          _SliderRow(
            label: 'Daily Loss Cap',
            value: prov.dailyLossCap,
            min: 10,
            max: 1000,
            suffix: '\$',
            prefix: true,
            color: Colors.red,
            onChanged: prov.setDailyLossCap,
            scheme: scheme,
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Max Open Trades',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: prov.maxOpenTrades > 1
                        ? () => prov.setMaxOpenTrades(prov.maxOpenTrades - 1)
                        : null,
                    color: scheme.primary,
                    iconSize: 20,
                  ),
                  Text(
                    '${prov.maxOpenTrades}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: prov.maxOpenTrades < 20
                        ? () => prov.setMaxOpenTrades(prov.maxOpenTrades + 1)
                        : null,
                    color: scheme.primary,
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final bool prefix;
  final Color color;
  final ValueChanged<double> onChanged;
  final ColorScheme scheme;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    this.prefix = false,
    required this.color,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final display = prefix
        ? '$suffix${value.toStringAsFixed(0)}'
        : '${value.toStringAsFixed(0)}$suffix';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: scheme.onSurface)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                display,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: color,
          inactiveColor: color.withOpacity(0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AutoFollowCard extends StatelessWidget {
  final AutomationProvider prov;
  final ColorScheme scheme;

  const _AutoFollowCard({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _ToggleRow(
            label: 'Auto-Follow Traders',
            subtitle: 'Automatically copy trades from followed traders',
            value: prov.autoFollowEnabled,
            onChanged: prov.setAutoFollow,
            scheme: scheme,
          ),
          const Divider(height: 20),
          _ToggleRow(
            label: 'Show AI Reasoning',
            subtitle: 'Display AI explanation before each auto-execution',
            value: prov.showAiReasoning,
            onChanged: prov.setShowAiReasoning,
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme scheme;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: scheme.primary,
        ),
      ],
    );
  }
}

class _ExecutionLog extends StatelessWidget {
  final AutomationProvider prov;
  final ColorScheme scheme;

  const _ExecutionLog({required this.prov, required this.scheme});

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (prov.log.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No automation activity yet.',
            style: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: prov.log.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: scheme.outline.withOpacity(0.1),
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, i) {
          final entry = prov.log[i];
          final isPositive = entry.result.contains('+');
          final isBlocked = entry.result.contains('Blocked');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? Colors.orange
                        : isPositive
                            ? Colors.green
                            : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.pair} • ${entry.action}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        entry.result,
                        style: TextStyle(
                          fontSize: 12,
                          color: isBlocked
                              ? Colors.orange
                              : isPositive
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(entry.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
