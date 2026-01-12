import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class CustomSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    
    // Remove any existing snackbars
    messenger.clearSnackBars();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getIcon(type),
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _getColor(type),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: const EdgeInsets.all(16),
      duration: duration,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
    );

    messenger.showSnackBar(snackBar);
  }

  static IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  static Color _getColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return AppColors.primaryGreen;
      case NotificationType.error:
        return AppColors.stopButton;
      case NotificationType.warning:
        return AppColors.priorityMedium;
      case NotificationType.info:
        return AppColors.primaryBlue;
    }
  }

  // Convenience methods
  static void success(BuildContext context, String message) {
    show(context, message: message, type: NotificationType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: NotificationType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, type: NotificationType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: NotificationType.info);
  }
}