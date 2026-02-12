import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:forex_companion/providers/account_connection_provider.dart';
import 'package:forex_companion/core/widgets/custom_snackbar.dart';

class ConnectForexAccountDialog extends StatefulWidget {
  const ConnectForexAccountDialog({super.key});

  @override
  State<ConnectForexAccountDialog> createState() => _ConnectForexAccountDialogState();
}

class _ConnectForexAccountDialogState extends State<ConnectForexAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connectAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<AccountConnectionProvider>(
        context,
        listen: false,
      ).connectForexAccount(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      CustomSnackbar.success(context, 'Successfully connected to Forex.com');
      Navigator.of(context).pop(true);
    } catch (error) {
      CustomSnackbar.error(context, 'Connection failed: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect Forex.com Account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your username';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Your credentials are encrypted and securely stored',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _connectAccount,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Connect'),
        ),
      ],
    );
  }
}