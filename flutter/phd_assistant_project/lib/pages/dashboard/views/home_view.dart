import 'package:flutter/material.dart';
import '../../../service/auth_service.dart';
import '../../../utils/theme_manager.dart';

class HomeView extends StatelessWidget {
  final AuthService auth;
  final ThemeManager themeManager;
  final Function(int) onNavigate;

  const HomeView({
    super.key,
    required this.auth,
    required this.themeManager,
    required this.onNavigate,
  });

  // 获取主题色
  Color get _primaryColor => themeManager.getPrimaryColor();

  @override
  Widget build(BuildContext context) {
    final username = auth.user?['username']?.toString() ?? '未登录';
    final isMobile = MediaQuery.of(context).size.width <= 600;

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: EdgeInsets.all(isMobile ? 24 : 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('👋', style: TextStyle(fontSize: isMobile ? 48 : 64)),
              SizedBox(height: isMobile ? 12 : 16),
              Text(
                'Welcome, $username!',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: isMobile ? 28 : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '祝你度过一个愉快而高效的一天~',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isMobile ? 24 : 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildQuickAction(context, Icons.timer, '专注', 1, isMobile),
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    context,
                    Icons.add_box_outlined,
                    '添加',
                    2,
                    isMobile,
                  ),
                  const SizedBox(width: 12),
                  _buildQuickAction(context, Icons.list, '记录', 4, isMobile),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建快捷操作按钮
  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    bool isMobile,
  ) {
    final size = isMobile ? 90.0 : 80.0;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      elevation: isMobile ? 2 : 0,
      child: InkWell(
        onTap: () => onNavigate(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: themeManager.currentTheme == AppTheme.dark
                    ? Colors.white
                    : _primaryColor,
                size: isMobile ? 32 : 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: themeManager.currentTheme == AppTheme.dark
                      ? Colors.white
                      : null,
                  fontSize: isMobile ? 13 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
