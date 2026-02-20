import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../core/models/agent_orchestrator_models.dart';
import '../../core/widgets/app_background.dart';
import '../../routes/app_routes.dart';
import '../../providers/account_connection_provider.dart';
import '../../providers/agent_orchestrator_provider.dart';
import 'widgets/forex_feed_widget.dart';
import 'widgets/news_sentiment_widget.dart';

class EmbodiedAgentScreen extends StatefulWidget {
  const EmbodiedAgentScreen({super.key});

  @override
  State<EmbodiedAgentScreen> createState() => _EmbodiedAgentScreenState();
}

class _EmbodiedAgentScreenState extends State<EmbodiedAgentScreen> {
  final TextEditingController _commandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AgentOrchestratorProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentOrchestratorProvider>(
      builder: (context, agent, _) {
        final viewport = MediaQuery.of(context).size;
        final isMobile = viewport.width < 980;
        final isTinyViewport = viewport.width <= 260 || viewport.height <= 520;
        return Scaffold(
          floatingActionButton: _KillSwitchFab(agent: agent),
          body: AppBackground(
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(agent, isMobile, isTinyViewport),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? (isTinyViewport ? 8 : 12) : 18,
                        isTinyViewport ? 8 : 10,
                        isMobile ? (isTinyViewport ? 8 : 12) : 18,
                        isTinyViewport ? 8 : 12,
                      ),
                      child: isMobile
                          ? _buildMobileLayout(agent, isTinyViewport)
                          : _buildDesktopLayout(agent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    AgentOrchestratorProvider agent,
    bool isMobile,
    bool isTinyViewport,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? (isTinyViewport ? 10 : 14) : 20,
        isTinyViewport ? 10 : 14,
        isMobile ? (isTinyViewport ? 10 : 14) : 20,
        isTinyViewport ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTitle(isTiny: isTinyViewport),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: agent.visualState.label,
                      color: visualStateColor(agent.visualState),
                    ),
                    _StatusChip(
                      label: agent.autonomyMode.label,
                      color: autonomyColor(agent.autonomyMode),
                    ),
                    _StatusChip(
                      label: isTinyViewport
                          ? '${agent.confidenceScore.toStringAsFixed(0)}% conf'
                          : '${agent.confidenceScore.toStringAsFixed(0)}% confidence',
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compactStack = constraints.maxWidth < 420;
                    final biasText = Text(
                      agent.offlineMode
                          ? 'Simulation mode active (backend unavailable). Market bias: ${agent.marketBias}'
                          : 'Market bias: ${agent.marketBias}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    );
                    if (compactStack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          biasText,
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildTopActions(
                              agent,
                              isCompact: true,
                              isTiny: isTinyViewport,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: biasText),
                        _buildTopActions(
                          agent,
                          isCompact: true,
                          isTiny: isTinyViewport,
                        ),
                      ],
                    );
                  },
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildHeaderTitle()),
                _StatusChip(
                  label: agent.visualState.label,
                  color: visualStateColor(agent.visualState),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: agent.autonomyMode.label,
                  color: autonomyColor(agent.autonomyMode),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label:
                      '${agent.confidenceScore.toStringAsFixed(0)}% confidence',
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                Text(
                  'Bias: ${agent.marketBias}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 14),
                _buildTopActions(agent, isTiny: false),
              ],
            ),
    );
  }

  Widget _buildHeaderTitle({bool isTiny = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final logoSize = isTiny
            ? 54.0
            : maxWidth >= 1500
                ? 250.0
                : maxWidth >= 1100
                    ? 160.0
                    : maxWidth >= 820
                        ? 120.0
                        : maxWidth >= 600
                            ? 90.0
                            : 68.0;
        final brandSize = isTiny
            ? 14.0
            : logoSize >= 220
                ? 30.0
                : logoSize >= 160
                    ? 26.0
                    : logoSize >= 120
                        ? 22.0
                        : 18.0;
        final copilotSize =
            (isTiny ? 10.0 : brandSize - 8).clamp(10.0, 18.0).toDouble();
        final taglineSize =
            (isTiny ? 10.0 : brandSize - 11).clamp(10.0, 15.0).toDouble();
        final spacing = isTiny ? 8.0 : (logoSize >= 160 ? 14.0 : 10.0);

        final logo = SizedBox(
          width: logoSize,
          height: logoSize,
          child: Image.asset(
            'assets/images/companion_logo.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.currency_exchange,
                color: Colors.white70,
                size: logoSize - 10,
              );
            },
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -1),
              child: logo,
            ),
            SizedBox(width: spacing),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Forex Companion ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: brandSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Your Forex Co-Pilot',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: copilotSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 0.5),
                  Text(
                    'Your Sleep I Earn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: taglineSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopActions(AgentOrchestratorProvider agent,
      {bool isCompact = false, bool isTiny = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'User/Admin Dashboard',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          icon: Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.white70,
            size: isTiny ? 17 : 19,
          ),
          visualDensity:
              isTiny ? VisualDensity.compact : VisualDensity.standard,
        ),
        if (agent.isProcessing)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        IconButton(
          tooltip: 'Refresh guardrails',
          onPressed: agent.isProcessing ? null : agent.refreshGuardrails,
          icon: Icon(
            Icons.refresh,
            color: Colors.white70,
            size: isTiny ? 18 : 20,
          ),
          visualDensity:
              isTiny ? VisualDensity.compact : VisualDensity.standard,
        ),
        if (!isCompact) const SizedBox(width: 2),
      ],
    );
  }

  Widget _buildDesktopLayout(AgentOrchestratorProvider agent) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: ListView(
            children: [
              _buildAvatarCard(agent),
              const SizedBox(height: 14),
              _buildControlCard(agent),
              const SizedBox(height: 14),
              _buildSafeguardsCard(agent),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 6,
          child: ListView(
            children: [
              _buildConversationCard(agent),
              const SizedBox(height: 14),
              _buildDecisionLogCard(agent),
              const SizedBox(height: 14),
              _buildMarketIntelligenceSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(AgentOrchestratorProvider agent, bool isTiny) {
    return ListView(
      children: [
        _buildAvatarCard(agent, isTiny: isTiny),
        const SizedBox(height: 12),
        _buildControlCard(agent),
        const SizedBox(height: 12),
        _buildConversationCard(agent, isTiny: isTiny),
        const SizedBox(height: 12),
        _buildDecisionLogCard(agent),
        const SizedBox(height: 12),
        _buildMarketIntelligenceSection(),
        const SizedBox(height: 12),
        _buildSafeguardsCard(agent),
      ],
    );
  }

  Widget _buildMarketIntelligenceSection() {
    return _GlassPanel(
      title: 'Market Intelligence',
      subtitle:
          'Merged relevant legacy capabilities: broker state, forex feed, and news sentiment.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrokerAccountCard(),
          const SizedBox(height: 12),
          const ForexFeedWidget(),
          const SizedBox(height: 12),
          const NewsSentimentWidget(),
        ],
      ),
    );
  }

  Widget _buildBrokerAccountCard() {
    return Consumer<AccountConnectionProvider>(
      builder: (context, provider, _) {
        final account = provider.selectedAccount;
        final isConnected = account?.isConnected ?? false;
        final statusColor =
            isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack = constraints.maxWidth < 260;
              final statusBadge = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );

              return Row(
                crossAxisAlignment: shouldStack
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account?.broker ?? 'No broker connected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account == null
                              ? 'Connect your broker to enable live execution.'
                              : 'Balance ${account.currency} ${account.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11,
                          ),
                        ),
                        if (shouldStack) ...[
                          const SizedBox(height: 8),
                          statusBadge,
                        ],
                      ],
                    ),
                  ),
                  if (!shouldStack) statusBadge,
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAvatarCard(
    AgentOrchestratorProvider agent, {
    bool isTiny = false,
  }) {
    return _GlassPanel(
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarStage(
            state: agent.visualState,
            confidenceScore: agent.confidenceScore,
            isSpeaking: agent.isBotSpeaking || agent.isCapturingVoiceCommand,
            compact: isTiny,
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard(AgentOrchestratorProvider agent) {
    final pending = agent.pendingHighRiskCommand;
    final applyGuardrailsButton = ElevatedButton.icon(
      onPressed: agent.isProcessing ? null : agent.applyDraftGuardrails,
      icon: const Icon(Icons.shield_outlined),
      label: const Text('Apply Guardrails'),
      style: AppTheme.glassElevatedButtonStyle(
        tintColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
    final runCycleButton = ElevatedButton.icon(
      onPressed: agent.isProcessing ? null : agent.executeAutonomousCycle,
      icon: const Icon(Icons.play_circle_outline),
      label: const Text('Run Cycle'),
      style: AppTheme.glassElevatedButtonStyle(
        tintColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );

    return _GlassPanel(
      title: 'Authority and Risk Controls',
      subtitle:
          'Non-negotiable guardrails stay enforced in every autonomy mode',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<AgentAutonomyMode>(
            key: ValueKey<AgentAutonomyMode>(agent.autonomyMode),
            initialValue: agent.autonomyMode,
            isExpanded: true,
            iconEnabledColor: Colors.white70,
            decoration: _inputDecoration('Autonomy mode'),
            dropdownColor: const Color(0xFF0B1220),
            items: AgentAutonomyMode.values
                .map(
                  (mode) => DropdownMenuItem<AgentAutonomyMode>(
                    value: mode,
                    child: Text(mode.label),
                  ),
                )
                .toList(),
            onChanged: agent.isProcessing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    agent.updateAutonomyMode(value);
                  },
          ),
          const SizedBox(height: 14),
          _buildSliderRow(
            label: 'Risk per trade',
            value: agent.draftRiskPerTradePercent,
            min: 0.25,
            max: 3.0,
            suffix: '%',
            onChanged: agent.setDraftRiskPerTradePercent,
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Daily loss cap',
            value: agent.draftDailyLossPercent,
            min: 0.5,
            max: 8.0,
            suffix: '%',
            onChanged: agent.setDraftDailyLossPercent,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack = constraints.maxWidth < 460;
              if (shouldStack) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: applyGuardrailsButton,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: runCycleButton,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: applyGuardrailsButton),
                  const SizedBox(width: 10),
                  Expanded(child: runCycleButton),
                ],
              );
            },
          ),
          if (pending != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirmation Required',
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pending,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final shouldStack = constraints.maxWidth < 360;
                      if (shouldStack) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton(
                              onPressed: agent.isProcessing
                                  ? null
                                  : () =>
                                      agent.submitCommand('confirm command'),
                              child: const Text('Confirm Command'),
                            ),
                            TextButton(
                              onPressed: agent.dismissPendingHighRiskCommand,
                              child: const Text('Dismiss'),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          TextButton(
                            onPressed: agent.isProcessing
                                ? null
                                : () => agent.submitCommand('confirm command'),
                            child: const Text('Confirm Command'),
                          ),
                          TextButton(
                            onPressed: agent.dismissPendingHighRiskCommand,
                            child: const Text('Dismiss'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          if (agent.error != null) ...[
            const SizedBox(height: 12),
            Text(
              agent.error!,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationCard(
    AgentOrchestratorProvider agent, {
    bool isTiny = false,
  }) {
    final messages = agent.conversation.reversed.toList(growable: false);
    return _GlassPanel(
      title: 'Voice + Chat Command Plane',
      subtitle: 'Natural-language instructions route to one orchestrator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack = constraints.maxWidth < 360;
              final dropdown = DropdownButtonFormField<String>(
                key: ValueKey<String>(agent.languageCode),
                initialValue: agent.languageCode,
                isExpanded: true,
                decoration: _inputDecoration('Select language').copyWith(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                dropdownColor: const Color(0xFF0B1220),
                items: agent.supportedLanguages.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  agent.setLanguage(value);
                },
              );

              if (shouldStack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Language',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    dropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Text(
                    'Language',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: dropdown),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            height: isTiny ? 190 : 300,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _ChatBubble(turn: message);
              },
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxChipWidth =
                  constraints.maxWidth.clamp(160.0, 360.0).toDouble();
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CommandSuggestionChip(
                    maxWidth: maxChipWidth,
                    label: 'Enable full autonomy with 1% risk per trade',
                    onTap: () => agent.submitCommand(
                      'Enable full autonomy with 1% risk per trade',
                    ),
                  ),
                  _CommandSuggestionChip(
                    maxWidth: maxChipWidth,
                    label: 'Pause trading during high volatility',
                    onTap: () => agent.submitCommand(
                      'Pause trading during high volatility',
                    ),
                  ),
                  _CommandSuggestionChip(
                    maxWidth: maxChipWidth,
                    label: 'Explain your current market bias',
                    onTap: () => agent.submitCommand(
                      'Explain your current market bias',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack = constraints.maxWidth < 390;
              final commandField = TextField(
                controller: _commandController,
                style: const TextStyle(color: Colors.white),
                minLines: 1,
                maxLines: isTiny ? 2 : 3,
                decoration: _inputDecoration('Type command for the agent'),
                onSubmitted: (_) => _submitCommand(agent),
              );
              final voiceModeButton = IconButton.filledTonal(
                onPressed: agent.isProcessing
                    ? null
                    : () {
                        agent.toggleVoiceListening();
                      },
                icon: Icon(
                  agent.isVoiceListening ? Icons.volume_up : Icons.volume_off,
                  color: agent.isVoiceListening
                      ? const Color(0xFF10B981)
                      : Colors.white70,
                ),
                tooltip: 'Toggle voice mode',
              );
              final voiceCaptureButton = IconButton.filledTonal(
                onPressed: (!agent.isVoiceListening ||
                        agent.isCapturingVoiceCommand ||
                        agent.isProcessing)
                    ? null
                    : () => agent.captureVoiceCommand(),
                icon: Icon(
                  agent.isCapturingVoiceCommand ? Icons.hearing : Icons.mic,
                  color: agent.isCapturingVoiceCommand
                      ? const Color(0xFF22D3EE)
                      : Colors.white,
                ),
                tooltip: 'Speak command',
              );
              final voiceTestButton = IconButton.filledTonal(
                onPressed: agent.isProcessing ? null : agent.triggerVoiceTest,
                icon: const Icon(Icons.record_voice_over_rounded),
                tooltip: 'Test voice output',
              );
              final sendButton = IconButton.filled(
                onPressed:
                    agent.isProcessing ? null : () => _submitCommand(agent),
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Send command',
              );

              if (shouldStack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    commandField,
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        voiceModeButton,
                        voiceCaptureButton,
                        voiceTestButton,
                        sendButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: commandField),
                  const SizedBox(width: 8),
                  voiceModeButton,
                  const SizedBox(width: 6),
                  voiceCaptureButton,
                  const SizedBox(width: 6),
                  voiceTestButton,
                  const SizedBox(width: 6),
                  sendButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionLogCard(AgentOrchestratorProvider agent) {
    final entries = agent.decisionLog.take(8).toList(growable: false);
    return _GlassPanel(
      title: 'Decision Timeline',
      subtitle: 'Explainability feed with rationale and confidence',
      child: Column(
        children: entries.isEmpty
            ? [
                const SizedBox(height: 8),
                Text(
                  'No decisions logged yet.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ]
            : entries.map((entry) => _DecisionTile(entry: entry)).toList(),
      ),
    );
  }

  Widget _buildSafeguardsCard(AgentOrchestratorProvider agent) {
    final g = agent.guardrails;
    return _GlassPanel(
      title: 'Immutable Safety Layer',
      subtitle: 'Capital preservation, circuit breakers, and instant overrides',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SafetyRow(
            label: 'Max risk per trade',
            value: '${g.maxRiskPerTradePercent.toStringAsFixed(2)}%',
            color: const Color(0xFF3B82F6),
          ),
          _SafetyRow(
            label: 'Daily loss limit',
            value: '${g.dailyLossLimitPercent.toStringAsFixed(2)}%',
            color: const Color(0xFFEF4444),
          ),
          _SafetyRow(
            label: 'Weekly loss limit',
            value: '${g.weeklyLossLimitPercent.toStringAsFixed(2)}%',
            color: const Color(0xFFF59E0B),
          ),
          _SafetyRow(
            label: 'Hard max drawdown',
            value: '${g.hardMaxDrawdownPercent.toStringAsFixed(2)}%',
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              g.pauseReason.isEmpty
                  ? 'No active risk lock. Live execution still requires explicit mode and guardrail alignment.'
                  : 'Current pause reason: ${g.pauseReason}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(2)}$suffix',
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.48)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
    );
  }

  void _submitCommand(AgentOrchestratorProvider agent) {
    final command = _commandController.text.trim();
    if (command.isEmpty) {
      return;
    }
    _commandController.clear();
    agent.submitCommand(command);
  }
}

class _GlassPanel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final bool showHeader;
  final Widget child;

  const _GlassPanel({
    this.title,
    this.subtitle,
    this.showHeader = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTiny = width <= 260;
    final hasTitle = showHeader && title != null && title!.trim().isNotEmpty;
    final hasSubtitle =
        showHeader && subtitle != null && subtitle!.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(isTiny ? 10 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle)
            Text(
              title!,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTiny ? 13 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (hasSubtitle) ...[
            SizedBox(height: hasTitle ? 4 : 0),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: isTiny ? 10 : 11,
              ),
            ),
          ],
          if (hasTitle || hasSubtitle) SizedBox(height: isTiny ? 10 : 12),
          child,
        ],
      ),
    );
  }
}

class _AvatarStage extends StatefulWidget {
  final AgentVisualState state;
  final double confidenceScore;
  final Object? isSpeaking;
  final bool compact;

  const _AvatarStage({
    required this.state,
    required this.confidenceScore,
    this.isSpeaking = false,
    this.compact = false,
  });

  @override
  State<_AvatarStage> createState() => _AvatarStageState();
}

class _AvatarStageState extends State<_AvatarStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = visualStateColor(widget.state);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final speaking = widget.isSpeaking == true;
        final compact = widget.compact;
        final stageHeight = compact ? 210.0 : 280.0;
        final effectSize = compact ? 120.0 : 146.0;
        final coreSize = compact ? 92.0 : 114.0;
        final iconSize = compact ? 34.0 : 44.0;
        final mouthBottom = compact ? 18.0 : 22.0;
        final phase = _controller.value;
        final antiClockwiseRotation = -2 * math.pi * phase;
        final clockwiseRotation = 2 * math.pi * phase;
        final zoomPulse =
            1.0 + (0.02 * math.sin(phase * 2 * math.pi * 0.8)); // very slow
        final glowPulse =
            0.42 + (0.58 * ((math.sin(phase * 2 * math.pi * 1.3) + 1) / 2));
        final speechA = speaking
            ? (0.30 + 0.70 * ((math.sin(phase * 2 * math.pi * 6.5) + 1) / 2))
            : 0.0;
        final speechB = speaking
            ? (0.30 +
                0.70 * ((math.sin((phase * 2 * math.pi * 6.5) + 1.6) + 1) / 2))
            : 0.0;
        final speechC = speaking
            ? (0.30 +
                0.70 * ((math.sin((phase * 2 * math.pi * 6.5) + 3.2) + 1) / 2))
            : 0.0;

        return Container(
          width: double.infinity,
          height: stageHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withValues(alpha: 0.16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _OrbitRingsPainter(
                    rotation: antiClockwiseRotation,
                    coreRotation: antiClockwiseRotation,
                    techRotation: clockwiseRotation,
                    horizontalSweep: 0,
                    glitterPhase: phase,
                  ),
                ),
              ),
              Transform.scale(
                scale: zoomPulse,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(effectSize, effectSize),
                      painter: _BotGlitterPainter(
                        phase: phase,
                        tint: color,
                      ),
                    ),
                    Container(
                      width: coreSize,
                      height: coreSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.9),
                            color.withValues(alpha: 0.34),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(
                              alpha: 0.25 + (0.18 * glowPulse),
                            ),
                            blurRadius: 20 + (10 * glowPulse),
                            spreadRadius: 2 + (1.5 * glowPulse),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.white,
                            size: iconSize,
                          ),
                          Positioned(
                            bottom: mouthBottom,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 120),
                              opacity: speaking ? 1 : 0,
                              child: SizedBox(
                                width: 34,
                                height: 13,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 5.0,
                                      height: 2.0 + (8.0 * speechA),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF97316)
                                            .withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                    Container(
                                      width: 5.0,
                                      height: 2.0 + (8.0 * speechB),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFB923C)
                                            .withValues(alpha: 0.98),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                    Container(
                                      width: 5.0,
                                      height: 2.0 + (8.0 * speechC),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF97316)
                                            .withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: speaking ? 1 : 0,
                                child: CustomPaint(
                                  painter: _SpeakingPulsePainter(
                                    phase: phase,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: compact ? 10 : 16,
                right: compact ? 10 : 16,
                child: _StatusChip(
                  label: '${widget.confidenceScore.toStringAsFixed(0)}%',
                  color: const Color(0xFF10B981),
                ),
              ),
              Positioned(
                bottom: compact ? 12 : 18,
                child: const _MonitoringPulseChip(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrbitRingsPainter extends CustomPainter {
  // Legacy field retained to keep hot-reload compatibility with older class
  // shape that used `rotation`.
  final double rotation;
  final double coreRotation;
  final double techRotation;
  final double horizontalSweep;
  final double glitterPhase;

  const _OrbitRingsPainter({
    this.rotation = 0,
    required this.coreRotation,
    required this.techRotation,
    required this.horizontalSweep,
    required this.glitterPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveCoreRotation = coreRotation == 0 ? rotation : coreRotation;
    final effectiveTechRotation = techRotation == 0 ? rotation : techRotation;
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height);
    final outerRadius = baseRadius * 0.30;
    final innerRadius = baseRadius * 0.22;
    final illuminationSweep = 70 * math.pi / 180; // 70-degree illumination

    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    final outerBaseLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFE53935).withValues(alpha: 0.45);
    final innerBaseLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF10B981).withValues(alpha: 0.45);

    canvas.drawCircle(center, outerRadius, outerBaseLine);
    canvas.drawCircle(center, innerRadius, innerBaseLine);

    final outerStart = -math.pi / 2 + effectiveCoreRotation; // anti-clockwise
    final innerStart = -math.pi / 2 + effectiveTechRotation; // clockwise

    final outerIllumination = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFFF5252).withValues(alpha: 0.98),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(outerStart),
      ).createShader(outerRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

    final innerIllumination = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF00E676).withValues(alpha: 0.98),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(innerStart),
      ).createShader(innerRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

    canvas.drawArc(
      outerRect,
      outerStart,
      illuminationSweep,
      false,
      outerIllumination,
    );
    canvas.drawArc(
      innerRect,
      innerStart,
      illuminationSweep,
      false,
      innerIllumination,
    );

    final glitterPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 10; i++) {
      final t = i / 9;
      final angle = outerStart + (illuminationSweep * t);
      final pulse = (math.sin((glitterPhase * 2 * math.pi * 2) + i) + 1) / 2;
      final p = Offset(
        center.dx + (math.cos(angle) * outerRadius),
        center.dy + (math.sin(angle) * outerRadius),
      );
      glitterPaint.color =
          const Color(0xFFFF5252).withValues(alpha: 0.25 + (0.55 * pulse));
      canvas.drawCircle(p, 0.35 + (0.9 * pulse), glitterPaint);
    }

    for (int i = 0; i < 10; i++) {
      final t = i / 9;
      final angle = innerStart + (illuminationSweep * t);
      final pulse =
          (math.sin((glitterPhase * 2 * math.pi * 2.1) + (i * 1.3)) + 1) / 2;
      final p = Offset(
        center.dx + (math.cos(angle) * innerRadius),
        center.dy + (math.sin(angle) * innerRadius),
      );
      glitterPaint.color =
          const Color(0xFF00E676).withValues(alpha: 0.25 + (0.55 * pulse));
      canvas.drawCircle(p, 0.35 + (0.9 * pulse), glitterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingsPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.coreRotation != coreRotation ||
        oldDelegate.techRotation != techRotation ||
        oldDelegate.horizontalSweep != horizontalSweep ||
        oldDelegate.glitterPhase != glitterPhase;
  }
}

class _BotGlitterPainter extends CustomPainter {
  final double phase;
  final Color tint;

  const _BotGlitterPainter({
    required this.phase,
    required this.tint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final glitterPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 16; i++) {
      final angle = (2 * math.pi / 16) * i + (phase * 2 * math.pi * 0.6);
      final pulse = (math.sin((phase * 2 * math.pi * 3.0) + i) + 1) / 2;
      final radius = 58 + (4 * pulse);
      final p = Offset(
        center.dx + (math.cos(angle) * radius),
        center.dy + (math.sin(angle) * radius),
      );
      glitterPaint.color = Color.lerp(
        Colors.white.withValues(alpha: 0.85),
        tint.withValues(alpha: 0.7),
        i.isEven ? 0.25 : 0.65,
      )!
          .withValues(alpha: 0.15 + (0.45 * pulse));
      canvas.drawCircle(p, 0.45 + (0.85 * pulse), glitterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BotGlitterPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.tint != tint;
  }
}

class _SpeakingPulsePainter extends CustomPainter {
  final double phase;

  const _SpeakingPulsePainter({
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = math.min(size.width, size.height) * 0.42;
    final pulse =
        0.5 + (0.5 * ((math.sin((phase * 2 * math.pi * 5.5) + 0.8) + 1) / 2));

    final ringA = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFB923C).withValues(alpha: 0.2 + (0.25 * pulse))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    final ringB = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFF97316).withValues(alpha: 0.16 + (0.22 * pulse))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    canvas.drawCircle(center, base + (3.0 * pulse), ringA);
    canvas.drawCircle(center, (base - 8) + (2.0 * pulse), ringB);
  }

  @override
  bool shouldRepaint(covariant _SpeakingPulsePainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isTiny = MediaQuery.of(context).size.width <= 260;
    final maxLabelWidth = isTiny ? 132.0 : 220.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTiny ? 8 : 10,
        vertical: isTiny ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxLabelWidth),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: isTiny ? 10 : 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MonitoringPulseChip extends StatefulWidget {
  const _MonitoringPulseChip();

  @override
  State<_MonitoringPulseChip> createState() => _MonitoringPulseChipState();
}

class _MonitoringPulseChipState extends State<_MonitoringPulseChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTiny = MediaQuery.of(context).size.width <= 260;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final scale = 1.0 + (0.045 * t); // subtle heart-beat pop
        final gradientStart =
            Color.lerp(const Color(0xFF10B981), const Color(0xFFEF4444), t)!;
        final gradientEnd =
            Color.lerp(const Color(0xFF047857), const Color(0xFFB91C1C), t)!;
        final glowColor =
            Color.lerp(const Color(0xFF10B981), const Color(0xFFEF4444), t)!;

        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTiny ? 10 : 12,
              vertical: isTiny ? 5 : 6,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  gradientStart.withValues(alpha: 0.28),
                  gradientEnd.withValues(alpha: 0.38),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: glowColor.withValues(alpha: 0.75)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.24),
                  blurRadius: 10,
                  spreadRadius: 0.4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.radio_button_checked,
                  size: isTiny ? 10 : 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Monitoring',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTiny ? 10 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommandSuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double maxWidth;

  const _CommandSuggestionChip({
    required this.label,
    required this.onTap,
    this.maxWidth = 360,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
      ),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AgentConversationTurn turn;

  const _ChatBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = turn.fromUser
        ? const Color(0xFF1D4ED8).withValues(alpha: 0.26)
        : Colors.white.withValues(alpha: 0.07);
    final borderColor = turn.fromUser
        ? const Color(0xFF3B82F6).withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.14);

    return Align(
      alignment: turn.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              turn.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _formatTime(turn.timestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  final DecisionLogEntry entry;

  const _DecisionTile({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.blockedByGuardrails
        ? const Color(0xFFEF4444)
        : visualStateColor(entry.state);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatTime(entry.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.rationale,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          _StatusChip(
            label:
                '${entry.state.label} - ${entry.confidencePercent.toStringAsFixed(0)}%',
            color: color,
          ),
        ],
      ),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SafetyRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KillSwitchFab extends StatelessWidget {
  final AgentOrchestratorProvider agent;

  const _KillSwitchFab({required this.agent});

  @override
  Widget build(BuildContext context) {
    final isTiny = MediaQuery.of(context).size.width <= 260;
    final onPressed = agent.isProcessing
        ? null
        : () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF0F172A),
                  title: const Text(
                    'Engage Kill Switch?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'This immediately revokes autonomous execution and forces manual mode.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: AppTheme.glassElevatedButtonStyle(
                        tintColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Stop Now'),
                    ),
                  ],
                );
              },
            );

            if (confirmed == true) {
              await agent.engageKillSwitch();
            }
          };

    if (isTiny) {
      return FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: agent.isKillSwitchEngaged
            ? const Color(0xFF9CA3AF)
            : const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        tooltip: agent.isKillSwitchEngaged ? 'Stopped' : 'Kill Switch',
        child: const Icon(Icons.stop_circle_outlined),
      );
    }

    return FloatingActionButton.extended(
      onPressed: agent.isProcessing ? null : onPressed,
      backgroundColor: agent.isKillSwitchEngaged
          ? const Color(0xFF9CA3AF)
          : const Color(0xFFEF4444),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.stop_circle_outlined),
      label: Text(agent.isKillSwitchEngaged ? 'Stopped' : 'Kill Switch'),
    );
  }
}

Color visualStateColor(AgentVisualState state) {
  switch (state) {
    case AgentVisualState.monitoring:
      return const Color(0xFF10B981);
    case AgentVisualState.analyzing:
      return const Color(0xFFF59E0B);
    case AgentVisualState.trading:
      return const Color(0xFFEF4444);
    case AgentVisualState.paused:
      return const Color(0xFF94A3B8);
  }
}

Color autonomyColor(AgentAutonomyMode mode) {
  switch (mode) {
    case AgentAutonomyMode.manual:
      return const Color(0xFF94A3B8);
    case AgentAutonomyMode.assisted:
      return const Color(0xFF3B82F6);
    case AgentAutonomyMode.semiAuto:
      return const Color(0xFFF59E0B);
    case AgentAutonomyMode.fullAuto:
      return const Color(0xFFEF4444);
  }
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
