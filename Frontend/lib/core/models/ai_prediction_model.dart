class AiPredictionModel {
  final String id;
  final String currencyPair;
  final String action; // 'BUY' or 'SELL'
  final double targetPrice;
  final double confidence;
  final String timeframe;
  final String status; // 'active', 'completed', 'cancelled'
  final DateTime createdAt;
  final String reasoning;
  final List<String> indicators;
  final double? profitLoss;

  AiPredictionModel({
    required this.id,
    required this.currencyPair,
    required this.action,
    required this.targetPrice,
    required this.confidence,
    required this.timeframe,
    required this.status,
    required this.createdAt,
    required this.reasoning,
    required this.indicators,
    this.profitLoss,
  });

  factory AiPredictionModel.fromJson(Map<String, dynamic> json) {
    return AiPredictionModel(
      id: json['id'] ?? '',
      currencyPair: json['currency_pair'] ?? '',
      action: json['action'] ?? 'BUY',
      targetPrice: (json['target_price'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
      timeframe: json['timeframe'] ?? '1H',
      status: json['status'] ?? 'active',
      createdAt:
          DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      reasoning: json['reasoning'] ?? '',
      indicators: List<String>.from(json['indicators'] ?? []),
      profitLoss:
          json['profit_loss'] != null ? (json['profit_loss'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'currency_pair': currencyPair,
      'action': action,
      'target_price': targetPrice,
      'confidence': confidence,
      'timeframe': timeframe,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'reasoning': reasoning,
      'indicators': indicators,
      'profit_loss': profitLoss,
    };
  }

  String get confidenceLevel {
    if (confidence >= 75) return 'High';
    if (confidence >= 50) return 'Medium';
    return 'Low';
  }

  bool get isBullish => action.toUpperCase() == 'BUY';
}
