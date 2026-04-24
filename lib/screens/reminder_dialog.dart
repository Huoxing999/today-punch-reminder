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
                const Icon(
                  Icons.alarm,
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
                const Text(
                  '请立即处理本次打卡提醒',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _processing ? null : _onPunch,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text(
                    '立即打卡',
                    style: TextStyle(fontSize: 20),
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
                  child: const Text(
                    '关闭本轮提醒',
                    style: TextStyle(fontSize: 18),
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