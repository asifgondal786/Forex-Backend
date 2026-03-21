import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:js_interop';
import '../../providers/chart_provider.dart';

@JS('renderTajirChart')
external void renderTajirChart(String json);

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});
  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final List<String> _pairs = ['EUR/USD', 'GBP/USD', 'USD/JPY'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChartProvider>().fetchCandles();
    });
  }

  void _renderChart(List<dynamic> candles) {
    renderTajirChart(jsonEncode(candles));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChartProvider>();

    if (!provider.isLoading && provider.candles.isNotEmpty) {
      final raw = provider.candles.map((c) => {
        'time': c.time,
        'open': c.open,
        'high': c.high,
        'low': c.low,
        'close': c.close,
      }).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) => _renderChart(raw));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Live Charts', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          DropdownButton<String>(
            value: provider.selectedPair,
            dropdownColor: const Color(0xFF161B22),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: _pairs.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (p) { if (p != null) context.read<ChartProvider>().selectPair(p); },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          if (provider.isLoading)
            const LinearProgressIndicator(color: Color(0xFF00D4AA)),
          if (provider.error != null)
            Container(
              color: Colors.red.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(8),
              child: Text(provider.error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: Stack(
              children: [
                const HtmlElementView(viewType: 'tajir-chart'),
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF00D4AA))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
