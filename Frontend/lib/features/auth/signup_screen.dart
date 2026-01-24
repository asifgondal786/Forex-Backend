import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _fullNameController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return false;
    }
    
    if (!_emailController.text.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return false;
    }
    
    if (_passwordController.text.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      return false;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return false;
    }
    
    if (_usernameController.text.length < 3) {
      setState(() => _errorMessage = 'Username must be at least 3 characters');
      return false;
    }
    
    return true;
  }

  Future<void> _handleSignup() async {
    if (!_validateInputs()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
      );

      if (mounted) {
        if (response.success && response.user != null) {
          debugPrint('✅ Signup successful');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account created! Please login.')),
            );
            Navigator.pop(context);
          }
        } else {
          setState(() => _errorMessage = response.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Signup failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Logo & Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🚀 Create Account',
                            style: TextStyle(
                              fontSize: isMobile ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join Forex Companion AI Trading',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .slideY(begin: -0.3),
                  const SizedBox(height: 32),

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

                          // Full Name Field
                          _buildInputField(
                            controller: _fullNameController,
                            label: 'Full Name',
                            hint: 'John Doe',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),

                          // Username Field
                          _buildInputField(
                            controller: _usernameController,
                            label: 'Username',
                            hint: 'johndoe',
                            icon: Icons.account_circle_outlined,
                          ),
                          const SizedBox(height: 16),

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
                          _buildPasswordField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Minimum 8 characters',
                            obscure: _obscurePassword,
                            onToggle: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password Field
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            obscure: _obscureConfirmPassword,
                            onToggle: () {
                              setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword);
                            },
                          ),
                          const SizedBox(height: 28),

                          // Signup Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _handleSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF3B82F6),
                                disabledBackgroundColor: const Color(0xFF3B82F6)
                                    .withOpacity(0.5),
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
                                      'Create Account',
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
                              .fadeIn(
                                  duration:
                                      const Duration(milliseconds: 600))
                              .slideY(
                                  begin: 0.3,
                                  delay: const Duration(
                                      milliseconds: 200)),
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
                        'Already have an account? ',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Sign In',
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
            prefixIcon: Icon(icon,
                color: const Color(0xFF3B82F6), size: 20),
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
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
            fontWeight: FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
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
            prefixIcon: Icon(Icons.lock_outline,
                color: const Color(0xFF3B82F6), size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: const Color(0xFF3B82F6),
                size: 18,
              ),
              onPressed: onToggle,
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
