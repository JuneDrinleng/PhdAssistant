import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../service/auth_service.dart';
import '../pages/login_page.dart';
import '../pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthService();
  await auth.restoreAndValidateSession();

  final router = GoRouter(
    /// 登录态变化时，自动触发重定向评估
    refreshListenable: auth,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      // 初始化未完成时不跳转，避免抖动
      if (!auth.isInitialized) return null;

      final bool loggedIn = auth.isLoggedIn;
      final bool onLogin = state.matchedLocation == '/login';

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(auth: auth),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => DashboardPage(auth: auth),
      ),
    ],
  );

  runApp(MyApp(router: router));
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
    );
  }
}
