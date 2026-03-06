import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../embodied_agent/embodied_agent_screen.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/header_provider.dart';
import 'login_screen.dart';
import 'verification_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _didFetch = false;
  static const bool _requirePhoneVerification = bool.fromEnvironment(
    'REQUIRE_PHONE_VERIFICATION',
    defaultValue: false,
  );
  static const bool _skipAuthGate =
      bool.fromEnvironment('SKIP_AUTH_GATE', defaultValue: false);
  static const String _devUserId =
      String.fromEnvironment('DEV_USER_ID', defaultValue: '');

  bool get _firebaseAuthReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _fetchAfterBuild(BuildContext context) {
    if (_didFetch) return;
    _didFetch = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaskProvider>().fetchTasks();
      context.read<UserProvider>().fetchUser();
      context.read<HeaderProvider>().fetchHeader();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_skipAuthGate && kDebugMode) {
      if (_devUserId.isNotEmpty) {
        _fetchAfterBuild(context);
      }
      return const EmbodiedAgentScreen();
    }

    if (!_firebaseAuthReady) {
      _didFetch = false;
      return LoginScreen(onLoginSuccess: () {});
    }

    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          _didFetch = false;
          return LoginScreen(onLoginSuccess: () {});
        }

        final needsEmail = !(user.emailVerified);
        final needsPhone =
            _requirePhoneVerification && ((user.phoneNumber ?? '').isEmpty);
        if (needsEmail || needsPhone) {
          _didFetch = false;
          return const VerificationScreen();
        }

        _fetchAfterBuild(context);

        return const EmbodiedAgentScreen();
      },
    );
  }
}
