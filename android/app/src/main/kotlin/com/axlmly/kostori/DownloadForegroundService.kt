package com.axlmly.kostori

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.view.View
import android.widget.RemoteViews

/**
 * 下载保活前台服务：存在下载任务时启动。
 * 单个通知内以自定义布局列出多个任务（标题 + 进度条 + 百分比，最多展示 3 个）。
 */
class DownloadForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "download"
        private const val NOTIFICATION_ID = 1002
        private const val MAX_VISIBLE = 3
        private const val ACTION_START = "com.axlmly.kostori.START_DOWNLOAD"
        private const val ACTION_STOP = "com.axlmly.kostori.STOP_DOWNLOAD"
        private const val ACTION_UPDATE = "com.axlmly.kostori.UPDATE_DOWNLOAD"
        private const val EXTRA_TASKS = "tasks"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_PROGRESS = "progress"

        private val taskTitleIds = intArrayOf(
            R.id.task_title_1, R.id.task_title_2, R.id.task_title_3,
        )
        private val taskProgressIds = intArrayOf(
            R.id.task_progress_1, R.id.task_progress_2, R.id.task_progress_3,
        )
        private val taskPercentIds = intArrayOf(
            R.id.task_percent_1, R.id.task_percent_2, R.id.task_percent_3,
        )
        private val taskRowIds = intArrayOf(
            R.id.task_row_1, R.id.task_row_2, R.id.task_row_3,
        )

        fun start(context: Context) {
            val intent = Intent(context, DownloadForegroundService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, DownloadForegroundService::class.java).setAction(ACTION_STOP)
            context.startService(intent)
        }

        fun update(context: Context, tasks: List<Map<String, Any>>) {
            val bundles = ArrayList<Bundle>(tasks.size)
            for (t in tasks) {
                bundles.add(
                    Bundle().apply {
                        putString(EXTRA_TITLE, t[EXTRA_TITLE] as? String ?: "")
                        putDouble(EXTRA_PROGRESS, (t[EXTRA_PROGRESS] as? Number)?.toDouble() ?: 0.0)
                    }
                )
            }
            val intent = Intent(context, DownloadForegroundService::class.java)
                .setAction(ACTION_UPDATE)
                .putParcelableArrayListExtra(EXTRA_TASKS, bundles)
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        acquireWakeLock()
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfInternal()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                @Suppress("DEPRECATION")
                val tasks = intent.getParcelableArrayListExtra<Bundle>(EXTRA_TASKS) ?: arrayListOf()
                if (tasks.isEmpty()) {
                    stopSelfInternal()
                    return START_NOT_STICKY
                }
                showNotification(tasks)
                return START_STICKY
            }
            else -> {
                showNotification(arrayListOf())
                return START_STICKY
            }
        }
    }

    private fun stopSelfInternal() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun acquireWakeLock() {
        if (wakeLock != null) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "kostori:download",
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "下载任务",
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
    }

    private fun launchPendingIntent(): PendingIntent {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        return PendingIntent.getActivity(
            this,
            1,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showNotification(tasks: List<Bundle>) {
        ensureChannel()
        val rv = RemoteViews(packageName, R.layout.download_notification)
        val count = tasks.size
        rv.setTextViewText(R.id.notif_count, "下载中 $count 个任务")

        for (i in 0 until MAX_VISIBLE) {
            if (i < count) {
                val t = tasks[i]
                val title = t.getString(EXTRA_TITLE) ?: ""
                val progress = t.getDouble(EXTRA_PROGRESS)
                val percent = (progress * 100).toInt().coerceIn(0, 100)
                rv.setTextViewText(taskTitleIds[i], title)
                rv.setTextViewText(taskPercentIds[i], "$percent%")
                rv.setProgressBar(taskProgressIds[i], 100, percent, progress <= 0.0)
                rv.setViewVisibility(taskRowIds[i], View.VISIBLE)
            } else {
                rv.setViewVisibility(taskRowIds[i], View.GONE)
            }
        }

        if (count > MAX_VISIBLE) {
            rv.setTextViewText(R.id.notif_more, "另有 ${count - MAX_VISIBLE} 个任务")
            rv.setViewVisibility(R.id.notif_more, View.VISIBLE)
        } else {
            rv.setViewVisibility(R.id.notif_more, View.GONE)
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(launchPendingIntent())
            .setCustomContentView(rv)
            .setCustomBigContentView(rv)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+：dataSync 在 targetSDK 36 被禁止，改用 specialUse
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)
    }
}
