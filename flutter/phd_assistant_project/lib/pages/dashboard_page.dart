import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../service/auth_service.dart';
import '../utils/theme_manager.dart';

// 导入所有视图和组件
import 'dashboard/widgets/sidebar.dart';
import 'dashboard/views/home_view.dart';
import 'dashboard/views/focus_view.dart';
import 'dashboard/views/add_focus_view.dart';
import 'dashboard/views/stats_view.dart';
import 'dashboard/views/records_view.dart';
import 'dashboard/views/settings_view.dart';
import 'dashboard/views/mobile_focus_view.dart';

class DashboardPage extends StatefulWidget {
  final AuthService auth;
  final ThemeManager themeManager;

  const DashboardPage({
    super.key,
    required this.auth,
    required this.themeManager,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  // 记录列表(共享状态)
  List<Map<String, dynamic>> _records = [];
  bool _loadingRecords = false;

  // 移动端索引映射:移动端显示的索引 -> 实际页面索引
  final List<int> _mobileIndexMap = [1, 3, 4, 5]; // 专注(1)、统计(3)、记录(4)、设置(5)

  // 使用 AuthService 的 Dio 实例
  Dio get _dio => widget.auth.dio;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // ========== 记录管理(共享功能) ==========

  Future<void> _loadRecords() async {
    setState(() => _loadingRecords = true);

    try {
      final response = await _dio.get('/focus?limit=500');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List) {
          setState(() {
            _records = List<Map<String, dynamic>>.from(
              data.map((item) => item as Map<String, dynamic>),
            );
            _loadingRecords = false;
          });
        } else {
          throw Exception('Unexpected response format');
        }
      }
    } catch (e) {
      setState(() => _loadingRecords = false);
      _showToast('加载失败:$e', isError: true);
    }
  }

  Future<void> _deleteRecord(dynamic recordId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确认删除这条专注记录?此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final id = recordId.toString();
      final response = await _dio.delete('/focus/$id');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _showToast('已删除');
        await _loadRecords();
      }
    } catch (e) {
      _showToast('删除失败:$e', isError: true);
    }
  }

  Future<void> _editRecord(Map<String, dynamic> record) async {
    final taskController = TextEditingController(
      text: record['task']?.toString(),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改专注内容'),
        content: TextField(
          controller: taskController,
          decoration: const InputDecoration(
            hintText: '输入新的任务内容',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, taskController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    try {
      final id = record['id'].toString();
      final response = await _dio.put(
        '/focus/$id',
        data: {
          'start_time': record['start_time'],
          'end_time': record['end_time'],
          'task': result.trim(),
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        _showToast('已更新');
        await _loadRecords();
      }
    } catch (e) {
      _showToast('更新失败:$e', isError: true);
    }
  }

  Future<void> _clearAllRecords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确认清空所有专注记录?此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空所有'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _dio.delete('/focus');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _showToast('已清空所有记录');
        await _loadRecords();
      }
    } catch (e) {
      _showToast('清空失败:$e', isError: true);
    }
  }

  // ========== UI 工具 ==========

  void _showToast(String message, {bool isError = false}) {
    final primaryColor = widget.themeManager.getPrimaryColor();
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : primaryColor,
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // ========== 主界面布局 ==========

  @override
  Widget build(BuildContext context) {
    // 响应式布局:根据屏幕宽度判断是否使用侧边栏
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // 桌面端布局(固定侧边栏 + 内容区)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // 固定的窄侧边栏 (只显示图标)
        Sidebar(
          selectedIndex: _selectedIndex,
          onItemTap: (index) {
            setState(() => _selectedIndex = index);
          },
          auth: widget.auth,
          themeManager: widget.themeManager,
          isCompact: true, // 紧凑模式
        ),

        // 主内容区
        Expanded(child: _buildContent()),
      ],
    );
  }

  // 移动端布局(底部导航栏)
  Widget _buildMobileLayout() {
    // 计算移动端当前选中的索引
    int mobileIndex = _mobileIndexMap.indexOf(_selectedIndex);
    if (mobileIndex == -1) {
      // 如果当前页面不在移动端导航中,默认显示第一个(专注)
      mobileIndex = 0;
      _selectedIndex = _mobileIndexMap[0];
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: _buildContent()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: mobileIndex,
        onTap: (index) {
          // 将移动端索引映射到实际页面索引
          setState(() => _selectedIndex = _mobileIndexMap[index]);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: widget.themeManager.getPrimaryColor(),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: '专注'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '记录'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  // 根据选中索引渲染对应内容
  Widget _buildContent() {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    // 移动端特殊处理:索引1显示组合视图
    if (!isDesktop && _selectedIndex == 1) {
      return MobileFocusView(
        auth: widget.auth,
        themeManager: widget.themeManager,
        onFocusCompleted: _loadRecords,
      );
    }

    switch (_selectedIndex) {
      case 0:
        return HomeView(
          auth: widget.auth,
          themeManager: widget.themeManager,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );

      case 1:
        return FocusView(
          auth: widget.auth,
          themeManager: widget.themeManager,
          onFocusCompleted: _loadRecords,
        );

      case 2:
        return AddFocusView(
          auth: widget.auth,
          themeManager: widget.themeManager,
          onFocusAdded: _loadRecords,
        );

      case 3:
        return StatsView(
          auth: widget.auth,
          themeManager: widget.themeManager,
          records: _records,
        );

      case 4:
        return RecordsView(
          auth: widget.auth,
          themeManager: widget.themeManager,
          records: _records,
          loadingRecords: _loadingRecords,
          onRefresh: _loadRecords,
          onClearAll: _clearAllRecords,
          onEdit: _editRecord,
          onDelete: _deleteRecord,
        );

      case 5:
        return SettingsView(
          auth: widget.auth,
          themeManager: widget.themeManager,
          onLogout: () async {
            await widget.auth.logout();
          },
        );

      default:
        return HomeView(
          auth: widget.auth,
          themeManager: widget.themeManager,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
    }
  }
}
