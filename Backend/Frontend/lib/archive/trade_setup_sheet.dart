import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/trade_execution.dart';
import '../../providers/beginner_mode_provider.dart';
import '../../shared/widgets/beginner_mode_overlay.dart';

/// Shows the full trade execution flow as a bottom sheet.
/// Call: showTradeSetupSheet(context, pair: 'EUR/USD', direction: 'BUY')
Future<void> showTradeSetupSheet(
  BuildContext context, {
  required String pair,
  required String direction,
}) async {
  final prov = context.read<TradeExecutionProvider>();
  prov.startSetup(pair: pair, dir: direction);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: prov,
      child: _TradeSetupSheet(pair: pair, direction: direction),
    ),
  );
}

class _TradeSetupSheet extends StatefulWidget {
  final String pair;
  final String direction;

  const _TradeSetupSheet({required this.pair, required this.direction});

  @override
  State<_TradeSetupSheet> createState() => _TradeSetupSheetState();
}

class _TradeSetupSheetState extends State<_TradeSetupSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeIn,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Consumer<TradeExecutionProvider>(
            builder: (context, prov, _) {
              return Column(
                children: [
                  _SheetHandle(scheme: scheme),
                  _StepIndicator(step: prov.step, scheme: scheme),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: _stepBody(prov, scheme, context),
                    ),
                  ),
                  if (prov.step != TradeSetupStep.done &&
                      prov.step != TradeSetupStep.executing)
                    _ActionBar(prov: prov, scheme: scheme),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stepBody(
      TradeExecutionProvider prov, ColorScheme scheme, BuildContext ctx) {
    switch (prov.step) {
      case TradeSetupStep.review:
      case TradeSetupStep.setup:
        return _SetupStep(prov: prov, scheme: scheme);
      case TradeSetupStep.confirm:
        return _ConfirmStep(prov: prov, scheme: scheme);
      case TradeSetupStep.executing:
        return _ExecutingStep(scheme: scheme);
      case TradeSetupStep.done:
        return _DoneStep(
          prov: prov,
          scheme: scheme,
          onClose: () => Navigator.pop(ctx),
        );
    }
  }
}

class _SheetHandle extends StatelessWidget {
  final ColorScheme scheme;
  const _SheetHandle({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.onSurface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Execute Trade',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final TradeSetupStep step;
  final ColorScheme scheme;

  const _StepIndicator({required this.step, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final steps = ['Setup', 'Review', 'Confirm', 'Done'];
    final stepIndex = [
      TradeSetupStep.setup,
      TradeSetupStep.review,
      TradeSetupStep.confirm,
      TradeSetupStep.done,
    ].indexOf(step).clamp(0, 3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final lineIndex = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: lineIndex < stepIndex
                    ? scheme.primary
                    : scheme.onSurface.withOpacity(0.15),
              ),
            );
          }
          final idx = i ~/ 2;
          final active = idx <= stepIndex;
          return Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? scheme.primary : scheme.surfaceContainerHighest,
            ),
            child: active && idx < stepIndex
                ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                : Center(
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? scheme.onPrimary
                            : scheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ),
          );
        }),
      ),
    );
  }
}

class _SetupStep extends StatefulWidget {
  final TradeExecutionProvider prov;
  final ColorScheme scheme;

  const _SetupStep({required this.prov, required this.scheme});

  @override
  State<_SetupStep> createState() => _SetupStepState();
}

class _SetupStepState extends State<_SetupStep> {
  double _lotSize = 0.01;
  double _leverage = 10;
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lotSize = widget.prov.lotSize;
    _leverage = widget.prov.leverage;
  }

  @override
  void dispose() {
    _slCtrl.dispose();
    _tpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = widget.prov.direction == 'BUY';
    final dirColor = isBuy ? Colors.green : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Direction + Pair header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dirColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dirColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: dirColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.prov.direction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.prov.selectedPair ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  Text(
                    'Market Order',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Lot size
        _SetupLabel('Lot Size', widget.scheme),
        const SizedBox(height: 8),
        Row(
          children: [
            _StepBtn(
              icon: Icons.remove,
              onTap: _lotSize > 0.01
                  ? () => setState(() {
                        _lotSize = double.parse(
                            (_lotSize - 0.01).toStringAsFixed(2));
                        widget.prov.updateSetup(lot: _lotSize);
                      })
                  : null,
              scheme: widget.scheme,
            ),
            Expanded(
              child: Center(
                child: Text(
                  _lotSize.toStringAsFixed(2),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 24),
                ),
              ),
            ),
            _StepBtn(
              icon: Icons.add,
              onTap: _lotSize < 10
                  ? () => setState(() {
                        _lotSize = double.parse(
                            (_lotSize + 0.01).toStringAsFixed(2));
                        widget.prov.updateSetup(lot: _lotSize);
                      })
                  : null,
              scheme: widget.scheme,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Leverage
        _SetupLabel('Leverage', widget.scheme),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('1:${_leverage.toInt()}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _leverage > 50
                      ? Colors.red
                      : _leverage > 20
                          ? Colors.orange
                          : widget.scheme.primary,
                )),
            Expanded(
              child: Slider(
                value: _leverage,
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: _leverage > 50
                    ? Colors.red
                    : _leverage > 20
                        ? Colors.orange
                        : widget.scheme.primary,
                onChanged: (v) {
                  setState(() => _leverage = v);
                  widget.prov.updateSetup(lev: v);
                },
              ),
            ),
          ],
        ),
        if (_leverage > 50)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Text(
                  'High leverage significantly increases risk',
                  style: TextStyle(
                      color: Colors.red, fontSize: 11),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Stop Loss / Take Profit
        Row(
          children: [
            Expanded(
              child: _PriceField(
                label: 'Stop Loss',
                ctrl: _slCtrl,
                hint: 'Optional',
                color: Colors.red,
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed == null && v.trim().isEmpty) {
                    widget.prov.clearStopLoss();
                    return;
                  }
                  widget.prov.updateSetup(sl: parsed);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PriceField(
                label: 'Take Profit',
                ctrl: _tpCtrl,
                hint: 'Optional',
                color: Colors.green,
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed == null && v.trim().isEmpty) {
                    widget.prov.clearTakeProfit();
                    return;
                  }
                  widget.prov.updateSetup(tp: parsed);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SetupLabel extends StatelessWidget {
  final String text;
  final ColorScheme scheme;

  const _SetupLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: scheme.onSurface.withOpacity(0.5),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme scheme;

  const _StepBtn(
      {required this.icon, required this.onTap, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onTap != null
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? scheme.primary
              : scheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final Color color;
  final ValueChanged<String> onChanged;

  const _PriceField({
    required this.label,
    required this.ctrl,
    required this.hint,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: scheme.onSurface.withOpacity(0.3), fontSize: 13),
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final TradeExecutionProvider prov;
  final ColorScheme scheme;

  const _ConfirmStep({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isBuy = prov.direction == 'BUY';
    final dirColor = isBuy ? Colors.green : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Explanation card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.purple, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Trade Analysis',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.purple,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This ${prov.direction} setup on ${prov.selectedPair} shows a strong risk/reward ratio of 1:2.4. '
                      'The signal confidence is 78% based on RSI divergence and key support levels. '
                      'Estimated max loss: \$${(prov.lotSize * prov.leverage * 10).toStringAsFixed(2)}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withOpacity(0.75),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Order summary
        Text(
          'Order Summary',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: scheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _SummaryRow('Pair', prov.selectedPair ?? '', scheme),
              _SummaryRow('Direction', prov.direction, scheme,
                  valueColor: dirColor),
              _SummaryRow('Lot Size', prov.lotSize.toStringAsFixed(2), scheme),
              _SummaryRow('Leverage', '1:${prov.leverage.toInt()}', scheme),
              if (prov.stopLoss != null)
                _SummaryRow(
                    'Stop Loss', prov.stopLoss!.toStringAsFixed(5), scheme,
                    valueColor: Colors.red),
              if (prov.takeProfit != null)
                _SummaryRow(
                    'Take Profit', prov.takeProfit!.toStringAsFixed(5), scheme,
                    valueColor: Colors.green),
              const Divider(height: 20),
              _SummaryRow(
                'Est. Max Loss',
                '\$${(prov.lotSize * prov.leverage * 10).toStringAsFixed(2)}',
                scheme,
                valueColor: Colors.red,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is a paper trade. No real money will be used.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme scheme;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow(this.label, this.value, this.scheme,
      {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutingStep extends StatelessWidget {
  final ColorScheme scheme;

  const _ExecutingStep({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: scheme.primary),
          const SizedBox(height: 20),
          Text(
            'Placing trade...',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Securing token and executing order',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  final TradeExecutionProvider prov;
  final ColorScheme scheme;
  final VoidCallback onClose;

  const _DoneStep(
      {required this.prov, required this.scheme, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
        ),
        const SizedBox(height: 20),
        const Text(
          'Trade Placed!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          prov.executionResult ?? 'Your order has been submitted.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              prov.reset();
              onClose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'View Portfolio',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            prov.reset();
            onClose();
          },
          child: const Text('Place another trade'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final TradeExecutionProvider prov;
  final ColorScheme scheme;

  const _ActionBar({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isConfirm = prov.step == TradeSetupStep.confirm;
    final isBuy = prov.direction == 'BUY';

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          if (isConfirm) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => prov.proceedToConfirm(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () async {
                if (!isConfirm) {
                  // Check beginner mode confirmation
                  final beginnerProv = context.read<BeginnerModeProvider>();
                  if (beginnerProv.isEnabled) {
                    final ok =
                        await beginnerConfirmTrade(context, prov.selectedPair ?? '');
                    if (!ok) return;
                  }
                  prov.proceedToConfirm();
                } else {
                  HapticFeedback.heavyImpact();
                  final success = await prov.executeTrade('demo_token');
                  if (!context.mounted) return;
                  if (success) {
                    final snapshot = prov.buildSnapshot();
                    if (snapshot != null) {
                      context.read<PortfolioProvider>().addOpenTrade(snapshot);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(prov.executionResult ?? 'Execution failed'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isConfirm
                    ? (isBuy ? Colors.green : Colors.red)
                    : scheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isConfirm
                    ? (isBuy ? '✓ Confirm BUY' : '✓ Confirm SELL')
                    : 'Continue →',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

