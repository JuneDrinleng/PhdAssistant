import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { red, blue, purple, green, dark }

class ThemeManager extends ChangeNotifier {
  static const String _kThemeKey = 'app_theme';
  AppTheme _currentTheme = AppTheme.red;

  AppTheme get currentTheme => _currentTheme;

  ThemeManager() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_kThemeKey) ?? 'red';
    _currentTheme = AppTheme.values.firstWhere(
      (t) => t.name == themeName,
      orElse: () => AppTheme.red,
    );
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, theme.name);
    notifyListeners();
  }

  ThemeData getThemeData() {
    switch (_currentTheme) {
      case AppTheme.red:
        return _redTheme;
      case AppTheme.blue:
        return _blueTheme;
      case AppTheme.purple:
        return _purpleTheme;
      case AppTheme.green:
        return _greenTheme;
      case AppTheme.dark:
        return _darkTheme; // ✅ 修复：返回 _darkTheme 而不是 Colors.white
    }
  }

  Color getPrimaryColor() {
    switch (_currentTheme) {
      case AppTheme.red:
        return const Color(0xFFFF6B81);
      case AppTheme.blue:
        return const Color(0xFF3B82F6);
      case AppTheme.purple:
        return const Color(0xFFA855F7);
      case AppTheme.green:
        return const Color(0xFF10B981);
      case AppTheme.dark:
        return const Color(0xFF343842); // ✅ 暗色主题使用深灰色（比背景浅一点）
    }
  }

  // Red Theme (红色主题)
  static final _redTheme = ThemeData(
    fontFamily: 'SourceHanSans',
    useMaterial3: true,
    primaryColor: const Color(0xFFFF6B81),
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFFFF6B81),
      secondary: const Color(0xFFFF4757),
      surface: Colors.white,
      background: const Color(0xFFFFF5F5),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.08),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF222222),
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF222222),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF222222),
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF333333),
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF333333)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF666666)),
      bodySmall: TextStyle(fontSize: 12, color: Color(0xFF888888)),
    ),
  );

  // Blue Theme (蓝色主题)
  static final _blueTheme = ThemeData(
    fontFamily: 'SourceHanSans',
    useMaterial3: true,
    primaryColor: const Color(0xFF3B82F6),
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF3B82F6),
      secondary: const Color(0xFF1D4ED8),
      surface: Colors.white,
      background: const Color(0xFFF5F9FF),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.08),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F2937),
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF374151)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
      bodySmall: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
    ),
  );

  // Purple Theme (紫色主题)
  static final _purpleTheme = ThemeData(
    fontFamily: 'SourceHanSans',
    useMaterial3: true,
    primaryColor: const Color(0xFFA855F7),
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFFA855F7),
      secondary: const Color(0xFF7E22CE),
      surface: Colors.white,
      background: const Color(0xFFFAF5FF),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.08),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F1633),
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F1633),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F1633),
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF3D2F5A),
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF3D2F5A)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF7C6E90)),
      bodySmall: TextStyle(fontSize: 12, color: Color(0xFF9B8DA8)),
    ),
  );

  // Green Theme (绿色主题)
  static final _greenTheme = ThemeData(
    fontFamily: 'SourceHanSans',
    useMaterial3: true,
    primaryColor: const Color(0xFF10B981),
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF10B981),
      secondary: const Color(0xFF059669),
      surface: Colors.white,
      background: const Color(0xFFF5FFFA),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.08),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F2F23),
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F2F23),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F2F23),
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1F4C3B),
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1F4C3B)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF5B7F71)),
      bodySmall: TextStyle(fontSize: 12, color: Color(0xFF7A9B8E)),
    ),
  );

  // Dark Theme (暗色主题) - 精心设计的暗色模式 🌙
  static final _darkTheme = ThemeData(
    fontFamily: 'SourceHanSans',
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF343842), // 使用深灰色作为主色（比背景浅）
    scaffoldBackgroundColor: const Color(0xFF0A0B0D), // 最深的背景
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF343842), // 深灰色按钮
      secondary: Color(0xFF2A2D33), // 稍深的灰色
      surface: Color(0xFF1A1D23), // 卡片表面
      background: Color(0xFF0A0B0D), // 背景
      onPrimary: Color(0xFFF9FAFB), // 深灰色按钮上的白色文字 ✅
      onSecondary: Color(0xFFF9FAFB),
      onSurface: Color(0xFFF3F4F6), // 表面上的文字
      onBackground: Color(0xFFF3F4F6), // 背景上的文字
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1D23),
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    // 文字主题 - 优化暗色模式下的可读性
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFFF9FAFB), // 几乎纯白
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF3F4F6), // 非常浅的灰白
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF3F4F6),
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFFE5E7EB), // 浅灰
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Color(0xFFD1D5DB), // 中等灰
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Color(0xFF9CA3AF), // 灰色
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: Color(0xFF6B7280), // 深灰
      ),
    ),
    // 输入框主题
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1D23),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF374151), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF374151), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFF3F4F6), // 更亮的白灰色聚焦边框
          width: 2,
        ),
      ),
    ),
    // 图标主题
    iconTheme: const IconThemeData(color: Color(0xFFE5E7EB), size: 20),
  );
}
