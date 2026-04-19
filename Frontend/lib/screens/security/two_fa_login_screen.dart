// ============================================================
// Phase 14 — 2FA Login Screen
// D:\Tajir\Frontend\lib\screens\security\two_fa_login_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import '../../services/security_service.dart';

class TwoFALoginScreen extends StatefulWidget {
  /// Called after successful 2FA verification
  final VoidCallback onVerified;

  const TwoFALoginScreen({super.key, required this.onVerified});

  @override
  State<TwoFALoginScreen> createState() => _TwoFALoginScreenState();
}

class _TwoFALoginScreenState extends State<TwoFALoginScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  int _attempts = 0;

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() => _loading = true);
    final success = await SecurityService.confirmLogin2FA(code);
    setState(() => _loading = false);

    if (success) {
      // Ask user if they want to trust this device
      _showTrustDeviceDialog();
    } else {
      _attempts++;
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_attempts >= 3
            ? 'Multiple failed attempts. Check your authenticator app.'
            : 'Invalid code. Try again.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showTrustDeviceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Trust This Device?'),
        content: const Text(
            'Skip 2FA on this device for 30 days. Only do this on your personal device.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onVerified();
            },
            child: const Text('No, ask every time'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await SecurityService.registerTrustedDevice(trustDays: 30);
              widget.onVerified();
            },
            child: const Text('Trust for 30 days'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.blueGrey),
              const SizedBox(height: 24),
              const Text('Two-Factor Authentication',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Enter the 6-digit code from your authenticator app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 32, letterSpacing: 10, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) {
                  if (v.length == 6) _submit();
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}


// ============================================================
// Phase 14 — Trade Confirmation Bottom Sheet Widget
// D:\Tajir\Frontend\lib\widgets\trade_confirmation_sheet.dart
// ============================================================

class TradeConfirmationSheet extends StatefulWidget {
  final Map<String, dynamic> tradePayload;

  /// Called only after token is verified — proceed with execution
  final VoidCallback onConfirmed;

  const TradeConfirmationSheet({
    super.key,
    required this.tradePayload,
    required this.onConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> tradePayload,
    required VoidCallback onConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TradeConfirmationSheet(
        tradePayload: tradePayload,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<TradeConfirmationSheet> createState() => _TradeConfirmationSheetState();
}

class _TradeConfirmationSheetState extends State<TradeConfirmationSheet> {
  String? _token;
  bool _generatingToken = true;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  Future<void> _generateToken() async {
    final token = await SecurityService.generateTradeToken(widget.tradePayload);
    setState(() {
      _token = token;
      _generatingToken = false;
    });
  }

  Future<void> _confirm() async {
    if (_token == null) return;
    setState(() => _confirming = true);
    final confirmed = await SecurityService.confirmTrade(_token!, widget.tradePayload);
    setState(() => _confirming = false);

    if (confirmed) {
      Navigator.of(context).pop();
      widget.onConfirmed();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirmation failed. Token expired or invalid.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trade = widget.tradePayload;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Confirm Trade',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Trade details
          _row('Pair', trade['pair'] ?? '-'),
          _row('Direction', trade['direction'] ?? '-',
              valueColor: (trade['direction'] ?? '') == 'BUY' ? Colors.green : Colors.red),
          _row('Lot Size', '${trade['lot_size'] ?? '-'}'),
          if (trade['stop_loss'] != null) _row('Stop Loss', '${trade['stop_loss']}'),
          if (trade['take_profit'] != null) _row('Take Profit', '${trade['take_profit']}'),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Token display
          if (_generatingToken)
            const Center(child: CircularProgressIndicator())
          else if (_token != null) ...[
            const Text('Confirmation Token',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                _token!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    fontFamily: 'monospace', letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 6),
            const Text('This token expires in 5 minutes.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_confirming || _token == null) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _confirming
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm & Execute'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black)),
        ],
      ),
    );
  }
}

