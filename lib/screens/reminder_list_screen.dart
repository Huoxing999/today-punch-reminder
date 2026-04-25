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
    reminders.sort((a, b) {
      if (a.itemType == ItemType.todo && b.itemType == ItemType.todo) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return _todoDateTime(a).compareTo(_todoDateTime(b));
      }
      if (a.itemType == ItemType.todo && !a.isCompleted) return -1;
      if (b.itemType == ItemType.todo && !b.isCompleted) return 1;
      return a.id.compareTo(b.id);
    });
    if (mounted) {
      setState(() {
        _reminders = reminders;
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

  Future<void> _deleteReminder(int id) async {
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
              onPressed: () => _deleteReminder(reminder.id),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildTodoCard(Reminder reminder) {
    final dueDate = reminder.dueDate;
    final timeText = '${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}';
    final subtitle = dueDate == null ? timeText : '${_formatDate(dueDate)} $timeText';
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
          '${reminder.isCompleted ? '已完成' : '待办提醒'} · $subtitle · 点击可编辑',
          style: TextStyle(fontSize: 12, color: reminder.isCompleted ? Colors.grey : Colors.orange[800]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteReminder(reminder.id),
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
