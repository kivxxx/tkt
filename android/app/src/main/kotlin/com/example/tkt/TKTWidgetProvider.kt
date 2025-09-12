package com.example.tkt

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

// 課程資料類
data class Course(
    val name: String,
    val classroom: String,
    val startSlot: Int,
    val endSlot: Int,
    val dayOfWeek: Int
)

class TKTWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            // 創建 RemoteViews
            val views = RemoteViews(context.packageName, R.layout.tkt_widget_layout)

            // 從 SharedPreferences 讀取課程資料
            val sharedPreferences: SharedPreferences = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val coursesDataString = sharedPreferences.getString("courses_data", null)

            if (coursesDataString != null) {
                try {
                    val courses = parseCourses(coursesDataString)
                    val todayCourses = filterTodayCourses(courses)

                    if (todayCourses.isNotEmpty()) {
                        views.setViewVisibility(R.id.courses_list, RemoteViews.VISIBLE)
                        views.setViewVisibility(R.id.empty_view, RemoteViews.GONE)

                        // 清空舊的課程視圖
                        views.removeAllViews(R.id.courses_list)

                        // 添加新的課程視圖
                        todayCourses.forEach { course ->
                            val courseView = RemoteViews(context.packageName, R.layout.course_item_layout)
                            courseView.setTextViewText(R.id.course_name, course.name)
                            courseView.setTextViewText(R.id.course_time, "第 ${course.startSlot}-${course.endSlot} 節")
                            views.addView(R.id.courses_list, courseView)
                        }
                    } else {
                        // 今日無課程
                        showEmptyView(views)
                    }
                } catch (e: Exception) {
                    // 解析錯誤
                    showEmptyView(views)
                }
            } else {
                // 沒有資料
                showEmptyView(views)
            }

            // 更新 Widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun parseCourses(jsonData: String): List<Course> {
        val courses = mutableListOf<Course>()
        val courseListJson = JSONArray(jsonData)

        for (i in 0 until courseListJson.length()) {
            val courseJsonString = courseListJson.getString(i)
            val courseJson = JSONObject(courseJsonString)
            courses.add(
                Course(
                    name = courseJson.getString("name"),
                    classroom = courseJson.getString("classroom"),
                    startSlot = courseJson.getInt("start_slot"),
                    endSlot = courseJson.getInt("end_slot"),
                    dayOfWeek = courseJson.getInt("day_of_week")
                )
            )
        }
        return courses
    }

    private fun filterTodayCourses(courses: List<Course>): List<Course> {
        val calendar = Calendar.getInstance()
        val today = calendar.get(Calendar.DAY_OF_WEEK) // 1 = Sunday, 2 = Monday, ..., 7 = Saturday

        // 轉換為 Flutter 的格式: 1=週一, 2=週二...7=週日
        val flutterWeekday = if (today == 1) 7 else today - 1

        return courses.filter { it.dayOfWeek == flutterWeekday }.sortedBy { it.startSlot }
    }

    private fun showEmptyView(views: RemoteViews) {
        views.setViewVisibility(R.id.courses_list, RemoteViews.GONE)
        views.setViewVisibility(R.id.empty_view, RemoteViews.VISIBLE)
    }
}
