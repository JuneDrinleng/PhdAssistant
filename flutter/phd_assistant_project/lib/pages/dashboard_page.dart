import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/auth_service.dart';
import '../utils/theme_manager.dart';
import 'dashboard/widgets/sidebar.dart';

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
  bool _sidebarCollapsed = false;

  // 专注计时器
  Timer? _focusTimer;
  DateTime? _focusStartTime;
  String _focusTask = '';
  int _elapsedSeconds = 0;
  bool _isFocusing = false;
  final _focusTaskController = TextEditingController();

  // 记录列表
  List<Map<String, dynamic>> _records = [];
  bool _loadingRecords = false;

  // 统计
  String _statsScope = 'week';
  Map<String, int> _taskMinutes = {};
  int _totalMinutes = 0;
  int _avgMinutes = 0;

  // 添加专注时间
  final _addTaskController = TextEditingController();
  DateTime? _addStartTime;
  DateTime? _addEndTime;

  // 辅助方法获取主题色
  Color get _primaryColor => widget.themeManager.getPrimaryColor();

  @override
  void initState() {
    super.initState();
    _loadFocusState();
    _loadRecords();
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _focusTaskController.dispose();
    _addTaskController.dispose();
    super.dispose();
  }

  // 使用 AuthService 的 Dio 实例
  Dio get _dio => widget.auth.dio;

  // ========== 专注计时器功能 ==========

  Future<void> _loadFocusState() async {
    final prefs = await SharedPreferences.getInstance();
    final startStr = prefs.getString('liveFocusStart');
    final task = prefs.getString('liveFocusTask') ?? '';

    if (startStr != null) {
      setState(() {
        _focusStartTime = DateTime.parse(startStr);
        _focusTask = task;
        _isFocusing = true;
        _focusTaskController.text = task;
      });
      _startTimer();
    }
  }

  Future<void> _saveFocusState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_focusStartTime != null) {
      await prefs.setString(
        'liveFocusStart',
        _focusStartTime!.toIso8601String(),
      );
      await prefs.setString('liveFocusTask', _focusTask);
    } else {
      await prefs.remove('liveFocusStart');
      await prefs.remove('liveFocusTask');
    }
  }

  void _startTimer() {
    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_focusStartTime != null) {
        setState(() {
          _elapsedSeconds = DateTime.now()
              .difference(_focusStartTime!)
              .inSeconds;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleFocus() async {
    if (!_isFocusing) {
      // 开始专注
      final task = _focusTaskController.text.trim();
      if (task.isEmpty) {
        _showToast('请输入专注内容', isError: true);
        return;
      }

      setState(() {
        _focusStartTime = DateTime.now();
        _focusTask = task;
        _isFocusing = true;
        _elapsedSeconds = 0;
      });
      await _saveFocusState();
      _startTimer();
      _showToast('开始专注');
    } else {
      // 结束专注
      if (_focusStartTime == null) return;

      try {
        final response = await _dio.post(
          '/focus',
          data: {
            'start_time': _focusStartTime!.toIso8601String(),
            'end_time': DateTime.now().toIso8601String(),
            'task': _focusTask,
          },
        );

        // 后端返回 201 Created
        if (response.statusCode == 201 || response.statusCode == 200) {
          // 先停止计时器
          _focusTimer?.cancel();
          _focusTimer = null;

          // 清空状态
          setState(() {
            _focusStartTime = null;
            _focusTask = '';
            _isFocusing = false;
            _elapsedSeconds = 0;
            _focusTaskController.clear();
          });

          // 保存到本地
          await _saveFocusState();

          // 刷新记录
          await _loadRecords();

          _showToast('保存成功 ✅', showViewRecords: true);
        }
      } catch (e) {
        _showToast('保存失败：$e', isError: true);
      }
    }
  }

  // ========== 添加专注时间 ==========

  Future<void> _submitFocusPlan() async {
    final task = _addTaskController.text.trim();
    if (task.isEmpty || _addStartTime == null || _addEndTime == null) {
      _showToast('请完整填写所有信息', isError: true);
      return;
    }

    if (_addEndTime!.isBefore(_addStartTime!)) {
      _showToast('结束时间必须晚于开始时间', isError: true);
      return;
    }

    try {
      final response = await _dio.post(
        '/focus',
        data: {
          'start_time': _addStartTime!.toIso8601String(),
          'end_time': _addEndTime!.toIso8601String(),
          'task': task,
        },
      );

      // 后端返回 201 Created
      if (response.statusCode == 201 || response.statusCode == 200) {
        // 清空表单
        _addTaskController.clear();
        setState(() {
          _addStartTime = null;
          _addEndTime = null;
        });

        // 刷新记录列表
        await _loadRecords();

        _showToast('✅ 已发送！', showViewRecords: true);
      }
    } catch (e) {
      _showToast('发送失败：$e', isError: true);
    }
  }

  // ========== 记录管理 ==========

  Future<void> _loadRecords() async {
    setState(() => _loadingRecords = true);

    try {
      final response = await _dio.get('/focus?limit=500');

      if (response.statusCode == 200) {
        final data = response.data;

        // 后端直接返回数组
        if (data is List) {
          setState(() {
            _records = List<Map<String, dynamic>>.from(
              data.map((item) => item as Map<String, dynamic>),
            );
            _loadingRecords = false;
          });
          _calculateStats();
        } else {
          throw Exception('Unexpected response format');
        }
      }
    } catch (e) {
      setState(() => _loadingRecords = false);
      _showToast('加载失败：$e', isError: true);
    }
  }

  Future<void> _deleteRecord(dynamic recordId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确认删除这条专注记录？此操作不可撤销。'),
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
      // 兼容 id 可能是 int 或 String
      final id = recordId.toString();
      final response = await _dio.delete('/focus/$id');

      // 后端返回 204 No Content
      if (response.statusCode == 204 || response.statusCode == 200) {
        _showToast('已删除');
        await _loadRecords();
      }
    } catch (e) {
      _showToast('删除失败：$e', isError: true);
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

      // 后端返回 204 No Content
      if (response.statusCode == 204 || response.statusCode == 200) {
        _showToast('已更新');
        await _loadRecords();
      }
    } catch (e) {
      _showToast('更新失败：$e', isError: true);
    }
  }

  Future<void> _clearAllRecords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确认清空所有专注记录？此操作不可撤销。'),
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
      _showToast('清空失败：$e', isError: true);
    }
  }

  // ========== 统计功能 ==========

  void _calculateStats() {
    final now = DateTime.now();
    final taskMins = <String, int>{};
    int totalMins = 0;
    final daysInRange = <String>{};

    DateTime? rangeStart;
    if (_statsScope == 'day') {
      rangeStart = DateTime(now.year, now.month, now.day);
    } else if (_statsScope == 'week') {
      final weekday = now.weekday;
      rangeStart = now.subtract(Duration(days: weekday - 1));
      rangeStart = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    } else if (_statsScope == 'month') {
      rangeStart = DateTime(now.year, now.month, 1);
    }

    for (final record in _records) {
      try {
        final start = DateTime.parse(record['start_time'].toString());
        final end = DateTime.parse(record['end_time'].toString());

        if (rangeStart != null && start.isBefore(rangeStart)) continue;

        final minutes = end.difference(start).inMinutes;
        totalMins += minutes;

        final task = record['task']?.toString() ?? '(未命名)';
        taskMins[task] = (taskMins[task] ?? 0) + minutes;

        daysInRange.add(
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
        );
      } catch (e) {
        // 跳过解析失败的记录
        continue;
      }
    }

    setState(() {
      _taskMinutes = taskMins;
      _totalMinutes = totalMins;
      _avgMinutes = daysInRange.isNotEmpty
          ? totalMins ~/ daysInRange.length
          : 0;
    });
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}小时${mins}分';
    }
    return '${minutes}分';
  }

  // ========== UI 工具 ==========

  void _showToast(
    String message, {
    bool isError = false,
    bool showViewRecords = false,
  }) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : _primaryColor,
      duration: const Duration(seconds: 2),
      action: showViewRecords
          ? SnackBarAction(
              label: '查看记录',
              textColor: Colors.white,
              onPressed: () {
                setState(() => _selectedIndex = 4);
              },
            )
          : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  final List<_MenuItem> _menuItems = [
    _MenuItem(icon: Icons.home, label: '主页'),
    _MenuItem(icon: Icons.timer, label: '专注'),
    _MenuItem(icon: Icons.add_box_outlined, label: '添加专注时间'),
    _MenuItem(icon: Icons.bar_chart, label: '统计'),
    _MenuItem(icon: Icons.list, label: '查看记录'),
    _MenuItem(icon: Icons.settings, label: '设置'),
  ];

  void _toggleSidebar() {
    setState(() {
      _sidebarCollapsed = !_sidebarCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.auth.user?['username']?.toString() ?? '未登录';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // 侧边栏
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _sidebarCollapsed ? 0 : 260,
            child: _sidebarCollapsed ? null : _buildSidebar(username),
          ),

          // 主内容区
          Expanded(
            child: Column(
              children: [
                if (_sidebarCollapsed) _buildTopBar(),
                Expanded(child: _buildContent(username)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(String username) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _toggleSidebar,
                  icon: const Icon(Icons.menu),
                  color: _primaryColor,
                ),
                const SizedBox(width: 8),
                Text('专注小助手', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),

          // 菜单
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isActive = _selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        // 切换到统计页时重新计算
                        if (index == 3) _calculateStats();
                        // 切换到记录页时重新加载
                        if (index == 4) _loadRecords();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (widget.themeManager.currentTheme ==
                                        AppTheme.dark
                                    ? const Color.fromARGB(
                                        255,
                                        255,
                                        255,
                                        255,
                                      ) // ✅ 暗色模式下选中用更浅的灰色
                                    : _primaryColor.withOpacity(
                                        0.15,
                                      )) // 其他主题保持原样
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
                );
              },
            ),
          ),

          // 退出登录
          Container(
            padding: const EdgeInsets.all(10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await widget.auth.logout();
                  if (mounted) context.go('/login');
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        size: 20,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(
                                255,
                                255,
                                255,
                                255,
                              ) // ✅ 暗色模式用亮红色
                            : _primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '退出登录',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(
                                  255,
                                  255,
                                  255,
                                  255,
                                ) // ✅ 暗色模式用亮红色
                              : _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleSidebar,
            icon: const Icon(Icons.menu),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String username) {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage(username);
      case 1:
        return _buildFocusPage();
      case 2:
        return _buildAddFocusPage();
      case 3:
        return _buildStatsPage();
      case 4:
        return _buildRecordsPage();
      case 5:
        return _buildSettingsPage(username);
      default:
        return _buildHomePage(username);
    }
  }

  // ========== 各页面 UI ==========

  Widget _buildHomePage(String username) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('👋', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                'Welcome, $username!',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '祝你度过一个愉快而高效的一天~',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildQuickAction(Icons.timer, '专注', 1),
                  const SizedBox(width: 12),
                  _buildQuickAction(Icons.add_box_outlined, '添加', 2),
                  const SizedBox(width: 12),
                  _buildQuickAction(Icons.list, '记录', 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, int index) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          // 切换到统计页时重新计算
          if (index == 3) _calculateStats();
          // 切换到记录页时重新加载
          if (index == 4) _loadRecords();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _primaryColor, size: 28),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusPage() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 专注',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 30),
                  Text('当前任务', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _focusTaskController,
                    readOnly: _isFocusing,
                    decoration: InputDecoration(
                      hintText: '输入你要专注的内容…',
                      filled: true,
                      fillColor: _isFocusing
                          ? Theme.of(context).disabledColor.withOpacity(0.1)
                          : Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text('已用时', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_elapsedSeconds),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _toggleFocus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _isFocusing ? '结束专注' : '开始专注',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildAddFocusPage() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⏰ 添加专注时间',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 30),

                  // 时间选择（开始和结束在同一行）
                  Text('时间选择', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 开始时间
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '开始时间',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _addStartTime = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _addStartTime == null
                                      ? '选择'
                                      : '${_addStartTime!.month}/${_addStartTime!.day} '
                                            '${_addStartTime!.hour.toString().padLeft(2, '0')}:${_addStartTime!.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _addStartTime == null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      // 结束时间
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '结束时间',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _addEndTime = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _addEndTime == null
                                      ? '选择'
                                      : '${_addEndTime!.month}/${_addEndTime!.day} '
                                            '${_addEndTime!.hour.toString().padLeft(2, '0')}:${_addEndTime!.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _addEndTime == null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text('专注内容', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addTaskController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '描述你要专注的任务...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitFocusPlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '🚀 发送专注计划',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildStatsPage() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📊 专注统计',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatsTab('日', 'day'),
                      const SizedBox(width: 8),
                      _buildStatsTab('周', 'week'),
                      const SizedBox(width: 8),
                      _buildStatsTab('月', 'month'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '总计 ${_formatMinutes(_totalMinutes)}　日均 ${_formatMinutes(_avgMinutes)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_taskMinutes.isEmpty)
                    Column(
                      children: [
                        Icon(Icons.bar_chart, size: 100, color: _primaryColor),
                        const SizedBox(height: 20),
                        Text(
                          '暂无数据',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    )
                  else
                    ..._taskMinutes.entries.map((entry) {
                      final percent =
                          (_totalMinutes > 0
                                  ? (entry.value / _totalMinutes) * 100
                                  : 0)
                              .toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${_formatMinutes(entry.value)} ($percent%)',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _totalMinutes > 0
                                  ? entry.value / _totalMinutes
                                  : 0,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _primaryColor,
                              ),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab(String label, String scope) {
    final isActive = _statsScope == scope;
    return Material(
      color: isActive
          ? _primaryColor.withOpacity(0.18)
          : Colors.black.withOpacity(0.05),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          setState(() => _statsScope = scope);
          _calculateStats();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? _primaryColor.withOpacity(0.22)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? _primaryColor
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordsPage() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '🗂️ 专注记录',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const Spacer(),
                if (_records.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _clearAllRecords,
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('清空'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromARGB(255, 139, 53, 53) // ✅ 暗色模式：亮红色
                          : Colors.red,
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(
                                255,
                                139,
                                53,
                                53,
                              ) // ✅ 边框也用亮红色
                            : Colors.red,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loadingRecords ? null : _loadRecords,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('刷新'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF374151) // ✅ 暗色：深灰背景
                        : _primaryColor.withOpacity(0.12),
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF3F4F6) // ✅ 暗色：白色文字和图标
                        : _primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _primaryColor.withOpacity(0.1),
                      _primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _loadingRecords
                    ? Center(
                        child: CircularProgressIndicator(color: _primaryColor),
                      )
                    : _records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无记录',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final record = _records[index];

                          // 安全地解析时间
                          DateTime? start;
                          DateTime? end;
                          try {
                            start = DateTime.parse(
                              record['start_time'].toString(),
                            );
                            end = DateTime.parse(record['end_time'].toString());
                          } catch (e) {
                            // 解析失败，跳过这条记录
                            return const SizedBox.shrink();
                          }

                          final duration = end.difference(start);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                record['task']?.toString() ?? '(无任务名)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                '${start.month}/${start.day} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} → '
                                '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color.fromARGB(
                                              255,
                                              200,
                                              200,
                                              200,
                                            ) // ✅ 暗色模式用浅色文字
                                          : null, // 浅色模式保持默认
                                    ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _formatMinutes(duration.inMinutes),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(
                                                0xFFF3F4F6,
                                              ) // ✅ 暗色模式：白色文字
                                            : _primaryColor,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF3F4F6) // ✅ 暗色：白色图标
                                          : _primaryColor,
                                    ),
                                    onPressed: () => _editRecord(record),
                                    tooltip: '编辑',
                                    padding: EdgeInsets.all(8),
                                    constraints: BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color.fromARGB(
                                              255,
                                              139,
                                              53,
                                              53,
                                            ) // ✅ 暗色模式：亮红色
                                          : Colors.red, // 浅色模式：深红色
                                    ),
                                    onPressed: () =>
                                        _deleteRecord(record['id']),
                                    tooltip: '删除',
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPage(String username) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚙️ 设置',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 30),
                  Text('用户名', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: username),
                    readOnly: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).disabledColor.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.palette, size: 18, color: _primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              '主题颜色',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _primaryColor,
                                _primaryColor.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildThemeChip('Red', AppTheme.red),
                            _buildThemeChip('Blue', AppTheme.blue),
                            _buildThemeChip('Purple', AppTheme.purple),
                            _buildThemeChip('Green', AppTheme.green),
                            _buildThemeChip('Dark', AppTheme.dark),
                          ],
                        ),
                      ],
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

  Widget _buildThemeChip(String label, AppTheme theme) {
    final isActive = widget.themeManager.currentTheme == theme;

    return Material(
      color: isActive
          ? _primaryColor.withOpacity(0.18)
          : Colors.black.withOpacity(0.05),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          widget.themeManager.setTheme(theme);
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? _primaryColor.withOpacity(0.22)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? _primaryColor
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;

  _MenuItem({required this.icon, required this.label});
}
