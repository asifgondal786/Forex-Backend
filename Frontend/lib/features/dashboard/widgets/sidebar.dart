import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: AppColors.sidebarDark,
      child: Column(
        children: [
          // Logo & App Name
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',  // FIXED: Correct path
                  height: 36,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if logo doesn't exist
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.currency_exchange, color: Colors.white),
                    );
                  },
                ),
                const SizedBox(width: 12),
                const Text(
                  'Forex Companion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Navigation Items
          _buildMenuItem(context, Icons.dashboard, 'Dashboard', '/'),
          _buildMenuItem(context, Icons.add_circle_outline, 'Task Creation', '/create-task'),
          _buildMenuItem(context, Icons.history, 'Task History', '/task-history'),
          _buildMenuItem(context, Icons.psychology, 'AI Assistant', '/ai-chat'),
          _buildMenuItem(context, Icons.settings, 'Settings', '/settings'),
          
          const Spacer(),
          
          // User Profile Section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Notification Bell
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white54),
                      onPressed: () {},
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryGreen,
                      child: const Text(
                        'S',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sohaib',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Free Plan',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  icon: const Icon(Icons.settings, size: 16, color: Colors.white54),
                  label: const Text(
                    'Settings',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build menu items
  Widget _buildMenuItem(BuildContext context, IconData icon, String label, String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = currentRoute == route;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryBlue.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? AppColors.primaryBlue : Colors.white54,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}