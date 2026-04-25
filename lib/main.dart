import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/reminder_list_screen.dart';
import 'screens/reminder_dialog.dart';
import 'models/reminder.dart';
import 'services/database_service.dart';
import 'services/reminder_service.dart';

String? _launchPayload;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final reminderService = ReminderService();
  // 只做最轻量的初始化（时区 + 通知插件），不排程，不启动前台服务
  await reminderService.initialize(reschedule: false);

  // 检查 app 是否是被通知点击拉起的（包括 app 被杀掉后点击通知）
  final launchDetails = await reminderService.getLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true) {
    _launchPayload = launchDetails!.payload;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '今天你打了吗',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('zh', 'CN'),
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ReminderService _reminderService = ReminderService();
  bool _alarmPageOpen = false;
  final GlobalKey<ReminderListScreenState> _listKey = GlobalKey<ReminderListScreenState>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      _listKey.currentState?.refresh();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _dbHelper.database;
    _reminderService.onReminderTriggered = _showReminderDialog;

    // 检查 app 是否是被通知点击拉起的（包括 app 被杀掉后）
    if (_launchPayload != null) {
      final reminder = await _reminderService.resolveReminderFromPayload(_launchPayload);
      _launchPayload = null;
      if (reminder != null && mounted) {
        _showReminderDialog(reminder);
        return;
      }
    }

    // 等 UI 渲染完成后再做重排程和权限，避免阻塞启动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 重排程所有提醒 + 启动前台服务，后台执行不阻塞 UI
      _reminderService.rescheduleAllReminders();
      _reminderService.startForegroundService();
      _requestAllPermissions();
    });
  }

  Future<void> _requestAllPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool('permissions_asked') ?? false;

    // 1. 通知权限（Android 13+ 会弹系统对话框）
    await _reminderService.requestPermissions();

    if (!alreadyAsked && mounted) {
      await prefs.setBool('permissions_asked', true);

      // 2. 合并弹框：精确闹钟 + 电池优化 + 自启动
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要开启以下权限'),
          content: const Text(
            '为了确保提醒在后台准时触发，请依次开启以下权限：\n\n'
            '1. 精确闹钟权限\n'
            '2. 关闭电池优化\n'
            '3. 允许自启动\n\n'
            '点击"去设置"将依次跳转到对应设置页面。',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('稍后')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去设置')),
          ],
        ),
      );

      if (goToSettings == true) {
        // 打开应用详情页（所有 Android 设备通用）
        // 用户可以在此页面开启：精确闹钟、通知、自启动等权限
        if (mounted) {
          try {
            const intent1 = AndroidIntent(
              action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
              data: 'package:com.example.attendance_reminder_app',
            );
            await intent1.launch();
          } catch (_) {}
        }

        // 电池优化
        if (mounted) {
          try {
            const intent2 = AndroidIntent(
              action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
            );
            await intent2.launch();
          } catch (_) {}
        }
      }
    }
  }

  void _showReminderDialog(Reminder reminder) {
    if (!mounted || _alarmPageOpen) return;
    _alarmPageOpen = true;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ReminderDialog(
          reminder: reminder,
          reminderService: _reminderService,
        ),
      ),
    )
        .then((_) {
      _alarmPageOpen = false;
      _listKey.currentState?.refresh();
    });
  }

  @override
  void dispose() {
    _reminderService.stopPeriodicCheck();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今天你打了吗'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ReminderListScreen(key: _listKey),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm),
            label: '提醒',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool? _notificationEnabled;
  bool? _exactAlarmEnabled;
  bool? _fullScreenIntentEnabled;
  bool? _batteryOptimizationIgnored;
  String _alarmDetail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPermissionStatus();
    }
  }

  Future<void> _loadPermissionStatus() async {
    final service = ReminderService();
    final notification = await service.isNotificationPermissionGranted();
    final exactAlarm = await service.canScheduleExactAlarms();
    final fullScreen = await service.canUseFullScreenIntent();
    final battery = await service.isIgnoringBatteryOptimizations();
    final detail = await service.getExactAlarmDetail();
    if (!mounted) return;
    setState(() {
      _notificationEnabled = notification;
      _exactAlarmEnabled = exactAlarm;
      _fullScreenIntentEnabled = fullScreen;
      _batteryOptimizationIgnored = battery;
      _alarmDetail = detail;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('权限状态', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // 权限状态卡片
            _buildPermissionStatus(
              icon: Icons.notifications,
              title: '通知权限',
              subtitle: _notificationEnabled == null
                  ? '检查中…'
                  : _notificationEnabled!
                      ? '已开启'
                      : '未开启 — 无法显示提醒通知',
              isEnabled: _notificationEnabled,
              onTap: _requestNotificationPermission,
              buttonText: _notificationEnabled == true ? '已开启' : '去开启',
            ),
            const SizedBox(height: 8),
            _buildPermissionStatus(
              icon: Icons.alarm,
              title: '精确闹钟',
              subtitle: _exactAlarmEnabled == null
                  ? '检查中…'
                  : _exactAlarmEnabled!
                      ? '已开启'
                      : '未开启 — 提醒可能不准时',
              isEnabled: _exactAlarmEnabled,
              onTap: _openAppSettings,
              buttonText: '去开启',
            ),
            const SizedBox(height: 8),
            _buildPermissionStatus(
              icon: Icons.fullscreen,
              title: '全屏通知（锁屏提醒）',
              subtitle: _fullScreenIntentEnabled == null
                  ? '检查中…'
                  : _fullScreenIntentEnabled!
                      ? '已开启'
                      : '未开启 — 锁屏时不会弹出提醒',
              isEnabled: _fullScreenIntentEnabled,
              onTap: _openAppSettings,
              buttonText: '去开启',
            ),
            const SizedBox(height: 8),
            _buildPermissionStatus(
              icon: Icons.battery_saver,
              title: '电池优化',
              subtitle: _batteryOptimizationIgnored == null
                  ? '检查中…'
                  : _batteryOptimizationIgnored!
                      ? '已关闭电池优化 — 后台服务正常运行'
                      : '未关闭 — 可能导致后台提醒被系统杀掉',
              isEnabled: _batteryOptimizationIgnored,
              onTap: _openBatteryOptimizationSettings,
              buttonText: _batteryOptimizationIgnored == true ? '已关闭' : '去设置',
            ),
            const SizedBox(height: 8),
            _buildPermissionStatus(
              icon: Icons.power_settings_new,
              title: '自启动',
              subtitle: '部分手机需要手动允许自启动（无法自动检测）',
              isEnabled: null,
              onTap: _openAutoStartSettings,
              buttonText: '去设置',
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('测试', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _testReminder,
              icon: const Icon(Icons.play_arrow),
              label: const Text('测试提醒（立即弹出）'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadPermissionStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新权限状态'),
            ),

            if (_alarmDetail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '调试信息: $_alarmDetail',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              '说明：要实现像闹钟一样在关闭应用后仍提醒，需要：\n'
              '1. 允许通知\n'
              '2. 允许精确闹钟（在应用详情页 → 权限 中开启）\n'
              '3. 关闭电池优化\n'
              '4. 允许自启动',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionStatus({
    required IconData icon,
    required String title,
    required String subtitle,
    bool? isEnabled,
    required VoidCallback onTap,
    required String buttonText,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isEnabled == null
              ? Colors.grey
              : isEnabled
                  ? Colors.green
                  : Colors.orange,
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(buttonText),
        ),
      ),
    );
  }

  Future<void> _testReminder() async {
    final testReminder = Reminder(
      id: 999,
      name: '测试提醒',
      time: TimeSetting(DateTime.now().hour, DateTime.now().minute),
      days: [1, 2, 3, 4, 5, 6, 7],
      isEnabled: true,
      soundPath: 'assets/sounds/reminder.mp3',
      type: ReminderType.daily,
    );

    final reminderService = ReminderService();
    reminderService.onReminderTriggered = (reminder) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => ReminderDialog(
            reminder: reminder,
            reminderService: reminderService,
          ),
        ),
      );
    };
    await reminderService.startRepeatingReminder(testReminder);
  }

  Future<void> _requestNotificationPermission() async {
    await ReminderService().requestPermissions();
  }

  Future<void> _openAppSettings() async {
    // 使用通用的应用详情页，所有 Android 设备都支持
    const intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:com.example.attendance_reminder_app',
    );
    await intent.launch();
    // 返回后会通过 didChangeAppLifecycleState 自动重新检查状态
  }

  Future<void> _openBatteryOptimizationSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  Future<void> _openAutoStartSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:com.example.attendance_reminder_app',
    );
    await intent.launch();
  }
}