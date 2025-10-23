// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../service/auth_service.dart';

class DashboardPage extends StatelessWidget {
  final AuthService auth;
  const DashboardPage({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    final name = auth.user?['username'] ?? 'User';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(child: Text('🎉 欢迎，$name')),
    );
  }
}
