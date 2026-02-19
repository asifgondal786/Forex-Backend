import 'package:flutter/material.dart';
import '../widgets/dashboard_content.dart';
import '../widgets/sidebar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      drawer: Drawer(
        backgroundColor: Color(0xFF0B1220),
        child: SafeArea(
          child: Sidebar(isCollapsed: false),
        ),
      ),
      body: DashboardContent(),
    );
  }
}
