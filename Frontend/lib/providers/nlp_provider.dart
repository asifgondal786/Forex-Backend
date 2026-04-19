import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/nlp_service.dart';

enum NlpConversationStage {
  idle,
  parsing,
  confirmed,
  executing,
  done,
  error,
}

class NlpMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const NlpMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class NlpProvider extends ChangeNotifier {
  final ApiService _apiService;
  late final NlpService _nlpService;

  NlpConversationStage _stage = NlpConversationStage.idle;
  final List<NlpMessage> _messages = [];
  bool _isLoading = false;
  NlpResult? _pendingTrade;
  double _accountBalance;
  String _userId;

  NlpProvider({
    ApiService? apiService,
    double accountBalance = 10000.0,
    String userId = 'demo_user',
  })  : _apiService = apiService ?? ApiService(),
        _accountBalance = accountBalance,
        _userId = userId {
    _nlpService = NlpService(_apiService);
  }

  List<NlpMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  NlpConversationStage get stage => _stage;

  void updateContext({double? accountBalance, String? userId}) {
    if (accountBalance != null) {
      _accountBalance = accountBalance;
    }
    if (userId != null && userId.trim().isNotEmpty) {
      _userId = userId.trim();
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _messages.add(
      NlpMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    _isLoading = true;
    _stage = NlpConversationStage.parsing;
    notifyListeners();

    try {
      final result = await _nlpService.parse(
        trimmed,
        accountBalance: _accountBalance,
      );

      if (result.isTradeIntent) {
        _pendingTrade = result;
        _messages.add(
          NlpMessage(
            text: _buildTradePrompt(result),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _stage = NlpConversationStage.confirmed;
      } else {
        _pendingTrade = null;
        _messages.add(
          NlpMessage(
            text: result.response ?? _fallbackAssistantReply(trimmed),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _stage = NlpConversationStage.idle;
      }
    } catch (e) {
      _pendingTrade = null;
      _messages.add(
        NlpMessage(
          text: 'I could not process that request right now.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _stage = NlpConversationStage.error;
      debugPrint('NlpProvider.sendMessage error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void confirmTrade() {
    _confirmTrade();
  }

  Future<void> _confirmTrade() async {
    final pendingTrade = _pendingTrade;
    if (pendingTrade == null || _isLoading) return;

    _isLoading = true;
    _stage = NlpConversationStage.executing;
    notifyListeners();

    try {
      final result = await _nlpService.executePaperTrade(
        result: pendingTrade,
        userId: _userId,
      );
      final trade = result['trade'];
      final orderId = trade is Map<String, dynamic>
          ? (trade['id']?.toString() ?? 'pending')
          : 'pending';

      _messages.add(
        NlpMessage(
          text:
              'Trade executed for ${pendingTrade.pair} ${pendingTrade.direction?.toUpperCase() ?? ''}. '
              'Order ID: $orderId.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _pendingTrade = null;
      _stage = NlpConversationStage.done;
    } catch (e) {
      _messages.add(
        NlpMessage(
          text: 'Trade execution failed. Please review the setup and try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _stage = NlpConversationStage.error;
      debugPrint('NlpProvider.confirmTrade error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void rejectTrade() {
    if (_pendingTrade == null) return;
    _pendingTrade = null;
    _stage = NlpConversationStage.idle;
    _messages.add(
      NlpMessage(
        text: 'Trade cancelled.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void clearConversation() {
    _messages.clear();
    _pendingTrade = null;
    _stage = NlpConversationStage.idle;
    notifyListeners();
  }

  String _buildTradePrompt(NlpResult result) {
    final direction = result.direction?.toUpperCase() ?? 'TRADE';
    final pair = result.pair ?? 'the selected pair';
    final risk = result.riskPct != null ? ' Risk: ${result.riskPct}%.' : '';
    final analysis = result.response ?? result.reasoning ?? 'Review and confirm.';
    return 'Ready to $direction $pair.$risk\n\n$analysis';
  }

  String _fallbackAssistantReply(String text) {
    return 'I understood "$text", but I do not have a structured action for it yet.';
  }
}

