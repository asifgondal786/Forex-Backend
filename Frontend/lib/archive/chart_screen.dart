import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../../providers/chart_provider.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});
  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final List<String> _pairs = ['EUR/USD', 'GBP/USD', 'USD/JPY'];
  static bool _viewRegistered = false;
  web.HTMLIFrameElement? _iframe;
  bool _iframeReady = false;
  List<dynamic>? _pendingCandles;

  @override
  void initState() {
    super.initState();
    _registerIframe();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChartProvider>().fetchCandles();
    });
  }

  void _registerIframe() {
    if (_viewRegistered) return;
    _viewRegistered = true;
    _iframe = web.HTMLIFrameElement()
      ..id = 'tajir-chart-iframe'
      ..srcdoc = _chartHtml().toJS
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.backgroundColor = '#0D1117';

    // Listen for ready signal from iframe
    web.window.addEventListener('message', ((web.MessageEvent e) {
      if (e.data.toString() == 'CHART_READY') {
        _iframeReady = true;
        if (_pendingCandles != null) {
          _postCandles(_pendingCandles!);
          _pendingCandles = null;
        }
      }
    }).toJS);

    ui_web.platformViewRegistry.registerViewFactory(
      'tajir-chart',
      (int viewId) => _iframe!,
    );
  }

  String _chartHtml() {
    return '''<!DOCTYPE html>
<html>
<head>
<style>
  body { margin:0; background:#0D1117; overflow:hidden; }
  #chart { width:100vw; height:100vh; }
</style>
<script src="https://unpkg.com/lightweight-charts@3.3.0/dist/lightweight-charts.standalone.production.js"></script>
</head>
<body>
<div id="chart"></div>
<script>
  var chart = LightweightCharts.createChart(document.getElementById("chart"), {
    width: window.innerWidth, height: window.innerHeight,
    layout: { background: { color: "#0D1117" }, textColor: "#C9D1D9" },
    grid: { vertLines: { color: "#21262D" }, horzLines: { color: "#21262D" } },
    rightPriceScale: { borderColor: "#30363D" },
    timeScale: { borderColor: "#30363D", timeVisible: true },
  });
  var series = chart.addCandlestickSeries({
    upColor: "#00D4AA", downColor: "#FF4B4B",
    borderUpColor: "#00D4AA", borderDownColor: "#FF4B4B",
    wickUpColor: "#00D4AA", wickDownColor: "#FF4B4B",
  });
  window.addEventListener("resize", function() {
    chart.applyOptions({ width: window.innerWidth, height: window.innerHeight });
  });
  window.addEventListener("message", function(e) {
    if (e.data && e.data.type === "RENDER_CHART") {
      series.setData(e.data.candles);
    }
  });
  // Signal parent that chart is ready
  window.parent.postMessage("CHART_READY", "*");
</script>
</body>
</html>''';
  }

  void _postCandles(List<dynamic> candles) {
    final msg = '{"type":"RENDER_CHART","candles":${jsonEncode(candles)}}';
    _iframe?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
  }

  void _renderChart(List<dynamic> candles) {
    if (_iframeReady) {
      _postCandles(candles);
    } else {
      _pendingCandles = candles;
      // Fallback: force send after 2s if CHART_READY never fires
      Timer(const Duration(seconds: 2), () {
        if (_pendingCandles != null) {
          _postCandles(_pendingCandles!);
          _pendingCandles = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChartProvider>();

    if (!provider.isLoading && provider.candles.isNotEmpty) {
      final raw = provider.candles.map((c) => {
        'time': c.time, 'open': c.open,
        'high': c.high, 'low': c.low, 'close': c.close,
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
          const Expanded(
            child: HtmlElementView(viewType: 'tajir-chart'),
          ),
        ],
      ),
    );
  }
}



