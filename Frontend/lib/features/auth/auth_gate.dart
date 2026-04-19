import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_shell.dart';
import '../../providers/mode_provider.dart';
import 'login_screen.dart';
import 'verification_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const bool _requirePhoneVerification = bool.fromEnvironment(
    'REQUIRE_PHONE_VERIFICATION',
    defaultValue: false,
  );
  static const bool _skipAuthGate =
      bool.fromEnvironment('SKIP_AUTH_GATE', defaultValue: false);

  bool get _firebaseAuthReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _goToAppShell(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeProvider = context.watch<ModeProvider>();
    if (!modeProvider.loaded) {
      return const _AuthLoadingScreen();
    }

    if (_skipAuthGate && kDebugMode) {
      return const AppShell();
    }

    if (!_firebaseAuthReady) {
      return LoginScreen(onLoginSuccess: () => _goToAppShell(context));
    }

    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(onLoginSuccess: () => _goToAppShell(context));
        }

        final needsEmail = !user.emailVerified;
        final needsPhone =
            _requirePhoneVerification && ((user.phoneNumber ?? '').isEmpty);

        if (needsEmail || needsPhone) {
          return const VerificationScreen();
        }

        return const AppShell();
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

