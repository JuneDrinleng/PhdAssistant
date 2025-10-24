import 'package:flutter/material.dart';
import '../../../service/auth_service.dart';
import '../../../utils/theme_manager.dart';
import 'focus_view.dart';
import 'add_focus_view.dart';

class MobileFocusView extends StatefulWidget {
  final AuthService auth;
  final ThemeManager themeManager;
  final VoidCallback onFocusCompleted;

  const MobileFocusView({
    super.key,
    required this.auth,
    required this.themeManager,
    required this.onFocusCompleted,
  });

  @override
  State<MobileFocusView> createState() => _MobileFocusViewState();
}

class _MobileFocusViewState extends State<MobileFocusView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.themeManager.getPrimaryColor();

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: primaryColor,
              unselectedLabelColor: Theme.of(
                context,
              ).textTheme.bodyMedium?.color,
              indicatorColor: primaryColor,
              tabs: const [
                Tab(text: '计时器'),
                Tab(text: '添加记录'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              FocusView(
                auth: widget.auth,
                themeManager: widget.themeManager,
                onFocusCompleted: widget.onFocusCompleted,
              ),
              AddFocusView(
                auth: widget.auth,
                themeManager: widget.themeManager,
                onFocusAdded: widget.onFocusCompleted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
