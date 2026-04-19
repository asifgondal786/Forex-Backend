// lib/features/settings/connect_broker_sheet.dart
//
// Bottom sheet for connecting an OANDA live trading account.
// Posts credentials to /v1/api/accounts/connect/forex.
// On success: updates AccountConnectionProvider → home card shows live balance.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/account_connection_provider.dart';
import '../../services/api_service.dart';

class ConnectBrokerSheet extends StatefulWidget {
  const ConnectBrokerSheet({super.key});

  /// Convenience launcher — call from any screen.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF161D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ConnectBrokerSheet(),
    );
  }

  @override
  State<ConnectBrokerSheet> createState() => _ConnectBrokerSheetState();
}

class _ConnectBrokerSheetState extends State<ConnectBrokerSheet> {
  // palette
  static const _kCard    = Color(0xFF161D2E);
  static const _kBorder  = Color(0xFF1E2A3D);
  static const _kGold    = Color(0xFFD4A853);
  static const _kGreen   = Color(0xFF00C896);
  static const _kRed     = Color(0xFFFF4560);
  static const _kText    = Color(0xFFE2E8F0);
  static const _kSubtext = Color(0xFF64748B);

  final _formKey    = GlobalKey<FormState>();
  final _apiKeyCtrl = TextEditingController();
  final _acctCtrl   = TextEditingController();

  bool _obscureKey  = true;
  bool _isLoading   = false;
  String? _error;
  bool _success     = false;

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _acctCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      final api      = context.read<ApiService>();
      final provider = context.read<AccountConnectionProvider>();

      // connectForexAccount maps to POST /v1/api/accounts/connect/forex
      // username = OANDA Account ID, password = API Key
      // (matches backend expectation per roadmap)
      final connection = await api.connectForexAccount(
        _acctCtrl.text.trim(),
        _apiKeyCtrl.text.trim(),
      );

      // Update provider so HomeScreen live balance card refreshes
      await provider.loadConnections();

      setState(() {
        _success   = true;
        _isLoading = false;
      });

      // Auto-close after brief success display
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error     = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: _kGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect Broker',
                      style: TextStyle(
                        color: _kText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'OANDA live trading account',
                      style: TextStyle(color: _kSubtext, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Success state ────────────────────────────────────────────
            if (_success) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF003D2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _kGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: _kGreen, size: 36),
                    SizedBox(height: 10),
                    Text(
                      'Broker connected successfully',
                      style: TextStyle(
                        color: _kGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your live balance will appear on the home screen.',
                      style: TextStyle(color: _kSubtext, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── OANDA Account ID ─────────────────────────────────────────
            _FieldLabel('OANDA Account ID'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _acctCtrl,
              style: const TextStyle(color: _kText, fontSize: 14),
              decoration: _inputDeco(
                hint: '001-001-12345678-001',
                icon: Icons.badge_outlined,
              ),
              keyboardType: TextInputType.text,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Account ID is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ── OANDA API Key ────────────────────────────────────────────
            _FieldLabel('OANDA API Key'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _apiKeyCtrl,
              style: const TextStyle(color: _kText, fontSize: 14),
              obscureText: _obscureKey,
              decoration: _inputDeco(
                hint: 'Paste your OANDA v20 API key',
                icon: Icons.key_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _kSubtext,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              autocorrect: false,
              enableSuggestions: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'API key is required';
                }
                if (v.trim().length < 20) {
                  return 'API key looks too short — check and try again';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // ── Security note ────────────────────────────────────────────
            Row(
              children: const [
                Icon(Icons.lock_outline_rounded, color: _kSubtext, size: 12),
                SizedBox(width: 6),
                Text(
                  'Credentials are encrypted and stored per-user in Supabase.',
                  style: TextStyle(color: _kSubtext, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Error ────────────────────────────────────────────────────
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D0010),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _kRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: _kRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Connect button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _connect,
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  disabledBackgroundColor: _kGold.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Connect Account',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // ── How to get API key ────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: () {
                  // openLink handled by host — launches OANDA API key page
                },
                child: const Text(
                  'How to get an OANDA API key →',
                  style: TextStyle(color: _kSubtext, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _FieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: _kSubtext,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kSubtext, fontSize: 13),
        prefixIcon: Icon(icon, color: _kSubtext, size: 18),
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _kRed, fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}
