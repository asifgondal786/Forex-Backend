import 'dart:async';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePass = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMsg;

  // Rate limit state
  bool _isRateLimited = false;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _lockoutTimer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startLockout(int seconds) {
    setState(() {
      _isRateLimited = true;
      _lockoutSeconds = seconds;
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _lockoutSeconds--);
      if (_lockoutSeconds <= 0) {
        t.cancel();
        setState(() => _isRateLimited = false);
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_isRateLimited) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 1200));

    // Simulate rate limit on 3rd attempt (demo)
    // In real app: check response status 429 and parse retry-after header
    setState(() => _isLoading = false);
    _shakeCtrl.forward(from: 0);
    setState(() => _errorMsg = 'Invalid credentials. Please try again.');
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    // Firebase Google Auth integration point
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _isLoading = false);
    // Navigate on success: context.go('/home')
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              _buildLogo(scheme),
              const SizedBox(height: 40),
              _buildHeader(scheme),
              const SizedBox(height: 32),
              if (_isRateLimited) _buildRateLimitBanner(scheme),
              _buildForm(scheme),
              const SizedBox(height: 16),
              _buildRememberForgotRow(scheme),
              const SizedBox(height: 24),
              _buildLoginButton(scheme),
              const SizedBox(height: 20),
              _buildDivider(scheme),
              const SizedBox(height: 20),
              _buildGoogleButton(scheme),
              const SizedBox(height: 32),
              _buildRegisterRow(scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ColorScheme scheme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.currency_exchange, color: Colors.white, size: 26),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to your Tajir account',
          style: TextStyle(
            fontSize: 15,
            color: scheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildRateLimitBanner(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Too many attempts',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Try again in $_lockoutSeconds seconds',
                  style: TextStyle(
                    color: Colors.red.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Countdown ring
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _lockoutSeconds / 30.0,
                  strokeWidth: 3,
                  color: Colors.red,
                  backgroundColor: Colors.red.withOpacity(0.2),
                ),
                Text(
                  '$_lockoutSeconds',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final offset =
            _shakeCtrl.isAnimating ? (_shakeAnim.value * 8) * ((_shakeAnim.value * 10).toInt().isEven ? 1 : -1) : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_errorMsg != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            _TajirTextField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              scheme: scheme,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _TajirTextField(
              controller: _passCtrl,
              label: 'Password',
              hint: '••••••••',
              obscureText: _obscurePass,
              prefixIcon: Icons.lock_outline_rounded,
              scheme: scheme,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: scheme.onSurface.withOpacity(0.4),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRememberForgotRow(ColorScheme scheme) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _rememberMe ? scheme.primary : Colors.transparent,
                  border: Border.all(
                    color: _rememberMe
                        ? scheme.primary
                        : scheme.outline.withOpacity(0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: _rememberMe
                    ? Icon(Icons.check, size: 13, color: scheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Remember me',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Text(
            'Forgot password?',
            style: TextStyle(
              fontSize: 13,
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isLoading || _isRateLimited) ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: scheme.onPrimary,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _isRateLimited ? 'Locked ($_lockoutSeconds s)' : 'Sign In',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: scheme.outline.withOpacity(0.3)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
        Expanded(
          child: Divider(color: scheme.outline.withOpacity(0.3)),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        icon: const _GoogleIcon(),
        label: const Text(
          'Continue with Google',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: scheme.outline.withOpacity(0.4)),
        ),
      ),
    );
  }

  Widget _buildRegisterRow(ColorScheme scheme) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: TextStyle(
                color: scheme.onSurface.withOpacity(0.5), fontSize: 14),
          ),
          GestureDetector(
            onTap: () {},
            child: Text(
              'Sign up',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TajirTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final ColorScheme scheme;
  final String? Function(String?)? validator;

  const _TajirTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    required this.prefixIcon,
    this.suffixIcon,
    required this.scheme,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle:
            TextStyle(color: scheme.onSurface.withOpacity(0.3), fontSize: 14),
        prefixIcon:
            Icon(prefixIcon, color: scheme.onSurface.withOpacity(0.4), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outline.withOpacity(0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Icon(Icons.g_mobiledata_rounded, size: 22),
    );
  }
}
