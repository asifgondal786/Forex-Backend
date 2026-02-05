import 'package:flutter/material.dart';
import '../widgets/dashboard_content.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DashboardContent(),
    );
  }
}
