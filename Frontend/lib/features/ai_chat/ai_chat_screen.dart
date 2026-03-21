// lib/features/ai_chat/ai_chat_screen.dart
// Phase 7 - NLP Voice Copilot
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/gemini_service.dart';
import '../../services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/quick_actions_overlay.dart';
import '../../providers/quick_actions_provider.dart';
import '../../providers/paper_trading_provider.dart';
import '../../providers/trade_signals_provider.dart';

// ── Web Speech API via JS interop ─────────────────────────────────────────────
@JS('window.startSpeechRecognition')
external JSPromise<JSString> _startSpeechRecognitionJS();

@JS('window.isSpeechSupported')
external JSBoolean _isSpeechSupportedJS();

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _voiceSupported = false;
  late AnimationController _pulseCtrl;

  static const List<String> _suggestions = [
    '📈 EUR/USD analysis today',
    '💡 Explain pip value',
    '🔍 Best pairs for beginners?',
    '📰 Latest market news',
    '⚠️ What is a stop loss?',
    '🕐 Best trading hours?',
  ];

  static const _quickPrompts = {
    'prompt_analyse': 'Analyse my watched currency pairs and tell me which looks best right now.',
    'prompt_explain': 'Explain the latest trade signal to me in simple terms.',
    'prompt_risk':    'How much risk am I currently taking across my open trades?',
    'prompt_news':    'Summarise the biggest market-moving news from the last 2 hours.',
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _addMessage(_timeBasedGreeting(), isUser: false);
    _checkVoiceSupport();
  }

  void _checkVoiceSupport() {
    try {
      _voiceSupported = _isSpeechSupportedJS().toDart;
    } catch (_) {
      _voiceSupported = false;
    }
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    final sal = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon'
        : hour < 21 ? 'Good Evening' : 'Welcome Back';
    return '$sal! 👋 I\'m your Forex AI Copilot.\n\n'
        'Ask me anything — or tap 🎙️ to use voice commands like:\n'
        '• "Buy EUR/USD with 1% risk"\n'
        '• "Show me GBP/USD signals"\n'
        '• "What\'s my performance today?"';
  }

  void _addMessage(String text, {required bool isUser, String? intent, bool isCommand = false}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text, isUser: isUser, timestamp: DateTime.now(),
        intent: intent, isCommand: isCommand,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Voice input ───────────────────────────────────────────────────────────
  Future<void> _startVoice() async {
    if (_isListening || !_voiceSupported) {
      if (!_voiceSupported) {
        _addMessage('🎙️ Voice not supported in this browser. Try Chrome or Edge.', isUser: false);
      }
      return;
    }
    setState(() => _isListening = true);
    HapticFeedback.mediumImpact();
    try {
      final result = await _startSpeechRecognitionJS().toDart;
      final text = result.toDart.trim();
      if (text.isNotEmpty) {
        _addMessage('🎙️ "$text"', isUser: true, isCommand: true);
        await _handleVoiceCommand(text);
      }
    } catch (e) {
      _addMessage('🎙️ Could not hear clearly. Please try again.', isUser: false);
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  // ── NLP command handler ───────────────────────────────────────────────────
  Future<void> _handleVoiceCommand(String text) async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final paperProvider = context.read<PaperTradingProvider>();
      final parsed = await api.parseNLPCommand(
        text: text,
        accountBalance: paperProvider.stats.totalPnl + 10000,
      );

      final intent   = parsed['intent'] as String? ?? 'CHAT';
      final response = parsed['response'] as String?;
      final requiresConfirm = parsed['requires_confirmation'] as bool? ?? false;

      switch (intent) {
        case 'OPEN_TRADE':
          if (requiresConfirm) {
            _addMessage(response ?? 'Open trade?', isUser: false, intent: intent);
            _showTradeConfirmDialog(parsed);
          }
          break;

        case 'GET_SIGNAL':
          _addMessage(response ?? 'Fetching signals...', isUser: false, intent: intent);
          await _fetchAndDisplaySignal(parsed['pair'] as String?);
          break;

        case 'GET_NEWS':
          _addMessage(response ?? 'Fetching news...', isUser: false, intent: intent);
          await _sendMessage('Give me the latest forex market news and what it means for trading today.');
          break;

        case 'GET_RISK':
          _addMessage(response ?? 'Calculating...', isUser: false, intent: intent);
          await _sendMessage('Calculate Kelly Criterion position sizing for my current strategy (55% win rate, 1:1.67 RR).');
          break;

        case 'GET_PERFORMANCE':
          _addMessage(response ?? 'Fetching stats...', isUser: false, intent: intent);
          final stats = paperProvider.stats;
          _addMessage(
            '📊 Your Performance:\n'
            '• Total Trades: ${stats.totalTrades}\n'
            '• Win Rate: ${(stats.winRate * 100).toStringAsFixed(1)}%\n'
            '• Total P&L: \$${stats.totalPnl.toStringAsFixed(2)}\n'
            '• Best Trade: \$${stats.bestTrade.toStringAsFixed(2)}',
            isUser: false, intent: intent,
          );
          break;

        case 'CHAT':
        default:
          await _sendMessage(text);
          break;
      }
    } catch (e) {
      debugPrint('NLP command error: $e');
      await _sendMessage(text); // Fallback to regular chat
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAndDisplaySignal(String? pair) async {
    try {
      final api = context.read<ApiService>();
      final signals = await api.fetchLiveSignals(
        pairs: pair != null ? [pair] : ['EUR_USD', 'GBP_USD', 'USD_JPY'],
      );
      if (signals.isNotEmpty) {
        final s = signals.first;
        final action = s['action'] as String? ?? 'HOLD';
        final conf   = ((s['confidence'] as num? ?? 0.5) * 100).toStringAsFixed(0);
        final pair_  = (s['pair'] as String? ?? '').replaceAll('_', '/');
        _addMessage(
          '📊 Signal: $action $pair_\n'
          '• Confidence: $conf%\n'
          '• Entry: ${s['entry_price']}\n'
          '• Stop Loss: ${s['stop_loss']}\n'
          '• Take Profit: ${s['take_profit']}\n'
          '• Reasoning: ${s['reasoning'] ?? 'N/A'}',
          isUser: false, intent: 'GET_SIGNAL',
        );
      } else {
        _addMessage('No signals available right now.', isUser: false);
      }
    } catch (e) {
      _addMessage('Could not fetch signals: $e', isUser: false);
    }
  }

  void _showTradeConfirmDialog(Map<String, dynamic> parsed) {
    final direction = parsed['direction'] as String? ?? 'BUY';
    final pair = (parsed['pair'] as String? ?? 'EUR_USD').replaceAll('_', '/');
    final riskUsd = parsed['risk_usd'] as double? ?? 100.0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161D2E),
        title: Row(children: [
          Icon(direction == 'BUY' ? Icons.trending_up : Icons.trending_down,
              color: direction == 'BUY' ? const Color(0xFF00C896) : const Color(0xFFFF4560)),
          const SizedBox(width: 8),
          Text('Confirm $direction $pair',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Text(
          'Open a paper $direction trade on $pair\nwith \$${riskUsd.toStringAsFixed(2)} risk?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _addMessage('Trade cancelled.', isUser: false); },
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: direction == 'BUY' ? const Color(0xFF00C896) : const Color(0xFFFF4560),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(context);
              _addMessage('Opening $direction $pair paper trade...', isUser: false);
              // Fetch live price and open trade
              try {
                final api = context.read<ApiService>();
                final prices = await api.fetchLiveSignals(pairs: [parsed['pair'] ?? 'EUR_USD']);
                if (prices.isNotEmpty) {
                  final price = (prices.first['entry_price'] as num?)?.toDouble() ?? 1.0;
                  final sl = direction == 'BUY' ? price * 0.995 : price * 1.005;
                  final tp = direction == 'BUY' ? price * 1.01  : price * 0.99;
                  final signal = TradeSignal.fromBackend({
                    'action': direction, 'pair': parsed['pair'], 'entry_price': price,
                    'stop_loss': sl, 'take_profit': tp, 'confidence': 0.7,
                    'sentiment': 'neutral', 'reasoning': 'Voice command trade',
                    'news_summary': '', 'generated_at': DateTime.now().toIso8601String(),
                  });
                  final success = await context.read<PaperTradingProvider>().openFromSignal(signal);
                  _addMessage(
                    success
                        ? '✅ $direction $pair opened at $price\n• SL: ${sl.toStringAsFixed(5)}\n• TP: ${tp.toStringAsFixed(5)}'
                        : '❌ Failed to open trade. Check Paper Trading screen.',
                    isUser: false, intent: 'OPEN_TRADE',
                  );
                }
              } catch (e) {
                _addMessage('❌ Trade error: $e', isUser: false);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ── Regular chat ──────────────────────────────────────────────────────────
  Future<void> _sendMessage([String? override]) async {
    final message = (override ?? _messageController.text).trim();
    if (message.isEmpty) return;
    _messageController.clear();
    if (override == null) _addMessage(message, isUser: true);
    setState(() => _isLoading = true);
    try {
      final response = await _geminiService.sendMessage(message);
      _addMessage(response, isUser: false);
    } catch (e) {
      _addMessage('Sorry, I encountered an error: $e', isUser: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(children: [
              _buildHeader(),
              Expanded(child: _buildMessageList()),
              if (_messages.length <= 1)
                Consumer<QuickActionsProvider>(
                  builder: (ctx, _, __) => QuickActionsOverlay(
                    modeKey: 'aiChat',
                    accentColor: const Color(0xFFD4A853),
                    title: 'QUICK ACTIONS',
                    onAction: (action) {
                      final prompt = _quickPrompts[action.routeOrAction];
                      if (prompt != null) _sendMessage(prompt);
                      else if (action.isRoute) Navigator.pushNamed(context, action.routeOrAction);
                    },
                  ),
                ),
              _buildSuggestionChips(),
              _buildInputArea(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.078),
      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.157))),
    ),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
        onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false),
      ),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.4)),
        ),
        child: const Icon(Icons.psychology_rounded, color: AppColors.primaryGreen, size: 22),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Forex AI Copilot', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          Text('Voice + NLP • Phase 7', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
      // Voice button with pulse animation
      GestureDetector(
        onTap: _startVoice,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isListening
                  ? AppColors.primaryGreen.withOpacity(0.3 + _pulseCtrl.value * 0.2)
                  : Colors.white.withOpacity(0.078),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isListening ? AppColors.primaryGreen : Colors.white24,
                width: _isListening ? 2 : 1,
              ),
              boxShadow: _isListening ? [BoxShadow(
                color: AppColors.primaryGreen.withOpacity(0.3 + _pulseCtrl.value * 0.3),
                blurRadius: 12, spreadRadius: 2,
              )] : [],
            ),
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: _isListening ? AppColors.primaryGreen : Colors.white54,
              size: 22,
            ),
          ),
        ),
      ),
    ]),
  );

  Widget _buildMessageList() => ListView.builder(
    controller: _scrollController,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    itemCount: _messages.length + (_isLoading ? 1 : 0),
    itemBuilder: (context, index) {
      if (index == _messages.length && _isLoading) return _buildLoadingIndicator();
      return _buildMessageBubble(_messages[index]);
    },
  );

  Widget _buildMessageBubble(ChatMessage message) {
    final isCommand = message.isCommand;
    final hasIntent = message.intent != null;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: message.isUser
              ? (isCommand ? const Color(0xFF3B82F6).withOpacity(0.85) : AppColors.primaryGreen.withOpacity(0.85))
              : Colors.white.withOpacity(0.098),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser ? null : Border.all(color: Colors.white.withOpacity(0.137)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasIntent && !message.isUser)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _IntentBadge(intent: message.intent!),
            ),
          Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45)),
          const SizedBox(height: 4),
          Text(_formatTime(message.timestamp),
              style: TextStyle(color: Colors.white.withOpacity(0.47), fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _buildLoadingIndicator() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.098),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16), topRight: Radius.circular(16),
          bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.627)))),
        const SizedBox(width: 10),
        const Text('AI is thinking...', style: TextStyle(color: Colors.white60, fontSize: 13)),
      ]),
    ),
  );

  Widget _buildSuggestionChips() {
    if (_messages.length > 2) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _sendMessage(_suggestions[i].replaceAll(RegExp(r'^[^\w]+'), '').trim()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.078),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(_suggestions[i],
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.071),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.137))),
    ),
    child: Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.118),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.176)),
          ),
          child: TextField(
            controller: _messageController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Ask anything or type a command...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
            enabled: !_isLoading,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryGreen, AppColors.primaryGreen.withOpacity(0.75)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: IconButton(
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          onPressed: _isLoading ? null : () => _sendMessage(),
        ),
      ),
    ]),
  );
}

// ── Intent Badge ──────────────────────────────────────────────────────────────
class _IntentBadge extends StatelessWidget {
  const _IntentBadge({required this.intent});
  final String intent;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (intent) {
      'OPEN_TRADE'     => ('🔄 Trade Command', const Color(0xFF3B82F6)),
      'GET_SIGNAL'     => ('📊 Signal Request', const Color(0xFFD4A853)),
      'GET_NEWS'       => ('📰 News Request',   const Color(0xFF60A5FA)),
      'GET_RISK'       => ('🛡️ Risk Analysis',  const Color(0xFF00C896)),
      'GET_PERFORMANCE'=> ('📈 Performance',    const Color(0xFFD4A853)),
      _                => ('🤖 AI Response',    Colors.white54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? intent;
  final bool isCommand;

  ChatMessage({
    required this.text, required this.isUser, required this.timestamp,
    this.intent, this.isCommand = false,
  });
}