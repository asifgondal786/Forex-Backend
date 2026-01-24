import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  
  const LoginScreen({
    Key? key,
    required this.onLoginSuccess,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_validateInputs()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (response.success && response.user != null) {
          debugPrint('✅ Login successful');
          widget.onLoginSuccess();
        } else {
          setState(() => _errorMessage = response.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Login failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateInputs() {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return false;
    }
    
    if (!_emailController.text.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return false;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F1419),
              const Color(0xFF1A1F2E),
              const Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Animation
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF3B82F6),
                            const Color(0xFF2563EB),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 40,
                      ),
                    )
                        .animate()
                        .scaleXY(
                          begin: 0.8,
                          end: 1.0,
                          duration: const Duration(milliseconds: 600),
                        )
                        .fadeIn(),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      '🚀 Forex Companion',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600))
                        .slideX(begin: -0.3),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Your AI-Powered Trading Copilot',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600))
                        .slideX(begin: -0.3, delay: const Duration(milliseconds: 100)),
                    const SizedBox(height: 48),

                    // Card Container
                    Card(
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
                            // Welcome Text
                            Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to your account and start trading',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Error Message
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_errorMessage != null) const SizedBox(height: 20),

                            // Email Field
                            _buildInputField(
                              controller: _emailController,
                              label: 'Email Address',
                              hint: 'your@email.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            _buildPasswordField(),
                            const SizedBox(height: 24),

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  disabledBackgroundColor:
                                      const Color(0xFF3B82F6).withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  shadowColor: const Color(0xFF3B82F6)
                                      .withOpacity(0.4),
                                  elevation: _isLoading ? 0 : 8,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white.withOpacity(0.8),
                                          ),
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: const Duration(milliseconds: 600))
                                .slideY(begin: 0.3, delay: const Duration(milliseconds: 200)),
                            const SizedBox(height: 16),

                            // Demo Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        _emailController.text =
                                            'demo@example.com';
                                        _passwordController.text =
                                            'demo123456';
                                        await _handleLogin();
                                      },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.play_circle_outline,
                                      color: Color(0xFF3B82F6),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Try Demo Account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF3B82F6),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600))
                        .slideY(begin: 0.3),

                    const SizedBox(height: 32),

                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
            prefixIcon: Icon(Icons.lock_outline,
                color: const Color(0xFF3B82F6), size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF3B82F6),
                size: 18,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
