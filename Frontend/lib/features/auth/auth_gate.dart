import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../dashboard/screens/dashboard_screen.dart';
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
  static const bool _requirePhoneVerification = true;
  static const bool _skipAuthGate = true; // Skip authentication to redirect to home page
  static const String _devUserId =
      String.fromEnvironment('DEV_USER_ID', defaultValue: '');

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
    if (_skipAuthGate) {
      if (_devUserId.isNotEmpty) {
        _fetchAfterBuild(context);
      }
      return const DashboardScreen();
    }

    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
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
        final needsPhone = _requirePhoneVerification &&
            ((user.phoneNumber ?? '').isEmpty);
        if (needsEmail || needsPhone) {
          _didFetch = false;
          return const VerificationScreen();
        }

        _fetchAfterBuild(context);

        return const DashboardScreen();
      },
    );
  }
}
