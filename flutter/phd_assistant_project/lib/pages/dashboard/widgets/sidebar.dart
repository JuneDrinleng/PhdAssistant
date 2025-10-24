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
  final bool isCompact; // 是否为紧凑模式(只显示图标)

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.auth,
    required this.themeManager,
    this.isCompact = false,
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
    return Container(
      width: isCompact ? 72 : 260,
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
          // 头部 Logo
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
      padding: EdgeInsets.symmetric(
        vertical: 20,
        horizontal: isCompact ? 0 : 20,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: isCompact
          ? Icon(Icons.apps, color: _primaryColor, size: 28)
          : Row(
              children: [
                Icon(Icons.apps, color: _primaryColor),
                const SizedBox(width: 8),
                Text('专注小助手', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
    );
  }

  // 构建菜单列表
  Widget _buildMenuList(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: 20,
      ),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        final isActive = selectedIndex == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Tooltip(
            message: isCompact ? item.label : '',
            preferBelow: false,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onItemTap(index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 0 : 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (themeManager.currentTheme == AppTheme.dark
                              ? const Color.fromARGB(255, 255, 255, 255)
                              : _primaryColor.withOpacity(0.15))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isCompact
                      ? Center(
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: isActive
                                ? _primaryColor
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isActive
                                  ? _primaryColor
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                color: isActive
                                    ? _primaryColor
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
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
          ),
        );
      },
    );
  }

  // 构建退出登录按钮
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 10),
      child: Tooltip(
        message: isCompact ? '退出登录' : '',
        preferBelow: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 0 : 16,
                vertical: 12,
              ),
              child: isCompact
                  ? Center(
                      child: Icon(
                        Icons.logout,
                        size: 24,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : _primaryColor,
                      ),
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.logout,
                          size: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : _primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '退出登录',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : _primaryColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
