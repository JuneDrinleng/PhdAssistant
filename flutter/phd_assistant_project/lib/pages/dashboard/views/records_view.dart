import 'package:flutter/material.dart';
import '../../../service/auth_service.dart';
import '../../../utils/theme_manager.dart';

class RecordsView extends StatelessWidget {
  final AuthService auth;
  final ThemeManager themeManager;
  final List<Map<String, dynamic>> records;
  final bool loadingRecords;
  final VoidCallback onRefresh;
  final VoidCallback onClearAll;
  final Function(Map<String, dynamic>) onEdit;
  final Function(dynamic) onDelete;

  const RecordsView({
    super.key,
    required this.auth,
    required this.themeManager,
    required this.records,
    required this.loadingRecords,
    required this.onRefresh,
    required this.onClearAll,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _primaryColor => themeManager.getPrimaryColor();

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) return '${hours}小时';
      return '${hours}小时${mins}分钟';
    }
    return '${minutes}分钟';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recordDate = DateTime(date.year, date.month, date.day);

    if (recordDate == today) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (recordDate == yesterday) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(date).inDays < 7) {
      final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      return '周${weekdays[date.weekday - 1]} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
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

  // 按日期分组记录
  Map<String, List<Map<String, dynamic>>> _groupRecordsByDate(
    List<Map<String, dynamic>> records,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final record in records) {
      try {
        final start = DateTime.parse(record['start_time'].toString());
        final recordDate = DateTime(start.year, start.month, start.day);

        String dateKey;
        if (recordDate == today) {
          dateKey = '今天';
        } else if (recordDate == yesterday) {
          dateKey = '昨天';
        } else {
          dateKey = '${start.month}月${start.day}日';
        }

        grouped.putIfAbsent(dateKey, () => []);
        grouped[dateKey]!.add(record);
      } catch (e) {
        continue;
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;

    if (isMobile) {
      return _buildMobileView(context);
    } else {
      return _buildDesktopView(context);
    }
  }

  Widget _buildMobileView(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.grey.shade50
          : Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // 标题区域
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.list_alt,
                          color: _primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '专注记录',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              records.isEmpty
                                  ? '记录你的专注时光'
                                  : '共 ${records.length} 条记录',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 刷新按钮
                      Container(
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: loadingRecords ? null : onRefresh,
                          icon: Icon(
                            Icons.refresh,
                            color: loadingRecords ? Colors.grey : _primaryColor,
                          ),
                          tooltip: '刷新',
                        ),
                      ),
                      if (records.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            onPressed: () => _showClearDialog(context),
                            icon: Icon(
                              Icons.delete_sweep,
                              color: Colors.red.shade400,
                            ),
                            tooltip: '清空全部',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 记录列表
            Expanded(
              child: loadingRecords
                  ? Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    )
                  : _buildMobileRecordsList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRecordsList(BuildContext context) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '暂无专注记录',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '开始你的第一次专注吧',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // 排序记录（最新的在前）
    final sortedRecords = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) {
        final aStart = DateTime.parse(a['start_time'].toString());
        final bStart = DateTime.parse(b['start_time'].toString());
        return bStart.compareTo(aStart);
      });

    final groupedRecords = _groupRecordsByDate(sortedRecords);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: groupedRecords.length,
      itemBuilder: (context, groupIndex) {
        final dateKey = groupedRecords.keys.elementAt(groupIndex);
        final dateRecords = groupedRecords[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期分隔
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            // 该日期下的记录
            ...dateRecords.asMap().entries.map((entry) {
              final recordIndex = entry.key;
              final record = entry.value;
              return _buildMobileRecordCard(context, record, recordIndex);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildMobileRecordCard(
    BuildContext context,
    Map<String, dynamic> record,
    int index,
  ) {
    DateTime? startTime;
    DateTime? endTime;
    try {
      startTime = DateTime.parse(record['start_time'].toString());
      endTime = DateTime.parse(record['end_time'].toString());
    } catch (e) {
      return const SizedBox.shrink();
    }

    final task = record['task']?.toString() ?? '(未命名)';
    final recordId = record['id'];
    final duration = endTime.difference(startTime);

    return Dismissible(
      key: Key('record_$recordId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) => _showDeleteDialog(context, task),
      onDismissed: (direction) => onDelete(recordId),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onEdit(record),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 左侧色块图标
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getTaskColor(index).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.timer_outlined,
                      color: _getTaskColor(index),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 中间内容区
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - '
                              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 右侧时长标签
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getTaskColor(index).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${duration.inMinutes}min',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getTaskColor(index),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopView(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.grey.shade50
          : Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        Icons.list_alt,
                        color: _primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '专注记录',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            records.isEmpty
                                ? '记录你的专注时光'
                                : '共 ${records.length} 条记录',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (records.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _showClearDialog(context),
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('清空全部'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: loadingRecords ? null : onRefresh,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('刷新'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor.withOpacity(0.12),
                        foregroundColor: _primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 记录列表容器
                Container(
                  constraints: const BoxConstraints(minHeight: 400),
                  padding: const EdgeInsets.all(24),
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
                  child: loadingRecords
                      ? Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                          ),
                        )
                      : records.isEmpty
                      ? _buildEmptyState(context)
                      : _buildDesktopRecordsList(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopRecordsList(BuildContext context) {
    // 排序记录（最新的在前）
    final sortedRecords = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) {
        final aStart = DateTime.parse(a['start_time'].toString());
        final bStart = DateTime.parse(b['start_time'].toString());
        return bStart.compareTo(aStart);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedRecords.asMap().entries.map((entry) {
        final index = entry.key;
        final record = entry.value;
        return _buildDesktopRecordCard(context, record, index);
      }).toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '暂无专注记录',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '开始你的第一次专注吧',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRecordCard(
    BuildContext context,
    Map<String, dynamic> record,
    int index,
  ) {
    DateTime? startTime;
    DateTime? endTime;
    try {
      startTime = DateTime.parse(record['start_time'].toString());
      endTime = DateTime.parse(record['end_time'].toString());
    } catch (e) {
      return const SizedBox.shrink();
    }

    final duration = endTime.difference(startTime);
    final task = record['task']?.toString() ?? '(无任务名)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getTaskColor(index).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getTaskColor(index).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getTaskColor(index).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: _getTaskColor(index),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(startTime)} → ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getTaskColor(index).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatMinutes(duration.inMinutes),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _getTaskColor(index),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: _primaryColor),
            onPressed: () => onEdit(record),
            tooltip: '编辑',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
            onPressed: () =>
                _showDeleteDialogDesktop(context, record['id'], task),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteDialog(BuildContext context, String task) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('确认删除'),
            content: Text('确定要删除「$task」这条记录吗?'),
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
        ) ??
        false;
  }

  void _showDeleteDialogDesktop(
    BuildContext context,
    dynamic recordId,
    String task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('确认删除'),
        content: Text('确定要删除「$task」这条记录吗?'),
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

    if (confirmed == true) {
      onDelete(recordId);
    }
  }

  void _showClearDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('确认清空'),
        content: Text('确定要清空全部 ${records.length} 条记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onClearAll();
    }
  }
}
