package com.example.tkt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Calendar

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
        private const val LOG_TAG = "TktAppWidget"
        private data class WidgetCourse(
            val name: String,
            val classroom: String,
            val startSlot: Int,
            val endSlot: Int,
            val dayOfWeek: Int,
        )

        private fun tryAddFromJsonArray(raw: String, out: MutableList<WidgetCourse>) {
            try {
                val arr = JSONArray(raw)
                for (i in 0 until arr.length()) {
                    val value = arr.get(i)
                    val obj = when (value) {
                        is JSONObject -> value
                        is String -> try { JSONObject(value) } catch (_: Exception) { null }
                        else -> null
                    } ?: continue
                    out.add(
                        WidgetCourse(
                            name = obj.optString("name", ""),
                            classroom = obj.optString("classroom", ""),
                            dayOfWeek = obj.optInt("day_of_week", 0),
                            startSlot = obj.optInt("start_slot", 0),
                            endSlot = obj.optInt("end_slot", 0),
                        )
                    )
                }
            } catch (_: Exception) {
                // ignore invalid json
            }
        }

        private fun normalizeCoursesPayload(raw: String): String {
            val s = raw.trim()
            val idx = s.lastIndexOf('!')
            return if (idx >= 0 && idx < s.length - 1) s.substring(idx + 1).trim() else s
        }

        private fun loadAllCourses(context: Context): List<WidgetCourse> {
            return try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val list = mutableListOf<WidgetCourse>()
                val keysToTry = arrayOf("flutter.courses", "courses")

                // 1) 先嘗試讀取 StringSet（以 try/catch 防止型別不符）
                for (key in keysToTry) {
                    try {
                        val set = prefs.getStringSet(key, null)
                        if (set != null) {
                            for (entry in set) {
                                val obj = try { JSONObject(entry) } catch (_: Exception) { null } ?: continue
                                list.add(
                                    WidgetCourse(
                                        name = obj.optString("name", ""),
                                        classroom = obj.optString("classroom", ""),
                                        dayOfWeek = obj.optInt("day_of_week", 0),
                                        startSlot = obj.optInt("start_slot", 0),
                                        endSlot = obj.optInt("end_slot", 0),
                                    )
                                )
                            }
                        }
                    } catch (_: ClassCastException) {
                        // 忽略：實際為 String 時，改由下一步以字串解析
                    }
                }

                // 2) 再嘗試讀取字串（JSON 陣列）
                if (list.isEmpty()) {
                    for (key in keysToTry) {
                        val raw = prefs.getString(key, null)
                        if (raw != null) {
                            val normalized = normalizeCoursesPayload(raw)
                            tryAddFromJsonArray(normalized, list)
                        }
                    }
                }

                list
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun filterTodayCourses(all: List<WidgetCourse>): List<WidgetCourse> {
            val calendar = Calendar.getInstance()
            val dowCal = calendar.get(Calendar.DAY_OF_WEEK) // Sun=1 ... Sat=7
            val dowFlutter = if (dowCal == Calendar.SUNDAY) 7 else dowCal - 1 // Mon=1 ... Sun=7
            return all.filter { it.dayOfWeek == dowFlutter }.sortedBy { it.startSlot }
        }

        private fun logSharedPrefsSnapshot(context: Context, all: List<WidgetCourse>) {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val keys = prefs.all.keys.joinToString()
                Log.d(LOG_TAG, "prefs.keys: $keys")
                val keysToTry = arrayOf("flutter.courses", "courses")
                for (key in keysToTry) {
                    try {
                        val set = prefs.getStringSet(key, null)
                        if (set != null) {
                            val sample = set.firstOrNull()?.take(200)
                            Log.d(LOG_TAG, "$key as Set size=${set.size} sample=$sample")
                        }
                    } catch (_: ClassCastException) {
                        // 不是 Set
                    }
                    val raw = prefs.getString(key, null)
                    if (raw != null) {
                        val normalized = normalizeCoursesPayload(raw)
                        Log.d(LOG_TAG, "$key as String len=${raw.length} normHead=${normalized.take(300)}")
                    }
                }
                Log.d(LOG_TAG, "parsed.count=${all.size}")
                for ((idx, c) in all.take(10).withIndex()) {
                    Log.d(LOG_TAG, "parsed[$idx]: name=${c.name}, room=${c.classroom}, dow=${c.dayOfWeek}, slots=${c.startSlot}-${c.endSlot}")
                }
                val dowCal = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
                val dowFlutter = if (dowCal == Calendar.SUNDAY) 7 else dowCal - 1
                Log.d(LOG_TAG, "today dowCal=$dowCal dowFlutter=$dowFlutter")
            } catch (e: Exception) {
                Log.e(LOG_TAG, "log snapshot error: ${e.message}")
            }
        }

        private fun loadRawCoursesForDebug(context: Context): String {
            return try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val raw = prefs.getString("flutter.courses", null)
                if (raw != null) {
                    raw
                } else {
                    val all = prefs.all
                    val dump = StringBuilder()
                    dump.append("keys=\n")
                    for ((k, v) in all) {
                        dump.append(k).append(" -> ")
                        dump.append(v?.toString()?.take(80)).append('\n')
                    }
                    dump.toString()
                }
            } catch (e: Exception) {
                "error: ${e.message}"
            }
        }

        private fun setCourseRow(
            views: RemoteViews,
            index: Int,
            course: WidgetCourse?
        ) {
            val titleId = when (index) {
                0 -> R.id.course1_title
                1 -> R.id.course2_title
                2 -> R.id.course3_title
                else -> R.id.course4_title
            }
            val sessionId = when (index) {
                0 -> R.id.course1_session
                1 -> R.id.course2_session
                2 -> R.id.course3_session
                else -> R.id.course4_session
            }
            val roomId = when (index) {
                0 -> R.id.course1_room
                1 -> R.id.course2_room
                2 -> R.id.course3_room
                else -> R.id.course4_room
            }

            if (course == null) {
                views.setTextViewText(titleId, "")
                views.setTextViewText(sessionId, "")
                views.setTextViewText(roomId, "")
            } else {
                views.setTextViewText(titleId, course.name)
                views.setTextViewText(sessionId, "第${course.startSlot}-${course.endSlot}節")
                views.setTextViewText(roomId, course.classroom)
            }
        }

        private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_timetable)

            val date = Date()
            val dateStr = SimpleDateFormat("MM/dd (E)", Locale.TAIWAN).format(date)
            views.setTextViewText(R.id.tvDate, dateStr)

            val allCourses = loadAllCourses(context)
            val todayCourses = filterTodayCourses(allCourses)
            logSharedPrefsSnapshot(context, allCourses)

            // 清空除錯內容（已移除除錯 TextView）

            // 標題顯示今日課程數
            views.setTextViewText(R.id.tvTitle, "今日課表 (" + todayCourses.size + ")")
            for (i in 0 until 4) {
                val course = if (i < todayCourses.size) todayCourses[i] else null
                setCourseRow(views, i, course)
            }

            if (todayCourses.isEmpty()) {
                views.setTextViewText(R.id.course1_title, "（無）")
                views.setTextViewText(R.id.course1_session, "")
                views.setTextViewText(R.id.course1_room, "")
            }

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


