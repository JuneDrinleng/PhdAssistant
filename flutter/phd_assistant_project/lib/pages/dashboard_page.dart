import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../service/auth_service.dart';

class DashboardPage extends StatelessWidget {
  final AuthService auth;
  const DashboardPage({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        final username = auth.user?['username']?.toString() ?? '未登录';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
            actions: [
              IconButton(
                tooltip: '登出',
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('用户名'),
                  subtitle: Text(username),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: const Text('登录状态'),
                  subtitle: Text(auth.isLoggedIn ? '已登录' : '未登录（将被重定向到登录页）'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
