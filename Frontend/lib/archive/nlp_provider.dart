import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Parsed result from the NLP backend.
class NlpResult {
  final String intent;        // OPEN_TRADE | CLOSE_TRADE | CHAT | UNKNOWN
  final String? pair;
  final String? direction;    // buy | sell
  final double? riskPct;
  final double? confidence;
  final String? response;     // AI plain-text reply
  final double? entryPrice;
  final double? stopLoss;
  final double? takeProfit;
  final String? reasoning;

  const NlpResult({
    required this.intent,
    this.pair,
    this.direction,
    this.riskPct,
    this.confidence,
    this.response,
    this.entryPrice,
    this.stopLoss,
    this.takeProfit,
    this.reasoning,
  });

  bool get isTradeIntent =>
      intent == 'OPEN_TRADE' &&
      pair != null &&
      direction != null &&
      entryPrice != null &&
      stopLoss != null &&
      takeProfit != null;

  factory NlpResult.fromJson(Map<String, dynamic> json) {
    return NlpResult(
      intent:     (json['intent'] as String? ?? 'UNKNOWN').toUpperCase(),
      pair:       json['pair'] as String?,
      direction:  json['direction'] as String?,
      riskPct:    (json['risk_pct'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      response:   json['response'] as String?,
      entryPrice: (json['entry_price'] as num?)?.toDouble(),
      stopLoss:   (json['stop_loss'] as num?)?.toDouble(),
      takeProfit: (json['take_profit'] as num?)?.toDouble(),
      reasoning:  json['reasoning'] as String?,
    );
  }

  factory NlpResult.fallback(String userText) => NlpResult(
        intent: 'CHAT',
        confidence: 0.0,
        response:
            "I couldn't understand that command. Try something like: \"Buy EUR/USD with 1% risk\"",
      );
}

class NlpService {
  final ApiService _api;

  NlpService(this._api);

  /// Sends user text to /api/v1/signals/nlp/parse and returns a typed result.
  Future<NlpResult> parse(String text, {double accountBalance = 10000.0}) async {
    try {
      final raw = await _api.parseNLPCommand(
        text: text.trim(),
        accountBalance: accountBalance,
      );
      return NlpResult.fromJson(raw);
    } catch (e) {
      debugPrint('NlpService.parse error: $e');
      return NlpResult.fallback(text);
    }
  }

  /// Executes a confirmed paper trade from an NlpResult.
  Future<Map<String, dynamic>> executePaperTrade({
    required NlpResult result,
    required String userId,
  }) async {
    if (!result.isTradeIntent) {
      throw ApiException('NlpResult is not a valid trade intent.');
    }
    return _api.openPaperTrade(
      userId:     userId,
      pair:       result.pair!,
      direction:  result.direction!,
      entryPrice: result.entryPrice!,
      stopLoss:   result.stopLoss!,
      takeProfit: result.takeProfit!,
      reasoning:  result.reasoning ?? 'NLP Copilot trade',
    );
  }
}

