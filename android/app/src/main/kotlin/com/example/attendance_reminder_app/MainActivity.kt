package com.example.attendance_reminder_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        // 处理从原生通知点击打开 App 的情况
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("fromNotification", false) == true) {
            val reminderId = intent.getIntExtra("reminderId", -1)
            if (reminderId != -1) {
                // 取消该提醒的所有原生通知
                try {
                    val manager = getSystemService(NotificationManager::class.java)
                    for (occurrence in 0 until 7) {
                        manager.cancel(reminderId * 1000 + occurrence * 100)
                        for (repeat in 1..4) {
                            manager.cancel(reminderId * 1000 + occurrence * 100 + repeat)
                        }
                    }
                } catch (_: Exception) {}
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "attendance_reminder_app/alarm_permissions"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
                "getExactAlarmDetail" -> result.success(getExactAlarmDetail())
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                "isNotificationPermissionGranted" -> result.success(isNotificationPermissionGranted())
                "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                "startForegroundService" -> {
                    startForegroundService()
                    result.success(true)
                }
                "stopForegroundService" -> {
                    stopForegroundService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return true
        }
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return notificationManager.canUseFullScreenIntent()
    }

    private fun isNotificationPermissionGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun getExactAlarmDetail(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return "API<31,无需权限"
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canSchedule = alarmManager.canScheduleExactAlarms()

        // 检查 SCHEDULE_EXACT_ALARM 的 AppOps 状态
        var scheduleExactAlarmState = "unknown"
        try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
            val mode = appOps.unsafeCheckOpNoThrow(
                "android:schedule_exact_alarm",
                android.os.Process.myUid(),
                packageName
            )
            scheduleExactAlarmState = when (mode) {
                android.app.AppOpsManager.MODE_ALLOWED -> "allowed"
                android.app.AppOpsManager.MODE_IGNORED -> "ignored"
                android.app.AppOpsManager.MODE_ERRORED -> "errored"
                android.app.AppOpsManager.MODE_DEFAULT -> "default"
                else -> "mode_$mode"
            }
        } catch (_: Exception) {}

        // 检查 USE_EXACT_ALARM 的 AppOps 状态
        var useExactAlarmState = "unknown"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
                val mode = appOps.unsafeCheckOpNoThrow(
                    "android:use_exact_alarm",
                    android.os.Process.myUid(),
                    packageName
                )
                useExactAlarmState = when (mode) {
                    android.app.AppOpsManager.MODE_ALLOWED -> "allowed"
                    android.app.AppOpsManager.MODE_IGNORED -> "ignored"
                    android.app.AppOpsManager.MODE_ERRORED -> "errored"
                    android.app.AppOpsManager.MODE_DEFAULT -> "default"
                    else -> "mode_$mode"
                }
            } catch (_: Exception) {}
        }

        return "canSchedule=$canSchedule,schedule_exact=$scheduleExactAlarmState,use_exact=$useExactAlarmState"
    }

    private fun startForegroundService() {
        val intent = Intent(this, ReminderForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopForegroundService() {
        val intent = Intent(this, ReminderForegroundService::class.java)
        stopService(intent)
    }
}

class ReminderForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "reminder_foreground_service"
        const val NOTIFICATION_ID = 9999
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        // 启动原生级闹钟调度
        AlarmScheduler.scheduleAll(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 每次服务启动/重启时重新调度闹钟
        AlarmScheduler.scheduleAll(this)
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        scheduleServiceRestart()
    }

    override fun onDestroy() {
        super.onDestroy()
        AlarmScheduler.cancelPeriodicCheck(this)
        scheduleServiceRestart()
    }

    /**
     * 使用 setAlarmClock() 安排服务重启。
     * setAlarmClock() 被系统视为用户级闹钟，优先级最高，
     * 即使 App 被强制停止也能存活（国产手机也遵守）。
     */
    private fun scheduleServiceRestart() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerTime = System.currentTimeMillis() + 2000

            // 用于状态栏显示的闹钟图标 Intent（必需参数）
            val showIntent = PendingIntent.getActivity(
                applicationContext, 0, Intent(),
                PendingIntent.FLAG_IMMUTABLE
            )
            // 实际触发的广播 Intent → ReminderRestartReceiver 启动服务
            val restartIntent = Intent(applicationContext, ReminderRestartReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                applicationContext, 9998, restartIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerTime, showIntent),
                pendingIntent
            )
            Log.d("ReminderService", "已设置 setAlarmClock 重启闹钟")
        } catch (e: Exception) {
            Log.e("ReminderService", "设置重启闹钟失败", e)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "提醒服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "保持打卡提醒服务运行"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("打卡提醒")
            .setContentText("正在监听打卡提醒…")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
}

/**
 * 原生级闹钟调度器：直接读取 SQLite 数据库，通过 AlarmManager 设置精确闹钟。
 * 即使 Flutter 引擎被杀死，前台服务重启后也能重新调度所有提醒。
 */
object AlarmScheduler {
    private const val TAG = "AlarmScheduler"
    private const val REMINDER_NOTIFICATION_CHANNEL = "reminder_channel"
    private const val RESCHEDULE_INTERVAL_MS = 30 * 60 * 1000L // 30 分钟

    private val handler = Handler(Looper.getMainLooper())
    private var periodicRunnable: Runnable? = null

    fun scheduleAll(context: Context) {
        try {
            createNotificationChannel(context)
            cancelAllAlarms(context)
            val reminders = readEnabledReminders(context)
            var hasScheduled = false
            for (r in reminders) {
                if (scheduleAlarmsForReminder(context, r)) {
                    hasScheduled = true
                }
            }
            startPeriodicCheck(context)
            Log.d(TAG, "已调度 ${reminders.size} 个提醒")
        } catch (e: Exception) {
            Log.e(TAG, "scheduleAll 失败", e)
        }
    }

    fun cancelPeriodicCheck(context: Context) {
        periodicRunnable?.let { handler.removeCallbacks(it) }
        periodicRunnable = null
    }

    private fun startPeriodicCheck(context: Context) {
        periodicRunnable?.let { handler.removeCallbacks(it) }
        periodicRunnable = object : Runnable {
            override fun run() {
                try {
                    val reminders = readEnabledReminders(context)
                    var hasUpcoming = false
                    val now = System.currentTimeMillis()
                    for (r in reminders) {
                        val nextTrigger = getNextTriggerTime(r)
                        if (nextTrigger > now && nextTrigger - now < RESCHEDULE_INTERVAL_MS) {
                            hasUpcoming = true
                        }
                    }
                    if (!hasUpcoming) {
                        scheduleAll(context)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "定期检查失败", e)
                }
                handler.postDelayed(this, RESCHEDULE_INTERVAL_MS)
            }
        }
        handler.postDelayed(periodicRunnable!!, RESCHEDULE_INTERVAL_MS)
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                REMINDER_NOTIFICATION_CHANNEL,
                "提醒通知",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "用于打卡提醒的通知渠道"
                enableVibration(true)
                setBypassDnd(true)
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private data class ReminderData(
        val id: Int,
        val name: String,
        val hour: Int,
        val minute: Int,
        val days: String,
        val isEnabled: Int,
        val type: Int,
        val customDate: Long?,
        val itemType: Int,
        val isCompleted: Int,
        val dueDate: Long?
    )

    private fun readEnabledReminders(context: Context): List<ReminderData> {
        val result = mutableListOf<ReminderData>()
        try {
            val dbPath = context.getDatabasePath("reminders.db")
            if (!dbPath.exists()) return result
            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery(
                "SELECT id, name, hour, minute, days, isEnabled, type, customDate, itemType, isCompleted, dueDate FROM reminders WHERE isEnabled = 1 AND isCompleted = 0",
                null
            )
            while (cursor.moveToNext()) {
                result.add(ReminderData(
                    id = cursor.getInt(0),
                    name = cursor.getString(1) ?: "",
                    hour = cursor.getInt(2),
                    minute = cursor.getInt(3),
                    days = cursor.getString(4) ?: "",
                    isEnabled = cursor.getInt(5),
                    type = cursor.getInt(6),
                    customDate = if (cursor.isNull(7)) null else cursor.getLong(7),
                    itemType = cursor.getInt(8),
                    isCompleted = cursor.getInt(9),
                    dueDate = if (cursor.isNull(10)) null else cursor.getLong(10)
                ))
            }
            cursor.close()
            db.close()
        } catch (e: Exception) {
            Log.e(TAG, "读取数据库失败", e)
        }
        return result
    }

    private fun scheduleAlarmsForReminder(context: Context, r: ReminderData): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        var scheduled = false

        // 类型 3 = 指定日期
        if (r.type == 3 && r.customDate != null) {
            val cal = Calendar.getInstance().apply {
                timeInMillis = r.customDate
                set(Calendar.HOUR_OF_DAY, r.hour)
                set(Calendar.MINUTE, r.minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val triggerTime = cal.timeInMillis
            if (triggerTime > now && triggerTime - now < 24 * 60 * 60 * 1000L) {
                scheduleExactAlarm(context, alarmManager, r, triggerTime, 0)
                scheduled = true
            }
            return scheduled
        }

        // 其他类型：遍历未来 7 天
        val cal = Calendar.getInstance()
        for (dayOffset in 0 until 7) {
            val candidate = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, dayOffset)
                set(Calendar.HOUR_OF_DAY, r.hour)
                set(Calendar.MINUTE, r.minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val weekday = candidate.get(Calendar.DAY_OF_WEEK) // 1=周日, 2=周一 ...
            if (!matchesDay(r, weekday)) continue
            val triggerTime = candidate.timeInMillis
            if (triggerTime <= now) continue
            scheduleExactAlarm(context, alarmManager, r, triggerTime, dayOffset)
            scheduled = true
        }
        return scheduled
    }

    private fun matchesDay(r: ReminderData, androidWeekday: Int): Boolean {
        // Android: 1=周日, 2=周一, ..., 7=周六
        // 数据库: 1=周一, ..., 7=周日
        val dbDay = when (androidWeekday) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7
            else -> return false
        }
        return when (r.type) {
            0 -> true // 每天
            1 -> dbDay in 1..5 // 工作日
            2 -> {
                val daysList = r.days.split(",").mapNotNull { it.trim().toIntOrNull() }
                dbDay in daysList
            }
            else -> false
        }
    }

    private fun scheduleExactAlarm(
        context: Context,
        alarmManager: AlarmManager,
        r: ReminderData,
        triggerTime: Long,
        dayOffset: Int
    ) {
        // notificationId 编码：reminderId * 1000 + dayOffset * 100
        val notificationId = r.id * 1000 + dayOffset * 100
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            putExtra("notificationId", notificationId)
            putExtra("reminderId", r.id)
            putExtra("reminderName", r.name)
            putExtra("itemType", r.itemType)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, notificationId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                if (am.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
                )
            }
            Log.d(TAG, "已设置闹钟: ${r.name} @ ${java.text.SimpleDateFormat("MM-dd HH:mm", java.util.Locale.getDefault()).format(java.util.Date(triggerTime))}")
        } catch (e: Exception) {
            Log.e(TAG, "设置闹钟失败: ${r.name}", e)
        }
    }

    private fun getNextTriggerTime(r: ReminderData): Long {
        val now = System.currentTimeMillis()
        if (r.type == 3 && r.customDate != null) {
            val cal = Calendar.getInstance().apply {
                timeInMillis = r.customDate
                set(Calendar.HOUR_OF_DAY, r.hour)
                set(Calendar.MINUTE, r.minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            return cal.timeInMillis
        }
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, r.hour)
            set(Calendar.MINUTE, r.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (cal.timeInMillis <= now) cal.add(Calendar.DAY_OF_YEAR, 1)
        return cal.timeInMillis
    }

    private fun cancelAllAlarms(context: Context) {
        try {
            val reminders = readEnabledReminders(context)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (r in reminders) {
                for (dayOffset in 0 until 7) {
                    val notificationId = r.id * 1000 + dayOffset * 100
                    val intent = Intent(context, ReminderAlarmReceiver::class.java)
                    val pendingIntent = PendingIntent.getBroadcast(
                        context, notificationId, intent,
                        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                    )
                    pendingIntent?.let { alarmManager.cancel(it) }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "取消闹钟失败", e)
        }
    }
}

/**
 * 原生广播接收器：闹钟触发时显示系统通知。
 * 完全不依赖 Flutter 引擎，即使 App 被杀死也能正常弹出通知。
 */
class ReminderAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ReminderAlarmReceiver"
        private const val CHANNEL_ID = "reminder_channel"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra("notificationId", 0)
        val reminderId = intent.getIntExtra("reminderId", 0)
        val reminderName = intent.getStringExtra("reminderName") ?: "提醒"
        val itemType = intent.getIntExtra("itemType", 0)

        val title = if (itemType == 1) "待办事项提醒" else "打卡提醒"
        val body = if (itemType == 1) "$reminderName - 到时间了，请完成事项" else "$reminderName - 请打卡！"

        Log.d(TAG, "闹钟触发: $reminderName (id=$reminderId)")

        try {
            createNotificationChannel(context)
            showNotification(context, notificationId, reminderId, title, body)
            // 调度下一轮闹钟（5 分钟后重复提醒）
            scheduleRepeat(context, intent)
        } catch (e: Exception) {
            Log.e(TAG, "显示通知失败", e)
        }
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "提醒通知",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "用于打卡提醒的通知渠道"
                enableVibration(true)
                enableLights(true)
                setBypassDnd(true)
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(
        context: Context,
        notificationId: Int,
        reminderId: Int,
        title: String,
        body: String
    ) {
        // 全屏 Intent：点击通知后打开 App
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("reminderId", reminderId)
            putExtra("fromNotification", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, notificationId, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .build()

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(notificationId, notification)
    }

    private fun scheduleRepeat(context: Context, originalIntent: Intent) {
        // 5 分钟后再次提醒（最多重复 4 次）
        val notificationId = originalIntent.getIntExtra("notificationId", 0)
        val repeatIndex = notificationId % 100
        if (repeatIndex >= 4) return // 已达到最大重复次数

        val nextNotificationId = notificationId + 1
        val nextIntent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            putExtra("notificationId", nextNotificationId)
            putExtra("reminderId", originalIntent.getIntExtra("reminderId", 0))
            putExtra("reminderName", originalIntent.getStringExtra("reminderName"))
            putExtra("itemType", originalIntent.getIntExtra("itemType", 0))
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, nextNotificationId, nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerTime = System.currentTimeMillis() + 5 * 60 * 1000L // 5 分钟后
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
            )
        } catch (e: Exception) {
            Log.e(TAG, "设置重复提醒失败", e)
        }
    }
}

/**
 * 服务重启广播接收器：由 setAlarmClock() 触发，
 * 负责在 App 被杀后重新启动前台服务。
 */
class ReminderRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val serviceIntent = Intent(context, ReminderForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d("ReminderRestartReceiver", "前台服务已通过 setAlarmClock 重启")
        } catch (e: Exception) {
            Log.e("ReminderRestartReceiver", "重启服务失败", e)
        }
    }
}