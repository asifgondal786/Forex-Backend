import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../core/widgets/app_background.dart';
import '../../routes/app_routes.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = firebase_auth.FirebaseAuth.instance;

  String? _oobCode;
  String? _accountEmail;
  String? _errorMessage;
  String? _infoMessage;
  bool _isBusy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _resolveResetCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Map<String, String> _extractActionParams() {
    final directParams = Uri.base.queryParameters;
    if (directParams.isNotEmpty) {
      return directParams;
    }

    // Flutter web hash routing keeps query parameters inside the URL fragment:
    // https://app/#/reset?mode=resetPassword&oobCode=...
    final fragment = Uri.base.fragment.trim();
    if (fragment.isEmpty) {
      return const <String, String>{};
    }
    final normalizedFragment = fragment.startsWith('/')
        ? fragment
        : '/$fragment';
    return Uri.parse(normalizedFragment).queryParameters;
  }

  Future<void> _resolveResetCode() async {
    final params = _extractActionParams();
    final mode = (params['mode'] ?? '').trim();
    final code = (params['oobCode'] ?? '').trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Reset link is missing or invalid. Please request a new reset email.';
      });
      return;
    }
    if (mode.isNotEmpty && mode != 'resetPassword') {
      setState(() {
        _errorMessage = 'Invalid password reset link mode.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final email = await _auth.verifyPasswordResetCode(code);
      if (!mounted) return;
      setState(() {
        _oobCode = code;
        _accountEmail = email;
        _infoMessage = 'Set a new password for ${email.trim()}.';
      });
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyResetError(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to validate reset link. Request a new password reset email.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _submitReset() async {
    final code = _oobCode;
    if (code == null || code.isEmpty) {
      setState(() {
        _errorMessage = 'Reset link is not valid. Request a new reset email.';
      });
      return;
    }

    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (password.length < 8) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters.';
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await _auth.confirmPasswordReset(code: code, newPassword: password);
      if (!mounted) return;
      setState(() {
        _infoMessage = 'Password reset successful. Please sign in with your new password.';
      });
      _passwordController.clear();
      _confirmPasswordController.clear();
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboard,
          (_) => false,
        );
      });
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyResetError(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Password reset failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _friendlyResetError(String code) {
    switch (code.toLowerCase().trim()) {
      case 'invalid-action-code':
      case 'expired-action-code':
        return 'This reset link has expired. Request a new password reset email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network issue detected. Check internet and retry.';
      default:
        return 'Password reset failed ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  color: Colors.white.withOpacity(0.05),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 24 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _accountEmail == null
                              ? 'Enter your new password to continue.'
                              : 'Account: $_accountEmail',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_errorMessage != null)
                          _buildMessage(_errorMessage!, isError: true),
                        if (_infoMessage != null)
                          _buildMessage(_infoMessage!, isError: false),
                        const SizedBox(height: 8),
                        _buildPasswordField(
                          controller: _passwordController,
                          label: 'New Password',
                          obscure: _obscurePassword,
                          onToggle: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          label: 'Confirm New Password',
                          obscure: _obscureConfirmPassword,
                          onToggle: () {
                            setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword,
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isBusy ? null : _submitReset,
                            child: _isBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Update Password'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isBusy
                                ? null
                                : () {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      AppRoutes.login,
                                      (_) => false,
                                    );
                                  },
                            child: const Text('Back to Sign In'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Minimum 8 characters',
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF3B82F6)),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF3B82F6),
              ),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(String message, {required bool isError}) {
    final color = isError ? Colors.red : const Color(0xFF10B981);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
