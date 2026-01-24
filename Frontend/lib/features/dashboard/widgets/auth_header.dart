import 'package:flutter/material.dart';

/// Auth Header Widget - Top-right authentication UI
/// Shows Sign In / Create Account before login
/// Shows User Avatar + Risk Level Badge after login
class AuthHeader extends StatelessWidget {
  final bool isLoggedIn;
  final String? userName;
  final String? userEmail;
  final String? riskLevel; // 'Low', 'Moderate', 'High'
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogout;

  const AuthHeader({
    Key? key,
    required this.isLoggedIn,
    this.userName,
    this.userEmail,
    this.riskLevel = 'Moderate',
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onLogout,
  }) : super(key: key);

  Color _getRiskColor() {
    switch (riskLevel?.toLowerCase()) {
      case 'low':
        return const Color(0xFF10B981); // Green
      case 'high':
        return const Color(0xFFEF4444); // Red
      case 'moderate':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: isLoggedIn
          ? _buildLoggedInHeader()
          : _buildLoggedOutHeader(),
    );
  }

  Widget _buildLoggedInHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // User Info + Risk Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF2563EB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    (userName?.isNotEmpty ?? false)
                        ? userName!.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // User Name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  // Risk Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getRiskColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Risk: ${riskLevel ?? 'Moderate'}',
                      style: TextStyle(
                        color: _getRiskColor(),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Logout Button
              GestureDetector(
                onTap: onLogout,
                child: Icon(
                  Icons.logout,
                  color: Colors.white.withOpacity(0.6),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedOutHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Sign In Button
        GestureDetector(
          onTap: onSignIn,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Create Account Button
        GestureDetector(
          onTap: onCreateAccount,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF2563EB),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Create Account',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
