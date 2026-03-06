import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import 'auth_action_context.dart';
import 'auth_gate.dart';
import 'password_reset_screen.dart';
import 'verification_screen.dart';

class AuthEntryScreen extends StatelessWidget {
  const AuthEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final action = AuthActionContext.fromBaseUri();

    if (action.mode == 'resetPassword' || action.path == AppRoutes.reset) {
      return const PasswordResetScreen();
    }

    if (action.mode == 'verifyEmail' || action.path == AppRoutes.verify) {
      return const VerificationScreen();
    }

    return const AuthGate();
  }
}
