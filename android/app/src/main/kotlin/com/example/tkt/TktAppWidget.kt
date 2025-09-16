package com.example.tkt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TktAppWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                // 忽略單次更新失敗，避免 launcher 顯示無法載入
            }
        }
    }

    companion object {
        private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_timetable)

            val date = Date()
            val dateStr = SimpleDateFormat("MM/dd (E)", Locale.TAIWAN).format(date)
            views.setTextViewText(R.id.tvDate, dateStr)

            // 課程 1
            views.setTextViewText(R.id.course1_title, "計算機概論")
            views.setTextViewText(R.id.course1_session, "第1-2節")
            views.setTextViewText(R.id.course1_room, "RB-101")

            // 課程 2
            views.setTextViewText(R.id.course2_title, "線性代數")
            views.setTextViewText(R.id.course2_session, "第3-4節")
            views.setTextViewText(R.id.course2_room, "MA-302")

            // 課程 3
            views.setTextViewText(R.id.course3_title, "資料結構")
            views.setTextViewText(R.id.course3_session, "第6-7節")
            views.setTextViewText(R.id.course3_room, "CS-204")

            // 課程 4
            views.setTextViewText(R.id.course4_title, "作業系統")
            views.setTextViewText(R.id.course4_session, "第8-9節")
            views.setTextViewText(R.id.course4_room, "CS-305")

            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}


