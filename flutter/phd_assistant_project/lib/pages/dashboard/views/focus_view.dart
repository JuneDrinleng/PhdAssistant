import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../service/auth_service.dart';
import '../../../utils/theme_manager.dart';

class FocusView extends StatefulWidget {
  final AuthService auth;
  final ThemeManager themeManager;
  final VoidCallback onFocusCompleted;

  const FocusView({
    super.key,
    required this.auth,
    required this.themeManager,
    required this.onFocusCompleted,
  });

  @override
  State<FocusView> createState() => _FocusViewState();
}

class _FocusViewState extends State<FocusView> with TickerProviderStateMixin {
  Timer? _focusTimer;
  DateTime? _focusStartTime;
  String _focusTask = '';
  int _elapsedSeconds = 0;
  bool _isFocusing = false;
  final _focusTaskController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Color get _primaryColor => widget.themeManager.getPrimaryColor();

  @override
  void initState() {
    super.initState();
    _loadFocusState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _focusTaskController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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
      _showToast('开始专注 💪');
    } else {
      // 结束专注
      if (_focusStartTime == null) return;

      try {
        final response = await widget.auth.dio.post(
          '/focus',
          data: {
            'start_time': _focusStartTime!.toIso8601String(),
            'end_time': DateTime.now().toIso8601String(),
            'task': _focusTask,
          },
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          _focusTimer?.cancel();
          _focusTimer = null;

          setState(() {
            _focusStartTime = null;
            _focusTask = '';
            _isFocusing = false;
            _elapsedSeconds = 0;
            _focusTaskController.clear();
          });

          await _saveFocusState();
          widget.onFocusCompleted();
          _showToast('完成专注 ✅');
        }
      } catch (e) {
        _showToast('保存失败:$e', isError: true);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.grey.shade50
          : Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // 大圆形计时器显示区
              ScaleTransition(
                scale: _isFocusing
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _primaryColor.withOpacity(0.1),
                        _primaryColor.withOpacity(0.2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatDuration(_elapsedSeconds),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: _primaryColor,
                            letterSpacing: 2,
                          ),
                        ),
                        if (_isFocusing) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '专注中',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // 任务输入卡片
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: _primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '当前任务',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _focusTaskController,
                      readOnly: _isFocusing,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '输入你要专注的内容...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: _isFocusing
                            ? Colors.grey.shade100.withOpacity(0.5)
                            : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 控制按钮
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isFocusing
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : [_primaryColor, _primaryColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_isFocusing ? Colors.red : _primaryColor)
                          .withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleFocus,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isFocusing
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isFocusing ? '结束专注' : '开始专注',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
        ),
      ),
    );
  }
}
