import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../service/auth_service.dart';
import '../../../utils/theme_manager.dart';

class MenuItem {
  final IconData icon;
  final String label;

  MenuItem({required this.icon, required this.label});
}

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final AuthService auth;
  final ThemeManager themeManager;
  final VoidCallback onToggle;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.auth,
    required this.themeManager,
    required this.onToggle,
  });

  // 获取主题色
  Color get _primaryColor => themeManager.getPrimaryColor();

  // 菜单项列表
  List<MenuItem> get _menuItems => [
    MenuItem(icon: Icons.home, label: '主页'),
    MenuItem(icon: Icons.timer, label: '专注'),
    MenuItem(icon: Icons.add_box_outlined, label: '添加专注时间'),
    MenuItem(icon: Icons.bar_chart, label: '统计'),
    MenuItem(icon: Icons.list, label: '查看记录'),
    MenuItem(icon: Icons.settings, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final username = auth.user?['username']?.toString() ?? '未登录';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头部
          _buildHeader(context),

          // 菜单列表
          Expanded(child: _buildMenuList(context)),

          // 退出登录按钮
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  // 构建头部
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggle,
            icon: const Icon(Icons.menu),
            color: _primaryColor,
          ),
          const SizedBox(width: 8),
          Text('专注小助手', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  // 构建菜单列表
  Widget _buildMenuList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        final isActive = selectedIndex == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onItemTap(index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? (themeManager.currentTheme == AppTheme.dark
                            ? const Color.fromARGB(
                                255,
                                255,
                                255,
                                255,
                              ) // 暗色模式：更浅的灰色
                            : _primaryColor.withOpacity(0.15)) // 其他主题
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: isActive
                          ? _primaryColor
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: isActive
                            ? _primaryColor
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: isActive
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 构建退出登录按钮
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await auth.logout();
            if (context.mounted) context.go('/login');
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.logout,
                  size: 20,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors
                            .white // 暗色模式用白色
                      : _primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  '退出登录',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors
                              .white // 暗色模式用白色
                        : _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
