import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nlp_provider.dart';

class NlpCopilotScreen extends StatefulWidget {
  const NlpCopilotScreen({super.key});

  @override
  State<NlpCopilotScreen> createState() => _NlpCopilotScreenState();
}

class _NlpCopilotScreenState extends State<NlpCopilotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late final NlpProvider _provider = NlpProvider();

  static const _suggestions = [
    'Buy EUR/USD with 1% risk',
    'Sell GBP/USD, tight stop',
    'What should I trade today?',
    'Open USD/JPY long position',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _provider.dispose();
    super.dispose();
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

  void _send(NlpProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty || provider.isLoading) return;
    _controller.clear();
    provider.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChangeNotifierProvider<NlpProvider>.value(
      value: _provider,
      child: Consumer<NlpProvider>(
        builder: (context, provider, _) {
          if (provider.messages.isNotEmpty) _scrollToBottom();

          return Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              title: const Text('AI Copilot'),
              backgroundColor: colorScheme.surface,
              elevation: 0,
              actions: [
                if (provider.messages.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Clear chat',
                    onPressed: provider.clearConversation,
                  ),
              ],
            ),
            body: Column(
              children: [
                _StatusBanner(stage: provider.stage),
                Expanded(
                  child: provider.messages.isEmpty
                      ? _EmptyState(
                          suggestions: _suggestions,
                          onSuggestion: (s) {
                            _controller.text = s;
                            _send(provider);
                          },
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: provider.messages.length,
                          itemBuilder: (context, i) =>
                              _ChatBubble(message: provider.messages[i]),
                        ),
                ),
                if (provider.stage == NlpConversationStage.confirmed)
                  _ConfirmBar(
                    onConfirm: provider.confirmTrade,
                    onReject: provider.rejectTrade,
                  ),
                _InputBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  isLoading: provider.isLoading,
                  onSend: () => _send(provider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final NlpConversationStage stage;
  const _StatusBanner({required this.stage});

  @override
  Widget build(BuildContext context) {
    String? label;
    Color? color;

    switch (stage) {
      case NlpConversationStage.parsing:
        label = 'Analysing your command…';
        color = Colors.blue.shade700;
        break;
      case NlpConversationStage.executing:
        label = 'Executing paper trade…';
        color = Colors.orange.shade700;
        break;
      case NlpConversationStage.done:
        label = 'Trade executed successfully ✓';
        color = Colors.green.shade700;
        break;
      case NlpConversationStage.error:
        label = 'Something went wrong';
        color = Colors.red.shade700;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: color?.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          if (stage == NlpConversationStage.parsing ||
              stage == NlpConversationStage.executing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              ),
            ),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  const _EmptyState({
    required this.suggestions,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'AI Trading Copilot',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a trade command or ask a question.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions
                  .map((s) => ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        onPressed: () => onSuggestion(s),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final NlpMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontSize: 14,
            height: 1.45,
            fontFamily: message.text.contains('─') ? 'monospace' : null,
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  const _ConfirmBar({required this.onConfirm, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Execute Trade'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g. Buy EUR/USD with 1% risk…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: isLoading ? null : onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

