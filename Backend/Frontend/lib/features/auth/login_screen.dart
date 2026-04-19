import 'package:flutter/material.dart';
import 'package:forex_companion/config/theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/firebase_service.dart';
import '../../services/api_service.dart';
import '../../services/security_lockout_service.dart';
import '../../core/widgets/app_background.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _firebaseService = FirebaseService();
  final _apiService = ApiService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  static final _invisibleChars = RegExp(
    r'[\u0000-\u001F\u007F\u00A0\u1680\u180E\u2000-\u200F\u2028-\u202F\u205F-\u206F\u3000\uFEFF]',
  );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _apiService.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _normalize(String email) => email
      .replaceAll(_invisibleChars, '')
      .replaceAll(RegExp(r'\s+'), '')
      .trim()
      .toLowerCase();

  bool _isValidEmail(String email) =>
      RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
          .hasMatch(email);

  String _friendlyError(String code) => switch (code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Email or password is incorrect.',
        'invalid-email' => 'This email format is invalid.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please wait and try again.',
        'network-request-failed' =>
          'Network issue detected. Check your connection.',
        _ => 'Login failed ($code). Please try again.',
      };

  bool _countsAsFailure(String code) =>
      !{'network-request-failed', 'internal-error', 'too-many-requests'}
          .contains(code);

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  Future<void> _handleLogin() async {
    final email = _normalize(_emailCtrl.text);
    _emailCtrl.text = email;

    if (email.isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email.');
      return;
    }

    if (await SecurityLockoutService.isLocked(email)) {
      final msg = await SecurityLockoutService.lockMessage(email);
      if (mounted) setState(() => _errorMessage = msg);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user =
          await _firebaseService.signInWithEmail(email, _passwordCtrl.text);
      if (!mounted) return;
      if (user != null) {
        await SecurityLockoutService.resetOnSuccess(email);
        if (mounted) widget.onLoginSuccess();
      } else {
        setState(() => _errorMessage = 'Unable to sign in. Please try again.');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase().trim();
      if (!_countsAsFailure(code)) {
        if (mounted) setState(() => _errorMessage = _friendlyError(code));
        return;
      }
      final state = await SecurityLockoutService.recordFailure(email);
      if (!mounted) return;
      if (state.locked) {
        final msg = await SecurityLockoutService.lockMessage(email);
        if (mounted) setState(() => _errorMessage = msg);
      } else {
        final left = state.attemptsLeft;
        setState(() => _errorMessage =
            '${_friendlyError(code)} ($left attempt${left == 1 ? '' : 's'} left before lockout)');
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Forgot password
  // ---------------------------------------------------------------------------

  Future<void> _showForgotPassword() async {
    final msg = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        apiService: _apiService,
        initialEmail: _emailCtrl.text.trim(),
        normalizeEmail: _normalize,
        isValidEmail: _isValidEmail,
      ),
    );
    if (mounted && msg != null && msg.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final pad = isMobile ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Logo(isMobile: isMobile),
                  const SizedBox(height: 24),
                  Text(
                    'Forex Companion',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.3),
                  const SizedBox(height: 8),
                  Text(
                    'Your AI-Powered Trading Copilot',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideX(begin: -0.3, delay: 100.ms),
                  const SizedBox(height: 48),

                  // Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    color: Colors.white.withValues(alpha: 0.05),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 24 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome Back',
                              style: TextStyle(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 8),
                          Text('Sign in to your account and start trading',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500])),
                          const SizedBox(height: 28),

                          if (_errorMessage != null) ...[
                            _ErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 20),
                          ],

                          _InputField(
                            controller: _emailCtrl,
                            label: 'Email Address',
                            hint: 'your@email.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 16),

                          _PasswordField(
                            controller: _passwordCtrl,
                            obscure: _obscurePassword,
                            onToggle: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 4),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _isLoading ? null : _showForgotPassword,
                              child: const Text('Forgot password?',
                                  style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: AppTheme.glassElevatedButtonStyle(
                                tintColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                borderRadius: 12,
                                elevation: _isLoading ? 0 : 4,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    )
                                  : const Text('Sign In',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.5)),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slideY(begin: 0.3, delay: 200.ms),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13)),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, '/signup'),
                        child: const Text('Sign Up',
                            style: TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _Logo extends StatelessWidget {
  final bool isMobile;
  const _Logo({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final size = isMobile ? 144.0 : 165.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            blurRadius: 36,
            spreadRadius: 9,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Image.asset('assets/images/companion_logo.png',
            fit: BoxFit.cover),
      ),
    ).animate().scaleXY(begin: 0.8, end: 1.0, duration: 600.ms).fadeIn();
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500))),
        ]),
      );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
  });

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            width == 0 ? BorderSide.none : BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0.4)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.next,
            onSubmitted: onSubmitted,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              prefixIcon:
                  Icon(icon, color: const Color(0xFF3B82F6), size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: _border(Colors.transparent, width: 0),
              enabledBorder:
                  _border(Colors.white.withValues(alpha: 0.1)),
              focusedBorder:
                  _border(const Color(0xFF3B82F6), width: 2),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      );
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String>? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.onSubmitted,
  });

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            width == 0 ? BorderSide.none : BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Password',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0.4)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmitted,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              prefixIcon: const Icon(Icons.lock_outline,
                  color: Color(0xFF3B82F6), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF3B82F6),
                  size: 18,
                ),
                onPressed: onToggle,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: _border(Colors.transparent, width: 0),
              enabledBorder:
                  _border(Colors.white.withValues(alpha: 0.1)),
              focusedBorder:
                  _border(const Color(0xFF3B82F6), width: 2),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      );
}

// =============================================================================
// Forgot Password Dialog
// =============================================================================

class _ForgotPasswordDialog extends StatefulWidget {
  final ApiService apiService;
  final String initialEmail;
  final String Function(String) normalizeEmail;
  final bool Function(String) isValidEmail;

  const _ForgotPasswordDialog({
    required this.apiService,
    required this.initialEmail,
    required this.normalizeEmail,
    required this.isValidEmail,
  });

  @override
  State<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _ctrl;
  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = widget.normalizeEmail(_ctrl.text);
    _ctrl.text = email;

    if (!widget.isValidEmail(email)) {
      setState(() => _inlineError = 'Enter a valid email.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      final res =
          await widget.apiService.requestPasswordReset(email: email);
      final msg = (res['message'] as String?) ??
          'If an account exists, reset instructions have been sent.';
      if (mounted) Navigator.of(context).pop(msg);
    } catch (e) {
      if (mounted) setState(() => _inlineError = 'Reset failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                  labelText: 'Email', hintText: 'you@example.com'),
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 8),
              Text(_inlineError!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed:
                _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send'),
          ),
        ],
      );
}
