import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/reminder_service.dart';
import 'add_reminder_screen.dart';
import 'punch_record_screen.dart';

class ReminderListScreen extends StatefulWidget {
  const ReminderListScreen({Key? key}) : super(key: key);

  @override
  State<ReminderListScreen> createState() => ReminderListScreenState();
}

class ReminderListScreenState extends State<ReminderListScreen> with WidgetsBindingObserver {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Reminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadReminders();
    }
  }

  Future<void> _loadReminders() async {
    final reminders = await _dbHelper.getReminders();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 自动重置：重复类型的待办事项，完成日期不是今天则重置为未完成
    for (final r in reminders) {
      if (r.itemType == ItemType.todo &&
          r.isCompleted &&
          r.type != ReminderType.specificDate &&
          r.completedDate != null) {
        final completedDate = r.completedDate!;
        final completedDay = DateTime(completedDate.year, completedDate.month, completedDate.day);
        if (completedDay.isBefore(todayDate)) {
          await _dbHelper.markAsCompleted(r.id, false);
        }
      }
    }

    // 重新加载已更新的数据
    final updatedReminders = await _dbHelper.getReminders();
    updatedReminders.sort((a, b) {
      // 已完成的排最后
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      // 都是未完成：待办事项优先
      if (a.itemType != b.itemType) {
        return a.itemType == ItemType.todo ? -1 : 1;
      }
      // 同类型内：先按日期排，再按时间排
      final aDate = a.dueDate ?? DateTime(2000);
      final bDate = b.dueDate ?? DateTime(2000);
      final aDateVal = aDate.year * 10000 + aDate.month * 100 + aDate.day;
      final bDateVal = bDate.year * 10000 + bDate.month * 100 + bDate.day;
      if (aDateVal != bDateVal) return aDateVal.compareTo(bDateVal);
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });
    if (mounted) {
      setState(() {
        _reminders = updatedReminders;
      });
    }
  }

  Future<void> refresh() async {
    await _loadReminders();
  }

  Future<void> _toggleReminder(Reminder reminder) async {
    final updatedReminder = Reminder(
      id: reminder.id,
      name: reminder.name,
      time: reminder.time,
      days: reminder.days,
      isEnabled: !reminder.isEnabled,
      soundPath: reminder.soundPath,
      type: reminder.type,
      customDate: reminder.customDate,
      itemType: reminder.itemType,
      isCompleted: reminder.isCompleted,
      dueDate: reminder.dueDate,
    );
    await _dbHelper.updateReminder(updatedReminder);
    if (updatedReminder.isEnabled && !updatedReminder.isCompleted) {
      await ReminderService().scheduleReminder(updatedReminder);
    } else {
      await ReminderService().cancelReminder(updatedReminder.id);
    }
    _loadReminders();
  }

  Future<void> _toggleTodoCompleted(Reminder reminder, bool completed) async {
    await _dbHelper.markAsCompleted(reminder.id, completed);
    if (completed) {
      ReminderService().cancelReminderInBackground(reminder.id);
    } else if (reminder.isEnabled) {
      ReminderService().scheduleReminderInBackground(_copyReminder(reminder, isCompleted: false));
    }
    _loadReminders();
  }

  Future<void> _deleteReminder(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「$name」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dbHelper.deleteReminder(id);
    setState(() {
      _reminders = _reminders.where((reminder) => reminder.id != id).toList();
    });
    ReminderService().cancelReminderInBackground(id);
  }

  Future<void> _editReminder(Reminder reminder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(existingReminder: reminder),
      ),
    );
    if (result == true) {
      _loadReminders();
    }
  }

  Future<void> _addItem(ItemType type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(initialType: type),
      ),
    );
    if (result == true) {
      _loadReminders();
    }
  }

  Future<void> _showAddMenu() async {
    final type = await showModalBottomSheet<ItemType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('添加打卡提醒'),
              subtitle: const Text('上班、下班或自定义重复提醒'),
              onTap: () => Navigator.pop(context, ItemType.reminder),
            ),
            ListTile(
              leading: const Icon(Icons.check_box_outlined),
              title: const Text('添加待办事项'),
              subtitle: const Text('到指定时间提醒完成事项'),
              onTap: () => Navigator.pop(context, ItemType.todo),
            ),
          ],
        ),
      ),
    );
    if (type != null) {
      _addItem(type);
    }
  }

  Reminder _copyReminder(Reminder reminder, {bool? isCompleted}) {
    return Reminder(
      id: reminder.id,
      name: reminder.name,
      time: reminder.time,
      days: reminder.days,
      isEnabled: reminder.isEnabled,
      soundPath: reminder.soundPath,
      type: reminder.type,
      customDate: reminder.customDate,
      itemType: reminder.itemType,
      isCompleted: isCompleted ?? reminder.isCompleted,
      dueDate: reminder.dueDate,
    );
  }

  DateTime _todoDateTime(Reminder reminder) {
    final date = reminder.dueDate ?? DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
      reminder.time.hour,
      reminder.time.minute,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getReminderTypeText(ReminderType type) {
    switch (type) {
      case ReminderType.daily:
        return '每天';
      case ReminderType.weekdays:
        return '工作日';
      case ReminderType.custom:
        return '自定义';
      case ReminderType.specificDate:
        return '指定日期';
    }
  }

  String _formatDays(List<int> days) {
    const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    if (days.isEmpty) return '';
    return days.map((d) => dayNames[d - 1]).join(' ');
  }

  String _getSubtitle(Reminder reminder) {
    final typeText = _getReminderTypeText(reminder.type);
    if (reminder.type == ReminderType.custom) {
      return '$typeText · ${_formatDays(reminder.days)}';
    }
    if (reminder.type == ReminderType.specificDate && reminder.customDate != null) {
      return '$typeText · ${_formatDate(reminder.customDate!)}';
    }
    return typeText;
  }

  Widget _buildReminderCard(Reminder reminder) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _editReminder(reminder),
        title: Text(
          reminder.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 16,
              ),
            ),
            Text(
              '${_getSubtitle(reminder)} · 点击可编辑',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.isEnabled,
              onChanged: (value) => _toggleReminder(reminder),
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PunchRecordScreen(reminderId: reminder.id),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteReminder(reminder.id, reminder.name),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildTodoCard(Reminder reminder) {
    final timeText = '${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}';
    final typeText = _getSubtitle(reminder);
    final textColor = reminder.isCompleted ? Colors.grey : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _editReminder(reminder),
        leading: Checkbox(
          value: reminder.isCompleted,
          onChanged: (value) => _toggleTodoCompleted(reminder, value ?? false),
        ),
        title: Text(
          reminder.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${reminder.isCompleted ? '已完成' : '待办提醒'} · $timeText · $typeText · 点击可编辑',
          style: TextStyle(fontSize: 12, color: reminder.isCompleted ? Colors.grey : Colors.orange[800]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteReminder(reminder.id, reminder.name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadReminders,
        child: _reminders.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Text(
                      '暂无提醒或待办\n点击右下角添加\n下拉可刷新',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                itemCount: _reminders.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final reminder = _reminders[index];
                  if (reminder.itemType == ItemType.todo) {
                    return _buildTodoCard(reminder);
                  }
                  return _buildReminderCard(reminder);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('设置页面'),
    );
  }
}
