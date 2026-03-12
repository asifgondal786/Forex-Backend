import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/gemini_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _voiceInvoked = false;

  // ── Quick-ask suggestion chips ──────────────────────────────────────────
  static const List<String> _suggestions = [
    '📈 What is EUR/USD doing today?',
    '💡 Explain pip value',
    '🔍 Best pairs for beginners?',
    '📰 Latest market news',
    '⚠️ What is a stop loss?',
    '🕐 Best trading hours?',
  ];

  @override
  void initState() {
    super.initState();
    // Show time-based greeting silently — no auto-speak
    _addMessage(_timeBasedGreeting(), isUser: false);
  }

  // ── Time-based greeting ─────────────────────────────────────────────────
  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    String salutation;
    if (hour >= 5 && hour < 12) {
      salutation = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      salutation = 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      salutation = 'Good Evening';
    } else {
      salutation = 'Welcome Back';
    }
    return '$salutation! 👋 I\'m your Forex Companion AI.\n\n'
        'Ask me anything about forex trading, market analysis, or strategies. '
        'You can also tap a suggestion below to get started quickly.';
  }

  void _addMessage(String text, {required bool isUser}) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: isUser, timestamp: DateTime.now()),
      );
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

  Future<void> _sendMessage([String? override]) async {
    final message = override ?? _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    _addMessage(message, isUser: true);
    setState(() => _isLoading = true);

    try {
      final response = await _geminiService.sendMessage(message);
      _addMessage(response, isUser: false);
    } catch (e) {
      _addMessage('Sorry, I encountered an error: $e', isUser: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Voice invoke — greets and focuses input ─────────────────────────────
  void _invokeVoice() {
    if (_voiceInvoked) return;
    setState(() => _voiceInvoked = true);
    HapticFeedback.mediumImpact();
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good Morning, Sir! Ready to assist. What would you like to know?';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon, Sir! How can I help you with the markets today?';
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good Evening, Sir! What market insights can I provide?';
    } else {
      greeting = 'Welcome Back, Sir! Ready for late-night market analysis?';
    }
    _addMessage('🎙️ $greeting', isUser: false);
    // Reset so user can invoke again later
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _voiceInvoked = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
  if (!didPop) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/dashboard',
      (route) => false,
    );
        }
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMessageList()),
                _buildSuggestionChips(),
                _buildInputArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(40)),
        ),
      ),
      child: Row(
        children: [
          // Back to dashboard
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              '/dashboard',
              (route) => false,
            ),
            tooltip: 'Back to Dashboard',
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.4), width: 1),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: AppColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Forex AI Assistant',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  'Powered by Gemini • Ask anything',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // Online indicator
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text('Online',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 8),
          // Voice invoke button
          GestureDetector(
            onTap: _invokeVoice,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _voiceInvoked
                    ? AppColors.primaryGreen.withOpacity(0.3)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _voiceInvoked
                      ? AppColors.primaryGreen
                      : Colors.white24,
                  width: 1,
                ),
              ),
              child: Icon(
                _voiceInvoked ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _voiceInvoked
                    ? AppColors.primaryGreen
                    : Colors.white54,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildLoadingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.primaryGreen.withOpacity(0.85)
              : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser
              ? null
              : Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14.5, height: 1.45),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style:
                  TextStyle(color: Colors.white.withAlpha(120), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation(Colors.white.withAlpha(160)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('AI is thinking...',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Suggestion chips ────────────────────────────────────────────────────
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
          onTap: () => _sendMessage(_suggestions[i]
              .replaceAll(RegExp(r'^[^\w]+'), '')
              .trim()),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              _suggestions[i],
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(35))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(45)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ask about forex markets...',
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
                colors: [
                  AppColors.primaryGreen,
                  AppColors.primaryGreen.withOpacity(0.75)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _isLoading ? null : () => _sendMessage(),
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}