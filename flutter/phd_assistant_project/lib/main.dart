import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';

import '../service/auth_service.dart';
import '../utils/theme_manager.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows 窗口配置
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(800, 600), // 窗口大小
      minimumSize: Size(800, 600), // 最小尺寸
      center: true, // 居中显示
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'PhD Assistant', // 窗口标题
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final auth = AuthService();
  await auth.restoreAndValidateSession();

  final themeManager = ThemeManager();

  final router = GoRouter(
    refreshListenable: auth,
    initialLocation: '/login',
    redirect: (context, state) {
      if (!auth.isInitialized) return null;

      final bool loggedIn = auth.isLoggedIn;
      final bool onAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // 未登录且不在认证页面，跳转到登录页
      if (!loggedIn && !onAuthPage) return '/login';

      // 已登录且在认证页面，跳转到dashboard
      if (loggedIn && onAuthPage) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          auth: auth,
          themeManager: themeManager, // 添加这个参数
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterPage(
          auth: auth,
          themeManager: themeManager, // 添加这个参数
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) =>
            DashboardPage(auth: auth, themeManager: themeManager),
      ),
    ],
  );

  runApp(MyApp(router: router, themeManager: themeManager));
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  final ThemeManager themeManager;

  const MyApp({super.key, required this.router, required this.themeManager});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        return MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: themeManager.getThemeData(),
        );
      },
    );
  }
}
