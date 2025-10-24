import 'package:flutter/material.dart';
import '../../../service/auth_service.dart';
import '../../../utils/theme_manager.dart';

class StatsView extends StatefulWidget {
  final AuthService auth;
  final ThemeManager themeManager;
  final List<Map<String, dynamic>> records;

  const StatsView({
    super.key,
    required this.auth,
    required this.themeManager,
    required this.records,
  });

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  String _statsScope = 'week';
  Map<String, int> _taskMinutes = {};
  int _totalMinutes = 0;
  int _avgMinutes = 0;

  Color get _primaryColor => widget.themeManager.getPrimaryColor();

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  @override
  void didUpdateWidget(StatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records) {
      _calculateStats();
    }
  }

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

    for (final record in widget.records) {
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
      return '${hours}h${mins}min';
    }
    return '${minutes}min';
  }

  Color _getTaskColor(int index) {
    final colors = [
      _primaryColor,
      Colors.purple.shade400,
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.pink.shade400,
    ];
    return colors[index % colors.length];
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
                      Icons.bar_chart_rounded,
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
                          '专注统计',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '查看你的专注数据',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 时间范围选择
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildStatsTab('今日', 'day', Icons.today),
                    _buildStatsTab('本周', 'week', Icons.date_range),
                    _buildStatsTab('本月', 'month', Icons.calendar_month),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 总览卡片
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '总计',
                      _formatMinutes(_totalMinutes),
                      Icons.access_time_filled,
                      _primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      '日均',
                      _formatMinutes(_avgMinutes),
                      Icons.trending_up,
                      Colors.green.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 任务统计
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
                        Icon(
                          Icons.pie_chart_rounded,
                          color: _primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '任务分布',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_taskMinutes.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '该时间段暂无数据',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._taskMinutes.entries.toList().asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final taskEntry = entry.value;
                        final percent =
                            (_totalMinutes > 0
                                    ? (taskEntry.value / _totalMinutes) * 100
                                    : 0)
                                .toStringAsFixed(1);
                        final color = _getTaskColor(index);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      taskEntry.key,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$percent%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: _totalMinutes > 0
                                            ? taskEntry.value / _totalMinutes
                                            : 0,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              color,
                                            ),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _formatMinutes(taskEntry.value),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(String label, String scope, IconData icon) {
    final isActive = _statsScope == scope;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _statsScope = scope);
            _calculateStats();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? _primaryColor.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? _primaryColor : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? _primaryColor : Colors.grey.shade600,
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
