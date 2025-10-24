import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';

import '../service/auth_service.dart';
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
      minimumSize: Size(600, 450), // 最小尺寸
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
        builder: (context, state) => LoginPage(auth: auth),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => RegisterPage(auth: auth),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => DashboardPage(auth: auth),
      ),
    ],
  );

  runApp(
    MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 使用思源黑体
        fontFamily: 'SourceHanSans',

        // 优化字体渲染
        useMaterial3: true,

        // 文本主题 - 优化中文显示
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            height: 1.2,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            height: 1.3,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.6, // 增加行高，中文更舒适
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(fontSize: 14, height: 1.6, letterSpacing: 0.3),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),

        // 主题色
        primaryColor: const Color(0xFFE53935),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFFE53935),
          secondary: const Color(0xFFE53935),
          surface: Colors.white,
        ),
      ),
    ),
  );
}
