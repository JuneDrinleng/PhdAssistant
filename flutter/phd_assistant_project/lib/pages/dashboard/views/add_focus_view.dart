import 'package:flutter/material.dart';
import '../../../service/auth_service.dart';
import '../../../utils/theme_manager.dart';

class AddFocusView extends StatefulWidget {
  final AuthService auth;
  final ThemeManager themeManager;
  final VoidCallback onFocusAdded;

  const AddFocusView({
    super.key,
    required this.auth,
    required this.themeManager,
    required this.onFocusAdded,
  });

  @override
  State<AddFocusView> createState() => _AddFocusViewState();
}

class _AddFocusViewState extends State<AddFocusView> {
  final _addTaskController = TextEditingController();
  DateTime? _addStartTime;
  DateTime? _addEndTime;

  Color get _primaryColor => widget.themeManager.getPrimaryColor();

  @override
  void dispose() {
    _addTaskController.dispose();
    super.dispose();
  }

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
      final response = await widget.auth.dio.post(
        '/focus',
        data: {
          'start_time': _addStartTime!.toIso8601String(),
          'end_time': _addEndTime!.toIso8601String(),
          'task': task,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _addTaskController.clear();
        setState(() {
          _addStartTime = null;
          _addEndTime = null;
        });

        widget.onFocusAdded();
        _showToast('添加成功 ✅');
      }
    } catch (e) {
      _showToast('添加失败:$e', isError: true);
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
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Container(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.grey.shade50
          : Theme.of(context).scaffoldBackgroundColor,
      child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // 桌面端布局：紧凑型，适配 800x600
  Widget _buildDesktopLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题区域 - 精简
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: _primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '添加专注记录',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '补充之前的专注时光',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 主表单卡片 - 紧凑布局
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间选择区 - 横向紧凑排列
                  Row(
                    children: [
                      Icon(Icons.schedule, color: _primaryColor, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        '时间范围',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_addStartTime != null && _addEndTime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: _primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_addEndTime!.difference(_addStartTime!).inMinutes}分钟',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactTimeSelector(
                          context,
                          '开始',
                          _addStartTime,
                          Icons.play_circle_outline,
                          (time) => setState(() => _addStartTime = time),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.grey.shade400,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: _buildCompactTimeSelector(
                          context,
                          '结束',
                          _addEndTime,
                          Icons.stop_circle_outlined,
                          (time) => setState(() => _addEndTime = time),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 任务内容区 - 减小高度
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: _primaryColor, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        '专注内容',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _addTaskController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '描述你专注完成的任务...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 提交按钮 - 稍小
            Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _submitFocusPlan,
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '添加记录',
                          style: TextStyle(
                            fontSize: 16,
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
    );
  }

  // 移动端布局：保持原有布局
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // 标题区域
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: _primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '添加专注记录',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '补充之前的专注时光',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // 时间选择卡片
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
                      Icon(Icons.schedule, color: _primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '时间范围',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeSelector(
                          context,
                          '开始',
                          _addStartTime,
                          Icons.play_circle_outline,
                          (time) => setState(() => _addStartTime = time),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: _buildTimeSelector(
                          context,
                          '结束',
                          _addEndTime,
                          Icons.stop_circle_outlined,
                          (time) => setState(() => _addEndTime = time),
                        ),
                      ),
                    ],
                  ),
                  if (_addStartTime != null && _addEndTime != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: _primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '时长: ${_addEndTime!.difference(_addStartTime!).inMinutes}分钟',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 任务内容卡片
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
                      Icon(Icons.edit_note, color: _primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '专注内容',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addTaskController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '描述你专注完成的任务...\n例如：完成了数学作业、阅读了30页书',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 提交按钮
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _submitFocusPlan,
                  borderRadius: BorderRadius.circular(16),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '添加记录',
                          style: TextStyle(
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
    );
  }

  // 桌面端紧凑型时间选择器
  Widget _buildCompactTimeSelector(
    BuildContext context,
    String label,
    DateTime? selectedTime,
    IconData icon,
    Function(DateTime) onTimeSelected,
  ) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: _primaryColor),
              ),
              child: child!,
            );
          },
        );
        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(primary: _primaryColor),
                ),
                child: child!,
              );
            },
          );
          if (time != null) {
            onTimeSelected(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selectedTime != null
              ? _primaryColor.withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedTime != null
                ? _primaryColor.withOpacity(0.3)
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selectedTime != null
                  ? _primaryColor
                  : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              selectedTime == null
                  ? '未选择'
                  : '${selectedTime.month}/${selectedTime.day} '
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: selectedTime != null
                    ? _primaryColor
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 移动端时间选择器
  Widget _buildTimeSelector(
    BuildContext context,
    String label,
    DateTime? selectedTime,
    IconData icon,
    Function(DateTime) onTimeSelected,
  ) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: _primaryColor),
              ),
              child: child!,
            );
          },
        );
        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(primary: _primaryColor),
                ),
                child: child!,
              );
            },
          );
          if (time != null) {
            onTimeSelected(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectedTime != null
              ? _primaryColor.withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedTime != null
                ? _primaryColor.withOpacity(0.3)
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selectedTime != null
                  ? _primaryColor
                  : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selectedTime == null
                  ? '未选择'
                  : '${selectedTime.month}/${selectedTime.day} '
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: selectedTime != null
                    ? _primaryColor
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
