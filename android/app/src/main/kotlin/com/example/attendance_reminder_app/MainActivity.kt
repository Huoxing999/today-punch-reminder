package com.example.attendance_reminder_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // app 被从最近任务划掉时，用 AlarmManager 延迟重启本服务
        val restartIntent = Intent(applicationContext, ReminderForegroundService::class.java)
        val pendingIntent = PendingIntent.getService(
            applicationContext, 1, restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.set(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            android.os.SystemClock.elapsedRealtime() + 1000,
            pendingIntent
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        // 服务被销毁时也尝试重启
        try {
            val restartIntent = Intent(applicationContext, ReminderForegroundService::class.java)
            val pendingIntent = PendingIntent.getService(
                applicationContext, 2, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                android.os.SystemClock.elapsedRealtime() + 1000,
                pendingIntent
            )
        } catch (_: Exception) {}
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