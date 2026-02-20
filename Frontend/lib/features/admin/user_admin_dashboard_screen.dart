import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../core/widgets/app_background.dart';
import '../../providers/account_connection_provider.dart';
import '../../providers/agent_orchestrator_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

enum _Mode { rule, unleashed }

enum _RuleSide { sell, buy }

class UserAdminDashboardScreen extends StatefulWidget {
  const UserAdminDashboardScreen({super.key});

  @override
  State<UserAdminDashboardScreen> createState() =>
      _UserAdminDashboardScreenState();
}

class _UserAdminDashboardScreenState extends State<UserAdminDashboardScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _brokerUser = TextEditingController();
  final _brokerPass = TextEditingController();
  final _rulePrice = TextEditingController(text: '290');
  final _emailAlert = TextEditingController();
  final _mobile = TextEditingController();
  final _whatsapp = TextEditingController();
  final _unlockPhrase = TextEditingController();

  _Mode _mode = _Mode.rule;
  _RuleSide _side = _RuleSide.sell;
  String _pair = 'USD/PKR';

  bool _loadingPrefs = false;
  bool _savingProfile = false;
  bool _savingChannels = false;
  bool _connectingBroker = false;
  bool _applying = false;
  bool _obscurePass = true;
  bool _maskSensitive = true;
  bool _unlocked = false;
  bool _riskAcknowledged = false;
  bool _premiumPreview = false;
  bool _syncedUser = false;
  String? _notice;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _brokerUser.dispose();
    _brokerPass.dispose();
    _rulePrice.dispose();
    _emailAlert.dispose();
    _mobile.dispose();
    _whatsapp.dispose();
    _unlockPhrase.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final users = context.read<UserProvider>();
    final accounts = context.read<AccountConnectionProvider>();
    if (users.user == null && !users.isLoading) {
      await users.fetchUser();
    }
    if (accounts.connections.isEmpty && !accounts.isLoading) {
      await accounts.loadConnections();
    }
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loadingPrefs = true;
      _notice = null;
    });
    try {
      final prefs =
          await context.read<ApiService>().getNotificationPreferences();
      final settings = prefs['channel_settings'];
      if (settings is Map) {
        _emailAlert.text = _asText(settings['email_to']);
        _mobile.text = _asText(settings['phone_number']);
        _whatsapp.text = _asText(settings['whatsapp_number']);
      }
      final autonomous = prefs['autonomous_mode'] == true;
      final profile = _asText(prefs['autonomous_profile']).toLowerCase();
      _mode = autonomous && profile.contains('aggressive')
          ? _Mode.unleashed
          : _Mode.rule;
      _lastSync = DateTime.now();
    } catch (_) {
      _notice = 'Preference sync unavailable. Working in local-safe mode.';
    } finally {
      if (mounted) {
        setState(() {
          _loadingPrefs = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    final users = context.read<UserProvider>();
    await users.updateUser(name: _name.text.trim(), email: _email.text.trim());
    if (!mounted) return;
    setState(() => _savingProfile = false);
    _snack(
        users.error == null
            ? 'Account details saved.'
            : 'Failed to save account details.',
        users.error == null);
  }

  Future<void> _saveChannels() async {
    setState(() => _savingChannels = true);
    try {
      final channels = <String>['in_app'];
      if (_emailAlert.text.trim().isNotEmpty) channels.add('email');
      if (_mobile.text.trim().isNotEmpty) channels.add('sms');
      if (_whatsapp.text.trim().isNotEmpty) channels.add('whatsapp');
      await context.read<ApiService>().setNotificationPreferences(
        enabledChannels: channels,
        autonomousMode: _mode == _Mode.unleashed,
        autonomousProfile: _mode == _Mode.unleashed ? 'aggressive' : 'balanced',
        channelSettings: <String, dynamic>{
          'email_to': _emailAlert.text.trim(),
          'phone_number': _mobile.text.trim(),
          'whatsapp_number': _whatsapp.text.trim(),
        },
      );
      _lastSync = DateTime.now();
      _snack('Contact channels synced.', true);
    } catch (_) {
      _snack('Could not sync channels.', false);
    } finally {
      if (mounted) {
        setState(() => _savingChannels = false);
      }
    }
  }

  Future<void> _connectBroker() async {
    if (_brokerUser.text.trim().isEmpty || _brokerPass.text.isEmpty) {
      _snack('Enter Forex.com credentials first.', false);
      return;
    }
    setState(() => _connectingBroker = true);
    final provider = context.read<AccountConnectionProvider>();
    await provider.connectForexAccount(
        _brokerUser.text.trim(), _brokerPass.text);
    await provider.loadConnections();
    _brokerPass.clear();
    if (!mounted) return;
    setState(() => _connectingBroker = false);
    _snack(provider.lastError ?? 'Broker linked.', provider.lastError == null);
  }

  Future<void> _applyDirective() async {
    setState(() => _applying = true);
    final agent = context.read<AgentOrchestratorProvider>();
    final api = context.read<ApiService>();
    try {
      if (_mode == _Mode.rule) {
        final price = double.tryParse(_rulePrice.text.trim());
        if (price == null || price <= 0) {
          _snack('Enter a valid trigger price.', false);
          return;
        }
        final side = _side == _RuleSide.sell ? 'sell' : 'buy';
        final command =
            'Set rule: $side $_pair when price reaches ${price.toStringAsFixed(2)}.';
        await agent.submitCommand(command);
        await api.sendAutonomousStudyAlert(
          pair: _pair,
          userInstruction: command,
          priority: 'high',
        );
        _snack('Rule directive armed.', true);
      } else {
        if (!_riskAcknowledged) {
          _snack('Please acknowledge high-risk disclosure first.', false);
          return;
        }
        await agent
            .submitCommand('Enable full autonomy with 1% risk per trade');
        await agent.submitCommand('confirm command');
        _snack('Full autonomy request submitted.', true);
      }
    } catch (_) {
      _snack('Directive execution failed.', false);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor:
              ok ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
    );
  }

  String _asText(dynamic value) => value == null ? '' : value.toString().trim();
  String _mask(String input) => input.length < 7
      ? '***'
      : '${input.substring(0, 3)}***${input.substring(input.length - 3)}';

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>();
    final accounts = context.watch<AccountConnectionProvider>();
    final user = users.user;
    final account = accounts.selectedAccount;
    final revealed = !_maskSensitive || _unlocked;
    final score = (20 +
            ((_emailAlert.text.isNotEmpty ? 15 : 0) +
                (_mobile.text.isNotEmpty ? 15 : 0) +
                (_whatsapp.text.isNotEmpty ? 15 : 0) +
                ((account?.isConnected ?? false) ? 20 : 0) +
                (_maskSensitive ? 10 : 0) +
                (_mode == _Mode.rule ? 5 : 0)))
        .clamp(0, 100);
    if (!_syncedUser && user != null) {
      _name.text = user.name;
      _email.text = user.email;
      if (_emailAlert.text.isEmpty) _emailAlert.text = user.email;
      _syncedUser = true;
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(children: [
                IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white)),
                const Expanded(
                    child: Text('User Cum Admin Dashboard',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700))),
                _pill('FREE ACCESS', const Color(0xFF10B981))
              ]),
              _card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Security Posture',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: score / 100,
                        minHeight: 8,
                        color: score >= 75
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        backgroundColor: Colors.white24),
                    const SizedBox(height: 6),
                    Text(
                        'Score $score/100 | Plan: ${user?.plan.displayName ?? 'Free Plan'}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11))
                  ])),
              _card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _sectionTitle('1) Account Details'),
                    _field('Name', _name),
                    const SizedBox(height: 8),
                    _field('Email', _email, type: TextInputType.emailAddress),
                    const SizedBox(height: 8),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            onPressed: _savingProfile ? null : _saveProfile,
                            icon: _savingProfile
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.save_outlined),
                            label: const Text('Save Details'),
                            style: AppTheme.glassElevatedButtonStyle(
                                tintColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white)))
                  ])),
              _card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _sectionTitle('2) Forex.com Account & Credentials'),
                    Text(
                        'Linked: ${account == null ? 'Not linked' : (revealed ? account.accountNumber : _mask(account.accountNumber))}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 8),
                    _field('Forex.com Username', _brokerUser),
                    const SizedBox(height: 8),
                    _field('Forex.com Password', _brokerPass,
                        obscure: _obscurePass,
                        suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            icon: Icon(
                                _obscurePass
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                                size: 18))),
                    const SizedBox(height: 8),
                    Text('Password is never persisted locally.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: _connectingBroker ? null : _connectBroker,
                          icon: _connectingBroker
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.link),
                          label: const Text('Link Broker'),
                          style: AppTheme.glassElevatedButtonStyle(
                              tintColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white)),
                      OutlinedButton.icon(
                          onPressed: account == null
                              ? null
                              : () => accounts.disconnectAccount(account.id),
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor: const Color(0xFFEF4444),
                              foregroundColor: const Color(0xFFFCA5A5)))
                    ]),
                    if (accounts.lastError != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(accounts.lastError!,
                              style: const TextStyle(
                                  color: Color(0xFFFCA5A5), fontSize: 11)))
                  ])),
              _card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _sectionTitle('3) Directive Engine'),
                    SegmentedButton<_Mode>(
                      segments: const <ButtonSegment<_Mode>>[
                        ButtonSegment<_Mode>(
                          value: _Mode.rule,
                          label: Text('Rule-Based'),
                          icon: Icon(Icons.rule),
                        ),
                        ButtonSegment<_Mode>(
                          value: _Mode.unleashed,
                          label: Text('Unleashed AI'),
                          icon: Icon(Icons.bolt),
                        ),
                      ],
                      selected: <_Mode>{_mode},
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>(
                          (states) => states.contains(WidgetState.selected)
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.04),
                        ),
                        foregroundColor:
                            const WidgetStatePropertyAll<Color>(Colors.white),
                        side: WidgetStatePropertyAll<BorderSide>(
                          BorderSide(
                              color: Colors.white.withValues(alpha: 0.18)),
                        ),
                      ),
                      onSelectionChanged: (selection) {
                        setState(() => _mode = selection.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mode == _Mode.rule
                          ? 'Rule-based: e.g. sell dollar at 290 PKR'
                          : 'Fully unleashed AI control under guardrails.',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    if (_mode == _Mode.rule) ...[
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _dropdown<String>(
                            'Pair',
                            _pair,
                            const ['USD/PKR', 'EUR/USD', 'GBP/USD', 'USD/JPY'],
                            (v) => setState(() => _pair = v!)),
                        _dropdown<_RuleSide>('Action', _side, _RuleSide.values,
                            (v) => setState(() => _side = v!),
                            labeler: (v) =>
                                v == _RuleSide.sell ? 'SELL' : 'BUY')
                      ]),
                      const SizedBox(height: 8),
                      _field('Trigger Price', _rulePrice,
                          type: const TextInputType.numberWithOptions(
                              decimal: true))
                    ] else
                      CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _riskAcknowledged,
                          activeColor: const Color(0xFFEF4444),
                          title: const Text(
                              'I understand high-risk autonomous trading.',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 11)),
                          onChanged: (v) =>
                              setState(() => _riskAcknowledged = v == true)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: _applying ? null : _applyDirective,
                          icon: _applying
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.play_arrow),
                          label: const Text('Apply Directive'),
                          style: AppTheme.glassElevatedButtonStyle(
                              tintColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white)),
                      OutlinedButton.icon(
                          onPressed: context
                              .read<AgentOrchestratorProvider>()
                              .engageKillSwitch,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Emergency Stop'),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor: const Color(0xFFEF4444),
                              foregroundColor: const Color(0xFFFCA5A5)))
                    ])
                  ])),
              _card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _sectionTitle('4) Contacts (Email, Mobile, WhatsApp)'),
                    _field('Email', _emailAlert,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 8),
                    _field('Mobile', _mobile, type: TextInputType.phone),
                    const SizedBox(height: 8),
                    _field('WhatsApp', _whatsapp, type: TextInputType.phone),
                    const SizedBox(height: 8),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            onPressed: _loadingPrefs || _savingChannels
                                ? null
                                : _saveChannels,
                            icon: (_loadingPrefs || _savingChannels)
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.sync),
                            label: const Text('Sync Channels'),
                            style: AppTheme.glassElevatedButtonStyle(
                                tintColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white))),
                    if (_lastSync != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              'Last sync: ${_lastSync!.toIso8601String()}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 10)))
                  ])),
              _card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _sectionTitle('5) Security Shield'),
                    SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _maskSensitive,
                        title: const Text('Mask sensitive data by default',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                        subtitle: const Text(
                            'Recommended for secure admin access.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 10)),
                        onChanged: (v) => setState(() {
                              _maskSensitive = v;
                              if (!v) _unlocked = true;
                            }),
                        activeThumbColor: const Color(0xFF10B981)),
                    if (_maskSensitive && !_unlocked) ...[
                      _field('Session unlock phrase', _unlockPhrase,
                          obscure: true),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: () {
                            if (_unlockPhrase.text.trim().length < 4) {
                              _snack('Use at least 4 characters.', false);
                              return;
                            }
                            setState(() {
                              _unlocked = true;
                            });
                            _unlockPhrase.clear();
                            _snack('Session unlocked.', true);
                          },
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Unlock Session'),
                          style: AppTheme.glassElevatedButtonStyle(
                              tintColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white))
                    ] else if (_maskSensitive)
                      OutlinedButton(
                          onPressed: () => setState(() => _unlocked = false),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor: const Color(0xFFEF4444),
                              foregroundColor: const Color(0xFFFCA5A5)),
                          child: const Text('Lock Now'))
                  ])),
              _card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _sectionTitle('6) Subscription Rollout'),
                    Text('Current: ${user?.plan.displayName ?? 'Free Plan'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Phase 1: Free access for all users.',
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                    const Text('Phase 2: Enable \$10 signup subscription.',
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                    SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _premiumPreview,
                        activeThumbColor: const Color(0xFF3B82F6),
                        title: const Text(
                            'Enable \$10 paywall preview (UI only)',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                        onChanged: (v) => setState(() => _premiumPreview = v))
                  ])),
              if (_notice != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_notice!,
                        style: const TextStyle(
                            color: Color(0xFFFBBF24), fontSize: 11))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14));
  Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)));
  Widget _card({required Widget child}) => Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.03)
              ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
      child: child);

  Widget _field(String label, TextEditingController c,
          {TextInputType type = TextInputType.text,
          bool obscure = false,
          Widget? suffix}) =>
      TextField(
        controller: c,
        keyboardType: type,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.15))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)))),
      );

  Widget _dropdown<T>(
          String label, T value, List<T> items, ValueChanged<T?> onChanged,
          {String Function(T)? labeler}) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 145, maxWidth: 220),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: const Color(0xFF0B1220),
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.15))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.15))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)))),
          items: items
              .map((e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(labeler == null ? e.toString() : labeler(e),
                      overflow: TextOverflow.ellipsis)))
              .toList(),
        ),
      );
}
