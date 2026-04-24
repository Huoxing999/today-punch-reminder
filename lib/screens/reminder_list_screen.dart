import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/reminder_service.dart';
import 'add_reminder_screen.dart';
import 'punch_record_screen.dart';

class ReminderListScreen extends StatefulWidget {
  const ReminderListScreen({Key? key}) : super(key: key);

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Reminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final reminders = await _dbHelper.getReminders();
    setState(() {
      _reminders = reminders;
    });
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
    );
    await _dbHelper.updateReminder(updatedReminder);
    if (updatedReminder.isEnabled) {
      await ReminderService().scheduleReminder(updatedReminder);
    } else {
      await ReminderService().cancelReminder(updatedReminder.id);
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
      return '$typeText · ${reminder.customDate!.year}-${reminder.customDate!.month.toString().padLeft(2, '0')}-${reminder.customDate!.day.toString().padLeft(2, '0')}';
    }
    return typeText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _reminders.isEmpty
          ? const Center(
              child: Text(
                '暂无提醒\n点击右下角添加',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _reminders.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final reminder = _reminders[index];
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
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddReminderScreen()),
          );
          if (result == true) {
            _loadReminders();
          }
        },
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