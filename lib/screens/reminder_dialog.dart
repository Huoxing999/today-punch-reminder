import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/reminder_service.dart';

class ReminderDialog extends StatefulWidget {
  final Reminder reminder;
  final ReminderService reminderService;

  const ReminderDialog({
    Key? key,
    required this.reminder,
    required this.reminderService,
  }) : super(key: key);

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final timeText =
        '${widget.reminder.time.hour.toString().padLeft(2, '0')}:${widget.reminder.time.minute.toString().padLeft(2, '0')}';
    final isTodo = widget.reminder.itemType == ItemType.todo;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  isTodo ? Icons.check_box_outlined : Icons.alarm,
                  color: Colors.white,
                  size: 72,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.reminder.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  timeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isTodo ? '请处理本次待办事项' : '请立即处理本次打卡提醒',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _processing ? null : (isTodo ? _onCompleteTodo : _onPunch),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(
                    isTodo ? '标记完成' : '立即打卡',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _processing ? null : _onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(
                    isTodo ? '稍后处理' : '关闭本轮提醒',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onDismiss() async {
    setState(() {
      _processing = true;
    });
    await widget.reminderService.dismissReminder();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onCompleteTodo() async {
    setState(() {
      _processing = true;
    });
    await DatabaseHelper().markAsCompleted(widget.reminder.id, true);
    await widget.reminderService.dismissReminder();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('待办事项已完成！')),
    );
  }

  Future<void> _onPunch() async {
    setState(() {
      _processing = true;
    });
    final db = DatabaseHelper();
    await db.insertPunchRecord(widget.reminder.id, DateTime.now());
    await widget.reminderService.dismissReminder();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打卡成功！')),
    );
  }
}
