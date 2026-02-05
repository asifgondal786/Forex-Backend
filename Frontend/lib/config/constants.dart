class AppConstants {
  // API Configuration
  static const String baseUrl = 'http://localhost:8000'; // Update with your backend URL
  static const String wsBaseUrl = 'ws://localhost:8000'; // WebSocket URL

  // API Endpoints
  static const String apiAuth = '/api/auth';
  static const String apiTrades = '/api/trades';
  static const String apiAccount = '/api/account';
  static const String apiMarketData = '/api/market-data';
  static const String apiAiPredictions = '/api/ai/predictions';
  static const String apiAiTasks = '/api/ai/tasks';

  // WebSocket Endpoints
  static const String wsMarketData = '/ws/market-data';
  static const String wsAiUpdates = '/ws/ai-updates';

  // App Info
  static const String appName = 'Forex Companion';
  static const String appTagline = 'U Sleep, I Work for U';
  static const String appVersion = '1.0.0';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardPadding = 20.0;
  static const double borderRadius = 16.0;
  static const double smallBorderRadius = 8.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // Currency Pairs
  static const List<String> currencyPairs = [
    'EUR/USD',
    'GBP/USD',
    'USD/JPY',
    'USD/CHF',
    'AUD/USD',
    'USD/CAD',
    'NZD/USD',
  ];

  // Timeframes
  static const List<String> timeframes = [
    '1M',
    '5M',
    '15M',
    '30M',
    '1H',
    '4H',
    '1D',
    '1W',
  ];

  // Trade Types
  static const String tradeBuy = 'BUY';
  static const String tradeSell = 'SELL';

  // AI Confidence Levels
  static const double highConfidence = 75.0;
  static const double mediumConfidence = 50.0;
  static const double lowConfidence = 25.0;

  // Chart Colors
  static const String chartBullishColor = '#00FF88';
  static const String chartBearishColor = '#FF3B30';
  static const String chartGridColor = '#2A3F5F';
}
