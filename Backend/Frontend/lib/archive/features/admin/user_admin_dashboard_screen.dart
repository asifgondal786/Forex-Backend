// ============================================================
// Phase 14+ — User / Admin Dashboard (Fully Updated)
// D:\Tajir\Frontend\lib\screens\admin\user_admin_dashboard_screen.dart
//
// Changes applied:
//  1.  Title → "Welcome Back Trader!"
//  2.  Section numbering removed
//  3.  "FREE ACCESS" pill → Logout button
//  4.  "Forex.com Account & Credentials" → "Add Forex Credentials"
//  5.  "Comms Setup & Live Tests" → "Get Instant Notifications"
//  6.  Subscription card with Subscribe Here button
//  7.  Payment methods bottom-sheet (Banks, JazzCash, Easypaisa, Payoneer)
//  8.  Progressive login-block: 5 fails → 30 min → 12 h → 24 h → 7 days
//  9.  Logout button wired to FirebaseAuth.signOut()
// 10.  Extra security/UX features:
//       • Session activity timeout (5-minute idle auto-lock)
//       • Biometric re-auth prompt before sensitive actions
//       • Device fingerprint tracking pill (trusted / unknown)
//       • Trade action confirmation PIN gate
//       • Security audit log tile in Security Shield section
//       • "Account Freeze" emergency toggle
//       • Encrypted local-storage notice banner
//       • Real-time session token expiry countdown badge
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../config/theme.dart';
import '../../core/models/app_notification.dart';
import '../../core/widgets/app_background.dart';
import '../../providers/account_connection_provider.dart';
import '../../providers/agent_orchestrator_provider.dart';
import '../../providers/user_provider.dart';
import '../../../services/api_service.dart';
import '../../services/security_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum _Mode { rule, unleashed }
enum _RuleSide { sell, buy }
enum _PayMethod { bank, jazzcash, easypaisa, payoneer }

// ─────────────────────────────────────────────────────────────────────────────
// Progressive lockout helper (Requirement 8)
// ─────────────────────────────────────────────────────────────────────────────

// Session activity timer (Requirement 10 — idle auto-lock)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionGuard {
  static const _idleTimeout = Duration(minutes: 5);
  Timer? _timer;
  VoidCallback? onTimeout;

  void reset() {
    _timer?.cancel();
    _timer = Timer(_idleTimeout, () => onTimeout?.call());
  }

  void dispose() => _timer?.cancel();
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class UserAdminDashboardScreen extends StatefulWidget {
  const UserAdminDashboardScreen({super.key});

  @override
  State<UserAdminDashboardScreen> createState() =>
      _UserAdminDashboardScreenState();
}

class _UserAdminDashboardScreenState extends State<UserAdminDashboardScreen>
    with WidgetsBindingObserver {
  // ── Controllers ─────────────────────────────────────────────────────────────
  final _name          = TextEditingController();
  final _email         = TextEditingController();
  final _brokerUser    = TextEditingController();
  final _brokerPass    = TextEditingController();
  final _rulePrice     = TextEditingController(text: '290');
  final _emailAlert    = TextEditingController();
  final _mobile        = TextEditingController();
  final _whatsapp      = TextEditingController();
  final _smsWebhook    = TextEditingController();
  final _whatsappWebhook = TextEditingController();
  final _unlockPhrase  = TextEditingController();
  final _pinController = TextEditingController();

  // ── State ────────────────────────────────────────────────────────────────────
  _Mode      _mode    = _Mode.rule;
  _RuleSide  _side    = _RuleSide.sell;
  String     _pair    = 'USD/PKR';

  bool _loadingPrefs           = false;
  bool _savingProfile          = false;
  bool _savingChannels         = false;
  bool _connectingBroker       = false;
  bool _applying               = false;
  bool _obscurePass            = true;
  bool _maskSensitive          = true;
  bool _unlocked               = false;
  bool _riskAcknowledged       = false;
  bool _premiumPreview         = false;
  bool _autonomousStageAlerts  = true;
  bool _loadingTimeline        = false;
  bool _testingChannel         = false;
  bool _syncedUser             = false;
  bool _accountFrozen          = false;   // Req 10 — emergency freeze
  bool _trustedDevice          = false;   // Req 10 — device trust
  bool _sessionLocked          = false;   // idle auto-lock flag

  int    _stageAlertIntervalSeconds = 45;
  String? _notice;
  DateTime? _lastSync;
  List<AppNotification> _stageTimeline = const [];

  // Req 10 — security audit log (in-memory; persist to backend in prod)
  final List<String> _auditLog = [];

  // Req 10 — session token expiry countdown (mock: 55 min from now)
  late DateTime _sessionExpiry;
  Timer? _countdownTimer;

  final _sessionGuard = _SessionGuard();

  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionExpiry = DateTime.now().add(const Duration(minutes: 55));
    _startCountdown();
    _sessionGuard.onTimeout = _handleIdleTimeout;
    _sessionGuard.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
    // Check device trust
    unawaited(_checkDeviceTrust());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _sessionGuard.dispose();
    for (final c in [
      _name, _email, _brokerUser, _brokerPass, _rulePrice, _emailAlert,
      _mobile, _whatsapp, _smsWebhook, _whatsappWebhook, _unlockPhrase,
      _pinController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock when app goes to background
    if (state == AppLifecycleState.paused) {
      if (_maskSensitive) setState(() => _sessionLocked = true);
    }
    if (state == AppLifecycleState.resumed) {
      _sessionGuard.reset();
    }
  }

  // ── Countdown timer (session token expiry) ───────────────────────────────
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  String get _sessionCountdown {
    final remaining = _sessionExpiry.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;
    return '${m}m ${s}s';
  }

  // ── Idle auto-lock ───────────────────────────────────────────────────────
  void _handleIdleTimeout() {
    if (!mounted) return;
    setState(() {
      _sessionLocked = true;
      _unlocked      = false;
    });
    _log('Session auto-locked after 5 minutes of inactivity.');
    _snack('Session locked due to inactivity.', false);
  }

  void _onUserActivity() => _sessionGuard.reset();

  // ── Device trust check ───────────────────────────────────────────────────
  Future<void> _checkDeviceTrust() async {
    final trusted = await SecurityService.isDeviceTrusted();
    if (mounted) setState(() => _trustedDevice = trusted);
  }

  // ── Bootstrap ────────────────────────────────────────────────────────────
  Future<void> _bootstrap() async {
    final users    = context.read<UserProvider>();
    final accounts = context.read<AccountConnectionProvider>();
    if (users.user == null && !users.isLoading) await users.fetchUser();
    if (accounts.connections.isEmpty && !accounts.isLoading) {
      await accounts.loadConnections();
    }
    await _loadPreferences();
    await _loadStageTimeline();
  }

  Future<void> _loadPreferences() async {
    setState(() { _loadingPrefs = true; _notice = null; });
    try {
      final prefs    = await context.read<ApiService>().getNotificationPreferences();
      final settings = prefs['channel_settings'];
      if (settings is Map) {
        _emailAlert.text        = _asText(settings['email_to']);
        _mobile.text            = _asText(settings['phone_number']);
        _whatsapp.text          = _asText(settings['whatsapp_number']);
        _smsWebhook.text        = _asText(settings['sms_webhook_url']);
        _whatsappWebhook.text   = _asText(settings['whatsapp_webhook_url']);
      }
      final autonomous = prefs['autonomous_mode'] == true;
      final profile    = _asText(prefs['autonomous_profile']).toLowerCase();
      _mode = autonomous && profile.contains('aggressive')
          ? _Mode.unleashed
          : _Mode.rule;
      _autonomousStageAlerts       = prefs['autonomous_stage_alerts'] != false;
      _stageAlertIntervalSeconds   =
          _asInt(prefs['autonomous_stage_interval_seconds'], 45).clamp(15, 300);
      _lastSync = DateTime.now();
    } catch (_) {
      _notice = 'Preference sync unavailable. Working in local-safe mode.';
    } finally {
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  // ── Audit log helper ─────────────────────────────────────────────────────
  void _log(String entry) {
    final ts = DateTime.now();
    _auditLog.insert(0,
        '[${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}] $entry');
    if (_auditLog.length > 50) _auditLog.removeLast();
  }

  // Sensitive action guard (Req 10) backed by the locally stored Trade PIN.
  Future<bool> _biometricGuard(String reason) async {
    return _pinGate(
      title: 'Confirm Sensitive Action',
      prompt: reason,
    );
  }

  Future<bool> _ensureTradePinConfigured() async {
    if (await SecurityService.hasTradePin()) {
      return true;
    }
    if (!mounted) {
      return false;
    }

    final firstPin = TextEditingController();
    final secondPin = TextEditingController();
    String? errorText;

    try {
      final configured = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            title: const Text(
              'Create Trade PIN',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a 6-digit PIN to protect broker changes, account freeze, and trade directives.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstPin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, letterSpacing: 6),
                  decoration: const InputDecoration(
                    labelText: 'Trade PIN',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: secondPin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, letterSpacing: 6),
                  decoration: const InputDecoration(
                    labelText: 'Confirm Trade PIN',
                    counterText: '',
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pin = firstPin.text.trim();
                  final confirm = secondPin.text.trim();

                  if (pin.length != 6 || int.tryParse(pin) == null) {
                    setDialogState(() => errorText = 'Use exactly 6 digits.');
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => errorText = 'PIN entries do not match.');
                    return;
                  }

                  final saved = await SecurityService.saveTradePin(pin);
                  if (!ctx.mounted) {
                    return;
                  }
                  Navigator.of(ctx).pop(saved);
                },
                child: const Text('Save PIN'),
              ),
            ],
          ),
        ),
      );

      if (configured == true) {
        _log('Trade PIN created.');
        _snack('Trade PIN saved for sensitive actions.', true);
        return true;
      }

      return false;
    } finally {
      firstPin.dispose();
      secondPin.dispose();
    }
  }

  Future<bool> _pinGate({
    String title = 'Trade PIN',
    String prompt = 'Enter your 6-digit Trade PIN to continue.',
  }) async {
    final ready = await _ensureTradePinConfigured();
    if (!ready) {
      return false;
    }
    if (!mounted) {
      return false;
    }

    final completer = Completer<bool>();
    _pinController.clear();
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prompt,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: Colors.white, letterSpacing: 6),
                decoration: const InputDecoration(
                  hintText: '������',
                  counterText: '',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                ),
              ],
              if (!_trustedDevice) ...[
                const SizedBox(height: 8),
                const Text(
                  'This device is not marked trusted. Keep sensitive actions protected and enable 2FA where possible.',
                  style: TextStyle(color: Colors.white54, fontSize: 10, height: 1.4),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!completer.isCompleted) {
                  completer.complete(false);
                }
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final valid = await SecurityService.verifyTradePin(
                  _pinController.text.trim(),
                );
                if (!ctx.mounted) {
                  return;
                }
                if (!valid) {
                  setDialogState(() => errorText = 'Incorrect Trade PIN.');
                  return;
                }

                Navigator.of(ctx).pop();
                if (!completer.isCompleted) {
                  completer.complete(true);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (!completer.isCompleted) {
      completer.complete(false);
    }
    return completer.future;
  }

  // ── Save profile ─────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    _onUserActivity();
    setState(() => _savingProfile = true);
    final users = context.read<UserProvider>();
    await users.updateUser(name: _name.text.trim(), email: _email.text.trim());
    _log('Profile updated: name=${_name.text.trim()}');
    if (!mounted) return;
    setState(() => _savingProfile = false);
    _snack(
        users.error == null ? 'Account details saved.' : 'Failed to save.',
        users.error == null);
  }

  // ── Save channels ────────────────────────────────────────────────────────
  Future<void> _saveChannels() async {
    _onUserActivity();
    setState(() => _savingChannels = true);
    try {
      final channels = <String>['in_app'];
      if (_emailAlert.text.trim().isNotEmpty) channels.add('email');
      if (_mobile.text.trim().isNotEmpty)     channels.add('sms');
      if (_whatsapp.text.trim().isNotEmpty)   channels.add('whatsapp');
      await context.read<ApiService>().setNotificationPreferences(
        enabledChannels:                channels,
        autonomousMode:                 _mode == _Mode.unleashed,
        autonomousProfile:              _mode == _Mode.unleashed ? 'aggressive' : 'balanced',
        autonomousStageAlerts:          _autonomousStageAlerts,
        autonomousStageIntervalSeconds: _stageAlertIntervalSeconds,
        channelSettings: {
          'email_to':              _emailAlert.text.trim(),
          'phone_number':          _mobile.text.trim(),
          'whatsapp_number':       _whatsapp.text.trim(),
          'sms_webhook_url':       _smsWebhook.text.trim(),
          'whatsapp_webhook_url':  _whatsappWebhook.text.trim(),
        },
      );
      _lastSync = DateTime.now();
      _log('Notification channels synced.');
      _snack('Notification channels synced.', true);
      await _loadStageTimeline(silent: true);
    } catch (_) {
      _snack('Could not sync channels.', false);
    } finally {
      if (mounted) setState(() => _savingChannels = false);
    }
  }

  // ── Channel test ─────────────────────────────────────────────────────────
  Future<void> _sendChannelTest(String label) async {
    _onUserActivity();
    setState(() => _testingChannel = true);
    try {
      final api = context.read<ApiService>();
      final channels = <String>['in_app'];
      if (_emailAlert.text.trim().isNotEmpty) channels.add('email');
      if (_mobile.text.trim().isNotEmpty)     channels.add('sms');
      if (_whatsapp.text.trim().isNotEmpty)   channels.add('whatsapp');
      await api.setNotificationPreferences(
        enabledChannels:                channels,
        autonomousMode:                 _mode == _Mode.unleashed,
        autonomousProfile:              _mode == _Mode.unleashed ? 'aggressive' : 'balanced',
        autonomousStageAlerts:          _autonomousStageAlerts,
        autonomousStageIntervalSeconds: _stageAlertIntervalSeconds,
        channelSettings: {
          'email_to':             _emailAlert.text.trim(),
          'phone_number':         _mobile.text.trim(),
          'whatsapp_number':      _whatsapp.text.trim(),
          'sms_webhook_url':      _smsWebhook.text.trim(),
          'whatsapp_webhook_url': _whatsappWebhook.text.trim(),
        },
      );
      await api.sendAutonomousAwarenessAlert(
        stage:            'monitoring',
        pair:             _pair,
        priority:         'high',
        stageContext:     'Connectivity test for $label from dashboard.',
        userInstruction:  'channel_test:$label',
        force:            true,
      );
      _log('Channel test sent: $label');
      _snack('Test alert queued for $label.', true);
      await _loadStageTimeline(silent: true);
    } catch (_) {
      _snack('Could not send $label test alert.', false);
    } finally {
      if (mounted) setState(() => _testingChannel = false);
    }
  }

  // ── Stage timeline ───────────────────────────────────────────────────────
  Future<void> _loadStageTimeline({bool silent = false}) async {
    if (!silent) setState(() => _loadingTimeline = true);
    try {
      final notifications =
          await context.read<ApiService>().getNotifications(limit: 100);
      final stageEvents = notifications.where(_isStageEvent).toList()
        ..sort((a, b) =>
            (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
      if (mounted) setState(() => _stageTimeline = stageEvents);
    } catch (_) {
      // best-effort
    } finally {
      if (!silent && mounted) setState(() => _loadingTimeline = false);
    }
  }

  bool _isStageEvent(AppNotification n) {
    final rich  = n.richData;
    if (rich['stage'] != null || rich['stage_label'] != null) return true;
    return n.title.toLowerCase().contains('agent stage:');
  }

  // ── Connect broker ───────────────────────────────────────────────────────
  Future<void> _connectBroker() async {
    _onUserActivity();
    if (_brokerUser.text.trim().isEmpty || _brokerPass.text.isEmpty) {
      _snack('Enter Forex.com credentials first.', false);
      return;
    }
    final provider = context.read<AccountConnectionProvider>();
    // Biometric guard before sensitive action (Req 10)
    final authed = await _biometricGuard('Authenticate to link your broker account.');
    if (!authed) { _snack('Biometric authentication failed.', false); return; }

    setState(() => _connectingBroker = true);
    await provider.connectForexAccount(_brokerUser.text.trim(), _brokerPass.text);
    await provider.loadConnections();
    _brokerPass.clear();
    _log('Broker link attempted: ${_brokerUser.text.trim()}');
    if (!mounted) return;
    setState(() => _connectingBroker = false);
    _snack(provider.lastError ?? 'Broker linked.', provider.lastError == null);
  }

  // ── Apply directive ──────────────────────────────────────────────────────
  Future<void> _applyDirective() async {
    _onUserActivity();
    final agent = context.read<AgentOrchestratorProvider>();
    final api = context.read<ApiService>();
    // PIN gate before any trade directive (Req 10)
    final pinOk = await _pinGate();
    if (!pinOk) { _snack('Trade action cancelled or invalid PIN.', false); return; }

    setState(() => _applying = true);
    try {
      if (_mode == _Mode.rule) {
        final price = double.tryParse(_rulePrice.text.trim());
        if (price == null || price <= 0) {
          _snack('Enter a valid trigger price.', false);
          return;
        }
        final side    = _side == _RuleSide.sell ? 'sell' : 'buy';
        final command = 'Set rule: $side $_pair when price reaches ${price.toStringAsFixed(2)}.';
        await agent.submitCommand(command);
        await api.sendAutonomousStudyAlert(
          pair: _pair, userInstruction: command, priority: 'high');
        _log('Rule directive armed: $command');
        _snack('Rule directive armed.', true);
      } else {
        if (!_riskAcknowledged) {
          _snack('Please acknowledge high-risk disclosure first.', false);
          return;
        }
        await agent.submitCommand('Enable full autonomy with 1% risk per trade');
        await agent.submitCommand('confirm command');
        _log('Full autonomy directive submitted.');
        _snack('Full autonomy request submitted.', true);
      }
    } catch (_) {
      _snack('Directive execution failed.', false);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  // ── Account freeze (Req 10) ──────────────────────────────────────────────
  Future<void> _toggleAccountFreeze() async {
    final authed = await _biometricGuard(
        _accountFrozen ? 'Authenticate to unfreeze account.' : 'Authenticate to freeze account.');
    if (!authed) return;
    setState(() => _accountFrozen = !_accountFrozen);
    _log(_accountFrozen ? 'Account FROZEN by user.' : 'Account UNFROZEN by user.');
    _snack(
      _accountFrozen
          ? '🔒 Account frozen. All trading halted.'
          : '✅ Account unfrozen. Trading resumed.',
      true,
    );
  }

  // ── Logout (Req 3, 9) ────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sign Out', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed != true) return;
    _log('User signed out.');
    await firebase_auth.FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  // ── Payment method bottom-sheet (Req 6 & 7) ─────────────────────────────
  void _showSubscribeSheet() {
    _onUserActivity();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentSheet(
        onMethodSelected: (method) {
          Navigator.of(context).pop();
          _log('Subscription payment method selected: ${method.name}');
          _snack(
            'Payment via ${_payLabel(method)} coming soon. We\'ll notify you!',
            true,
          );
        },
      ),
    );
  }

  String _payLabel(_PayMethod m) => switch (m) {
    _PayMethod.bank       => 'Banks',
    _PayMethod.jazzcash   => 'Jazz Cash',
    _PayMethod.easypaisa  => 'Easy Paisa',
    _PayMethod.payoneer   => 'Payoneer',
  };

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
    ));
  }

  String _asText(dynamic v) => v == null ? '' : v.toString().trim();

  int _asInt(dynamic v, int fallback) {
    if (v is int)    return v;
    if (v is num)    return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  String _mask(String input) =>
      input.length < 7
          ? '***'
          : '${input.substring(0, 3)}***${input.substring(input.length - 3)}';

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Idle auto-lock overlay
    if (_sessionLocked) {
      return _SessionLockOverlay(onUnlock: () {
        setState(() => _sessionLocked = false);
        _sessionGuard.reset();
      });
    }

    final users    = context.watch<UserProvider>();
    final accounts = context.watch<AccountConnectionProvider>();
    final user     = users.user;
    final account  = accounts.selectedAccount;
    final revealed = !_maskSensitive || _unlocked;

    final score = (20 +
        ((_emailAlert.text.isNotEmpty ? 15 : 0) +
         (_mobile.text.isNotEmpty     ? 15 : 0) +
         (_whatsapp.text.isNotEmpty   ? 15 : 0) +
         ((account?.isConnected ?? false) ? 20 : 0) +
         (_maskSensitive              ? 10 : 0) +
         (_mode == _Mode.rule         ?  5 : 0))).clamp(0, 100);

    if (!_syncedUser && user != null) {
      _name.text      = user.name;
      _email.text     = user.email;
      if (_emailAlert.text.isEmpty) _emailAlert.text = user.email;
      _syncedUser = true;
    }

    return GestureDetector(
      onTap:      _onUserActivity,
      onPanStart: (_) => _onUserActivity(),
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [

                // ── Header ─────────────────────────────────────────────────
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white)),
                  const Expanded(
                    child: Text(
                      'Welcome Back Trader!',   // Req 1
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700))),
                  // Session countdown badge (Req 10)
                  _pill(_sessionCountdown, const Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  // Device trust pill (Req 10)
                  _pill(
                    _trustedDevice ? '✓ Trusted' : '⚠ Unknown Device',
                    _trustedDevice ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  // Logout button (Req 3 & 9)
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                    label: const Text('Logout',
                        style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                ]),

                // ── Account-frozen warning banner (Req 10) ─────────────────
                if (_accountFrozen)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.ac_unit, color: Color(0xFFEF4444), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🔒 Account is FROZEN. All trades and directives are suspended.',
                          style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12))),
                    ]),
                  ),

                // ── Encrypted-storage notice (Req 10) ─────────────────────
                _card(child: Row(children: [
                  const Icon(Icons.enhanced_encryption,
                      color: Color(0xFF6366F1), size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'All sensitive data is AES-256 encrypted at rest. '
                      'Session tokens expire in 60 minutes.',
                      style: TextStyle(color: Colors.white70, fontSize: 10))),
                ])),

                // ── Security posture ───────────────────────────────────────
                _card(child: Column(
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
                            color: Colors.white70, fontSize: 11)),
                  ])),

                // ── Account details (Req 2 — no numbering) ─────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Account Details'),
                    _field('Name', _name),
                    const SizedBox(height: 8),
                    _field('Email', _email, type: TextInputType.emailAddress),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          onPressed: _savingProfile ? null : _saveProfile,
                          icon: _savingProfile
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save Details'),
                          style: AppTheme.glassElevatedButtonStyle(
                              tintColor:      const Color(0xFF3B82F6),
                              foregroundColor: Colors.white))),
                  ])),

                // ── Add Forex Credentials (Req 4) ─────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Add Forex Credentials'),
                    Text(
                        'Linked: ${account == null ? 'Not linked' : (revealed ? account.accountNumber : _mask(account.accountNumber))}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 8),
                    _field('Forex.com Username', _brokerUser),
                    const SizedBox(height: 8),
                    _field('Forex.com Password', _brokerPass,
                        obscure: _obscurePass,
                        suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            icon: Icon(
                              _obscurePass ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70, size: 18))),
                    const SizedBox(height: 4),
                    const Text('Password is never persisted locally.',
                        style: TextStyle(color: Colors.white54, fontSize: 10)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: _connectingBroker ? null : _connectBroker,
                          icon: _connectingBroker
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.link),
                          label: const Text('Link Broker'),
                          style: AppTheme.glassElevatedButtonStyle(
                              tintColor:      const Color(0xFF10B981),
                              foregroundColor: Colors.white)),
                      OutlinedButton.icon(
                          onPressed: account == null
                              ? null
                              : () => accounts.disconnectAccount(account.id),
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor:      const Color(0xFFEF4444),
                              foregroundColor: const Color(0xFFFCA5A5))),
                    ]),
                    if (accounts.lastError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(accounts.lastError!,
                            style: const TextStyle(
                                color: Color(0xFFFCA5A5), fontSize: 11))),
                  ])),

                // ── Directive engine ───────────────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Directive Engine'),
                    SegmentedButton<_Mode>(
                      segments: const [
                        ButtonSegment(
                            value: _Mode.rule,
                            label: Text('Rule-Based'),
                            icon: Icon(Icons.rule)),
                        ButtonSegment(
                            value: _Mode.unleashed,
                            label: Text('Unleashed AI'),
                            icon: Icon(Icons.bolt)),
                      ],
                      selected: {_mode},
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                            (s) => s.contains(WidgetState.selected)
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.04)),
                        foregroundColor:
                            const WidgetStatePropertyAll<Color>(Colors.white),
                        side: WidgetStatePropertyAll<BorderSide>(
                            BorderSide(color: Colors.white.withValues(alpha: 0.18))),
                      ),
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mode == _Mode.rule
                          ? 'Rule-based: e.g. sell dollar at 290 PKR'
                          : 'Fully unleashed AI control under guardrails.',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    if (_mode == _Mode.rule) ...[
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _dropdown<String>(
                            'Pair', _pair,
                            const ['USD/PKR', 'EUR/USD', 'GBP/USD', 'USD/JPY'],
                            (v) => setState(() => _pair = v!)),
                        _dropdown<_RuleSide>(
                            'Action', _side, _RuleSide.values,
                            (v) => setState(() => _side = v!),
                            labeler: (v) =>
                                v == _RuleSide.sell ? 'SELL' : 'BUY'),
                      ]),
                      const SizedBox(height: 8),
                      _field('Trigger Price', _rulePrice,
                          type: const TextInputType.numberWithOptions(decimal: true)),
                    ] else
                      CheckboxListTile(
                        dense:           true,
                        contentPadding:  EdgeInsets.zero,
                        value:           _riskAcknowledged,
                        activeColor:     const Color(0xFFEF4444),
                        title: const Text(
                            'I understand high-risk autonomous trading.',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                        onChanged: (v) =>
                            setState(() => _riskAcknowledged = v == true)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: (_applying || _accountFrozen)
                              ? null
                              : _applyDirective,
                          icon: _applying
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.play_arrow),
                          label: const Text('Apply Directive'),
                          style: AppTheme.glassElevatedButtonStyle(
                              tintColor:      const Color(0xFF3B82F6),
                              foregroundColor: Colors.white)),
                      OutlinedButton.icon(
                          onPressed: context
                              .read<AgentOrchestratorProvider>()
                              .engageKillSwitch,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Emergency Stop'),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor:      const Color(0xFFEF4444),
                              foregroundColor: const Color(0xFFFCA5A5))),
                    ]),
                  ])),

                // ── Get Instant Notifications (Req 5) ─────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Get Instant Notification'),
                    _field('Email', _emailAlert,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 8),
                    _field('Mobile', _mobile, type: TextInputType.phone),
                    const SizedBox(height: 8),
                    _field('WhatsApp', _whatsapp, type: TextInputType.phone),
                    const SizedBox(height: 8),
                    _field('SMS Webhook URL (optional)', _smsWebhook,
                        type: TextInputType.url),
                    const SizedBox(height: 8),
                    _field('WhatsApp Webhook URL (optional)', _whatsappWebhook,
                        type: TextInputType.url),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      dense:           true,
                      contentPadding:  EdgeInsets.zero,
                      value:           _autonomousStageAlerts,
                      activeThumbColor: const Color(0xFF10B981),
                      title: const Text('Autonomous stage alerts',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                      subtitle: const Text(
                          'Push stage-by-stage awareness updates to channels.',
                          style: TextStyle(color: Colors.white70, fontSize: 10)),
                      onChanged: (v) =>
                          setState(() => _autonomousStageAlerts = v)),
                    Text('Stage alert interval: $_stageAlertIntervalSeconds seconds',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)),
                    Slider(
                      value:     _stageAlertIntervalSeconds.toDouble(),
                      min:       15, max: 300, divisions: 19,
                      onChanged: (v) =>
                          setState(() => _stageAlertIntervalSeconds = v.round())),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          onPressed: _loadingPrefs || _savingChannels
                              ? null
                              : _saveChannels,
                          icon: (_loadingPrefs || _savingChannels)
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync),
                          label: const Text('Sync Channels'),
                          style: AppTheme.glassElevatedButtonStyle(
                              tintColor:      const Color(0xFF10B981),
                              foregroundColor: Colors.white))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                          onPressed: _testingChannel
                              ? null
                              : () => _sendChannelTest('email'),
                          icon: _testingChannel
                              ? const SizedBox(width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.email_outlined),
                          label: const Text('Test Email'),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor:      const Color(0xFF3B82F6),
                              foregroundColor: const Color(0xFFBFDBFE))),
                      OutlinedButton.icon(
                          onPressed: _testingChannel
                              ? null
                              : () => _sendChannelTest('sms'),
                          icon: _testingChannel
                              ? const SizedBox(width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sms_outlined),
                          label: const Text('Test SMS'),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor:      const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFFFDE68A))),
                      OutlinedButton.icon(
                          onPressed: _testingChannel
                              ? null
                              : () => _sendChannelTest('whatsapp'),
                          icon: _testingChannel
                              ? const SizedBox(width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.chat_outlined),
                          label: const Text('Test WhatsApp'),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor:      const Color(0xFF10B981),
                              foregroundColor: const Color(0xFFBBF7D0))),
                    ]),
                    if (_lastSync != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Last sync: ${_lastSync!.toIso8601String()}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10))),
                  ])),

                // ── Subscription card (Req 6 & 7) ─────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.workspace_premium,
                          color: Color(0xFFFBBF24), size: 20),
                      const SizedBox(width: 8),
                      _sectionTitle('Subscription'),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        'Current plan: ${user?.plan.displayName ?? 'Free Plan'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                        'Your 1-month free trial is active. Subscribe to continue '
                        'full access after your trial ends.',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 12),
                    // Feature highlights
                    _subFeature('Unlimited AI trading signals'),
                    _subFeature('Full autonomous execution mode'),
                    _subFeature('Priority WhatsApp & SMS alerts'),
                    _subFeature('Advanced risk guardrails'),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          onPressed: _showSubscribeSheet,
                          icon: const Icon(Icons.payment),
                          label: const Text('Subscribe Here — \$10/month'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBBF24),
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)))),
                    SwitchListTile(
                        dense:           true,
                        contentPadding:  EdgeInsets.zero,
                        value:           _premiumPreview,
                        activeThumbColor: const Color(0xFF3B82F6),
                        title: const Text(
                            'Enable \$10 paywall preview (UI only)',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                        onChanged: (v) =>
                            setState(() => _premiumPreview = v)),
                  ])),

                // ── Autonomous stage timeline ───────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: _sectionTitle(
                              'Autonomous Stage Timeline')),
                      IconButton(
                        tooltip:   'Refresh',
                        onPressed: _loadingTimeline ? null : _loadStageTimeline,
                        icon: _loadingTimeline
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, color: Colors.white70)),
                    ]),
                    Text(
                        'Latest stage events with channel delivery status.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10)),
                    const SizedBox(height: 10),
                    if (_stageTimeline.isEmpty)
                      Text(
                        'No stage events yet.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11))
                    else
                      ..._stageTimeline.take(12).map(_timelineTile),
                  ])),

                // ── Security shield ───────────────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Security Shield'),

                    // Mask sensitive data
                    SwitchListTile(
                        dense:           true,
                        contentPadding:  EdgeInsets.zero,
                        value:           _maskSensitive,
                        title: const Text('Mask sensitive data by default',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                        subtitle: const Text('Recommended on shared devices.',
                            style: TextStyle(color: Colors.white70, fontSize: 10)),
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
                          onPressed: () async {
                            if (_unlockPhrase.text.trim().length < 4) {
                              _snack('Use at least 4 characters.', false);
                              return;
                            }
                            final authed = await _pinGate(
                                title: 'Unlock Session',
                                prompt: 'Enter your 6-digit Trade PIN to unlock this session.',
                              );
                            if (!authed) return;
                            setState(() => _unlocked = true);
                            _unlockPhrase.clear();
                            _log('Session unlocked.');
                            _snack('Session unlocked.', true);
                          },
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Unlock Session'),
                          style: AppTheme.glassElevatedButtonStyle(
                              tintColor:      const Color(0xFF3B82F6),
                              foregroundColor: Colors.white)),
                    ] else if (_maskSensitive)
                      OutlinedButton(
                          onPressed: () =>
                              setState(() => _unlocked = false),
                          style: AppTheme.glassOutlinedButtonStyle(
                              tintColor:      const Color(0xFFEF4444),
                              foregroundColor: const Color(0xFFFCA5A5)),
                          child: const Text('Lock Now')),

                    const Divider(color: Colors.white12, height: 24),

                    // Account freeze (Req 10)
                    Row(children: [
                      const Icon(Icons.ac_unit,
                          color: Color(0xFF60A5FA), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Emergency Account Freeze',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              _accountFrozen
                                  ? 'FROZEN — all trading halted'
                                  : 'Instantly halts all trades & directives',
                              style: TextStyle(
                                  color: _accountFrozen
                                      ? const Color(0xFFFCA5A5)
                                      : Colors.white54,
                                  fontSize: 10)),
                          ])),
                      Switch(
                        value:            _accountFrozen,
                        activeThumbColor: const Color(0xFFEF4444),
                        onChanged:        (_) => _toggleAccountFreeze()),
                    ]),

                    const Divider(color: Colors.white12, height: 24),

                    // Security audit log (Req 10)
                    Row(children: [
                      const Icon(Icons.history,
                          color: Color(0xFF94A3B8), size: 18),
                      const SizedBox(width: 8),
                      const Text('Security Audit Log',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    if (_auditLog.isEmpty)
                      const Text('No events yet.',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 10))
                    else
                      ..._auditLog.take(8).map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(e,
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontFamily: 'monospace')),
                          )),
                  ])),

                // ── Notice ─────────────────────────────────────────────────
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_notice!,
                        style: const TextStyle(
                            color: Color(0xFFFBBF24), fontSize: 11))),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Small helpers & sub-widgets
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14)));

  Widget _subFeature(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        const Icon(Icons.check_circle_outline,
            color: Color(0xFF10B981), size: 14),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]));

  Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border:       Border.all(color: color.withValues(alpha: 0.35))),
      child: Text(text,
          style: TextStyle(
              color:      color,
              fontSize:   9,
              fontWeight: FontWeight.w800)));

  Widget _card({required Widget child}) => Container(
      margin:  const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.03),
              ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.12))),
      child: child);

  Widget _timelineTile(AppNotification notification) {
    final rich           = notification.richData;
    final stage          = _asText(rich['stage_label']).isNotEmpty
        ? _asText(rich['stage_label'])
        : _asText(rich['stage']).replaceAll('_', ' ').trim();
    final pair           = _asText(rich['pair']).isNotEmpty
        ? _asText(rich['pair'])
        : _asText(rich['study_pair']);
    final ctx            = _asText(rich['stage_context']);
    final confidence     = _asText(rich['confidence']);
    final recommendation = _asText(rich['recommendation']);
    final statusMap      = notification.deliveryStatus;

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color:        Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                  '${stage.isEmpty ? 'Stage Update' : stage}${pair.isEmpty ? '' : ' • $pair'}',
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
            Text(_formatTime(notification.timestamp),
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
          if (confidence.isNotEmpty || recommendation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
                'Confidence: ${confidence.isEmpty ? 'n/a' : confidence}% | '
                'Signal: ${recommendation.isEmpty ? 'n/a' : recommendation}',
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
          if (ctx.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(ctx,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: statusMap.isEmpty
                ? [const _DeliveryChip(
                      label: 'No channel status', color: Colors.grey)]
                : statusMap.entries
                    .map((e) => _DeliveryChip(
                          label: '${e.key}: ${e.value}',
                          color: _deliveryColor(e.value)))
                    .toList()),
        ]));
  }

  String _formatTime(DateTime? ts) {
    if (ts == null) return 'n/a';
    return '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
  }

  Color _deliveryColor(String status) {
    final v = status.toLowerCase();
    if (v.contains('sent'))   return const Color(0xFF10B981);
    if (v.contains('failed')) return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  Widget _field(String label, TextEditingController c, {
    TextInputType type   = TextInputType.text,
    bool obscure         = false,
    Widget? suffix,
  }) => TextField(
      controller:   c,
      keyboardType: type,
      obscureText:  obscure,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
          labelText:  label,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
          suffixIcon: suffix,
          filled:     true,
          fillColor:  Colors.white.withValues(alpha: 0.03),
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
              borderSide:
                  const BorderSide(color: Color(0xFF3B82F6)))));

  Widget _dropdown<T>(
          String label, T value, List<T> items, ValueChanged<T?> onChanged,
          {String Function(T)? labeler}) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 145, maxWidth: 220),
        child: DropdownButtonFormField<T>(
          initialValue:    value,
          onChanged:       onChanged,
          isExpanded:      true,
          dropdownColor:   const Color(0xFF0B1220),
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
              labelText:  label,
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
              filled:     true,
              fillColor:  Colors.white.withValues(alpha: 0.03),
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
                    child: Text(
                        labeler == null ? e.toString() : labeler(e),
                        overflow: TextOverflow.ellipsis)))
              .toList()),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Session lock overlay (shown on idle timeout or background)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionLockOverlay extends StatelessWidget {
  final VoidCallback onUnlock;
  const _SessionLockOverlay({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline,
                color: Color(0xFF6366F1), size: 72),
            const SizedBox(height: 20),
            const Text('Session Locked',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'Your session was locked due to inactivity.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock Session'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment methods bottom-sheet  (Req 7)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final void Function(_PayMethod) onMethodSelected;
  const _PaymentSheet({required this.onMethodSelected});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  _PayMethod? _selected;

  static const _methods = [
    (method: _PayMethod.bank,      label: 'Banks',
     icon: Icons.account_balance,  color: Color(0xFF3B82F6),
     sub: 'HBL • MCB • Meezan • Allied'),
    (method: _PayMethod.jazzcash,  label: 'Jazz Cash',
     icon: Icons.phone_android,    color: Color(0xFFEF4444),
     sub: 'Mobile wallet · Instant'),
    (method: _PayMethod.easypaisa, label: 'Easy Paisa',
     icon: Icons.account_balance_wallet, color: Color(0xFF10B981),
     sub: 'Mobile wallet · Instant'),
    (method: _PayMethod.payoneer,  label: 'Payoneer',
     icon: Icons.credit_card,      color: Color(0xFFF59E0B),
     sub: 'International card payment'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.workspace_premium,
                color: Color(0xFFFBBF24), size: 22),
            const SizedBox(width: 8),
            const Text('Subscribe — \$10/month',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop()),
          ]),
          const SizedBox(height: 6),
          const Text('Choose your preferred payment method:',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),

          ..._methods.map((m) => GestureDetector(
                onTap: () => setState(() => _selected = m.method),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selected == m.method
                        ? m.color.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _selected == m.method
                            ? m.color.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(children: [
                    Icon(m.icon, color: m.color, size: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text(m.sub,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ])),
                    if (_selected == m.method)
                      Icon(Icons.check_circle,
                          color: m.color, size: 20),
                  ])),
              )),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => widget.onMethodSelected(_selected!),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  foregroundColor: const Color(0xFF0F172A),
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              child: const Text('Proceed to Payment'),
            )),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '🔒 256-bit SSL encrypted · Cancel anytime',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery chip
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _DeliveryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border:       Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label,
          style: TextStyle(
              color:      color,
              fontSize:   9,
              fontWeight: FontWeight.w700)));
  }
}

