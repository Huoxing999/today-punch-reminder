import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import '../services/database_service.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  static const MethodChannel _alarmPermissionChannel = MethodChannel(
    'attendance_reminder_app/alarm_permissions',
  );
  static final RegExp _notificationIdPattern = RegExp(r'^(\d+)$');
  static const int _daysToSchedule = 7;
  static const int _repeatEveryMinutes = 5;
  static const int _repeatCount = 4;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Timer? _checkTimer;
  Reminder? _currentActiveReminder;
  int? _currentNotificationId;
  bool _isPlaying = false;
  bool _initialized = false;
  bool _initializing = false;
  Future<void>? _initializationFuture;
  Function(Reminder)? onReminderTriggered;

  Future<void> initialize({bool reschedule = true}) {
    if (_initialized) {
      return reschedule ? rescheduleAllReminders() : Future.value();
    }

    if (_initializing) {
      return _initializationFuture ?? Future.value();
    }

    _initializing = true;
    _initializationFuture = _doInitialize(reschedule: reschedule);
    return _initializationFuture!;
  }

  Future<void> _doInitialize({required bool reschedule}) async {
    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      tz.setLocalLocation(tz.local);
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: _handleNotificationSelection,
    );

    await _createNotificationChannel();
    await requestPermissions();
    _initialized = true;
    _initializing = false;

    if (reschedule) {
      await rescheduleAllReminders();
    }
  }

  Future<void> _handleNotificationSelection(String? payload) async {
    final match = _notificationIdPattern.firstMatch(payload ?? '');
    if (match == null) return;
    final notificationId = int.parse(match.group(1)!);
    _currentNotificationId = notificationId;
    final reminderId = _reminderIdFromNotificationId(notificationId);
    final reminders = await DatabaseHelper().getReminders();
    for (final reminder in reminders) {
      if (reminder.id == reminderId && onReminderTriggered != null) {
        _currentActiveReminder = reminder;
        _isPlaying = true;
        onReminderTriggered!(reminder);
        break;
      }
    }
  }

  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    return flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  }

  Future<Reminder?> resolveReminderFromPayload(String? payload) async {
    final match = _notificationIdPattern.firstMatch(payload ?? '');
    if (match == null) return null;
    final notificationId = int.parse(match.group(1)!);
    _currentNotificationId = notificationId;
    final reminderId = _reminderIdFromNotificationId(notificationId);
    final reminders = await DatabaseHelper().getReminders();
    for (final reminder in reminders) {
      if (reminder.id == reminderId) {
        _currentActiveReminder = reminder;
        _isPlaying = true;
        return reminder;
      }
    }
    return null;
  }

  Future<void> requestPermissions() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestPermission();
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final result = await _alarmPermissionChannel.invokeMethod<bool>(
        'canScheduleExactAlarms',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<String> getExactAlarmDetail() async {
    try {
      final result = await _alarmPermissionChannel.invokeMethod<String>(
        'getExactAlarmDetail',
      );
      return result ?? 'unknown';
    } on PlatformException {
      return 'error';
    }
  }

  Future<bool> canUseFullScreenIntent() async {
    try {
      final result = await _alarmPermissionChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isNotificationPermissionGranted() async {
    try {
      final result = await _alarmPermissionChannel.invokeMethod<bool>(
        'isNotificationPermissionGranted',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _alarmPermissionChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> startForegroundService() async {
    try {
      await _alarmPermissionChannel.invokeMethod('startForegroundService');
    } on PlatformException {
      // 忽略错误，前台服务启动失败不影响主功能
    }
  }

  Future<void> stopForegroundService() async {
    try {
      await _alarmPermissionChannel.invokeMethod('stopForegroundService');
    } on PlatformException {
      // 忽略错误
    }
  }

  Future<void> _createNotificationChannel() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminder_channel',
        '提醒通知',
        description: '用于打卡提醒的通知渠道',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> rescheduleAllReminders() async {
    await initialize(reschedule: false);
    await _createNotificationChannel();
    final reminders = await DatabaseHelper().getReminders();
    await flutterLocalNotificationsPlugin.cancelAll();
    for (final reminder in reminders) {
      if (reminder.isEnabled && !reminder.isCompleted) {
        await scheduleReminder(reminder);
      }
    }
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    await initialize(reschedule: false);
    await _createNotificationChannel();
    await cancelReminder(reminder.id);

    if (reminder.itemType == ItemType.todo) {
      await _scheduleTodo(reminder);
      return;
    }

    final occurrences = _buildOccurrences(reminder);
    final now = DateTime.now();

    for (var occurrenceIndex = 0;
        occurrenceIndex < occurrences.length;
        occurrenceIndex++) {
      final occurrence = occurrences[occurrenceIndex];
      for (var repeatIndex = 0; repeatIndex <= _repeatCount; repeatIndex++) {
        final scheduled = occurrence.add(
          Duration(minutes: _repeatEveryMinutes * repeatIndex),
        );
        final notificationId = _notificationId(
          reminder.id,
          occurrenceIndex,
          repeatIndex,
        );
        final delaySeconds = scheduled.difference(now).inSeconds;
        if (delaySeconds <= 0) continue;

        try {
          await flutterLocalNotificationsPlugin.schedule(
            notificationId,
            '打卡提醒',
            repeatIndex == 0
                ? '${reminder.name} - 请打卡！'
                : '${reminder.name} - 仍未确认，请尽快打卡！',
            now.add(Duration(seconds: delaySeconds)),
            _notificationDetails,
            payload: notificationId.toString(),
            androidAllowWhileIdle: true,
          );
        } catch (e) {
          // 单条通知失败不影响其他通知继续排程
        }
      }
    }
  }

  Future<void> _scheduleTodo(Reminder reminder) async {
    if (reminder.isCompleted || reminder.dueDate == null) return;

    final now = DateTime.now();
    final scheduled = DateTime(
      reminder.dueDate!.year,
      reminder.dueDate!.month,
      reminder.dueDate!.day,
      reminder.time.hour,
      reminder.time.minute,
    );
    final delaySeconds = scheduled.difference(now).inSeconds;
    if (delaySeconds <= 0) return;

    try {
      await flutterLocalNotificationsPlugin.schedule(
        _todoNotificationId(reminder.id),
        '待办事项提醒',
        '${reminder.name} - 到时间了，请完成事项',
        now.add(Duration(seconds: delaySeconds)),
        _notificationDetails,
        payload: _todoNotificationId(reminder.id).toString(),
        androidAllowWhileIdle: true,
      );
    } catch (e) {
      // 单条通知失败不影响其他通知继续排程
    }
  }

  void scheduleReminderInBackground(Reminder reminder) {
    unawaited(scheduleReminder(reminder));
  }

  void rescheduleReminderInBackground(Reminder reminder) {
    unawaited(_rescheduleReminder(reminder));
  }

  Future<void> _rescheduleReminder(Reminder reminder) async {
    await cancelReminder(reminder.id);
    if (reminder.isEnabled && !reminder.isCompleted) {
      await scheduleReminder(reminder);
    }
  }

  Future<void> cancelReminder(int reminderId) async {
    await initialize(reschedule: false);
    await flutterLocalNotificationsPlugin.cancel(_todoNotificationId(reminderId));
    for (var occurrenceIndex = 0;
        occurrenceIndex < _daysToSchedule;
        occurrenceIndex++) {
      for (var repeatIndex = 0; repeatIndex <= _repeatCount; repeatIndex++) {
        await flutterLocalNotificationsPlugin.cancel(
          _notificationId(reminderId, occurrenceIndex, repeatIndex),
        );
      }
    }
  }

  void cancelReminderInBackground(int reminderId) {
    unawaited(cancelReminder(reminderId));
  }

  List<tz.TZDateTime> _buildOccurrences(Reminder reminder) {
    final now = tz.TZDateTime.now(tz.local);
    final result = <tz.TZDateTime>[];

    if (reminder.type == ReminderType.specificDate && reminder.customDate != null) {
      final scheduled = tz.TZDateTime(
        tz.local,
        reminder.customDate!.year,
        reminder.customDate!.month,
        reminder.customDate!.day,
        reminder.time.hour,
        reminder.time.minute,
      );
      if (scheduled.isAfter(now)) {
        result.add(scheduled);
      }
      return result;
    }

    for (var dayOffset = 0; dayOffset < _daysToSchedule; dayOffset++) {
      final candidate = now.add(Duration(days: dayOffset));
      if (!_matchesDay(reminder, candidate.weekday)) {
        continue;
      }
      final scheduled = tz.TZDateTime(
        tz.local,
        candidate.year,
        candidate.month,
        candidate.day,
        reminder.time.hour,
        reminder.time.minute,
      );
      if (scheduled.isAfter(now)) {
        result.add(scheduled);
      }
    }

    return result;
  }

  bool _matchesDay(Reminder reminder, int weekday) {
    switch (reminder.type) {
      case ReminderType.daily:
        return true;
      case ReminderType.weekdays:
        return weekday >= 1 && weekday <= 5;
      case ReminderType.custom:
        return reminder.days.contains(weekday);
      case ReminderType.specificDate:
        return false;
    }
  }

  int _notificationId(int reminderId, int occurrenceIndex, int repeatIndex) {
    return reminderId * 1000 + occurrenceIndex * 100 + repeatIndex;
  }

  int _todoNotificationId(int reminderId) {
    return reminderId * 1000 + 999;
  }

  int _reminderIdFromNotificationId(int notificationId) {
    return notificationId ~/ 1000;
  }

  Future<void> _cancelCurrentOccurrence() async {
    if (_currentNotificationId == null) {
      return;
    }

    final occurrenceBase = (_currentNotificationId! ~/ 100) * 100;
    for (var repeatIndex = 0; repeatIndex <= _repeatCount; repeatIndex++) {
      await flutterLocalNotificationsPlugin.cancel(occurrenceBase + repeatIndex);
    }
    await flutterLocalNotificationsPlugin.cancel(_currentNotificationId!);
  }

  NotificationDetails get _notificationDetails {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel',
        '提醒通知',
        channelDescription: '用于打卡提醒的通知渠道',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
      ),
    );
  }

  Future<void> showNotification(String title, String body, int id) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails,
      payload: id.toString(),
    );
  }

  Future<void> testSound() async {
    _isPlaying = true;
    await showNotification('测试提醒', '这是提醒声音测试', 999001);
  }

  Future<void> stopReminderSound() async {
    _isPlaying = false;
    await flutterLocalNotificationsPlugin.cancel(999001);
    await _cancelCurrentOccurrence();
  }

  Future<void> startRepeatingReminder(Reminder reminder) async {
    _currentActiveReminder = reminder;
    _isPlaying = true;
    await showNotification(
      reminder.itemType == ItemType.todo ? '待办事项提醒' : '打卡提醒',
      reminder.itemType == ItemType.todo ? '${reminder.name} - 到时间了，请完成事项' : '${reminder.name} - 请打卡！',
      reminder.id,
    );
  }

  Future<void> dismissReminder() async {
    await _cancelCurrentOccurrence();
    _currentActiveReminder = null;
    _currentNotificationId = null;
    _isPlaying = false;
  }

  Reminder? get currentActiveReminder => _currentActiveReminder;
  bool get isPlaying => _isPlaying;
}
