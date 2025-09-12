import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/course_model.dart';
import 'app_group_preferences.dart';

class AppGroupService {
  static const String _appGroupId = 'group.com.example.tkt.TKTWidget'; // 與 entitlements 中的 App Group ID 一致
  static const String _coursesKey = 'courses'; // 與 Widget 使用相同的鍵值
  static const String _lastUpdateKey = 'last_update';

  static AppGroupService? _instance;

  AppGroupService._();

  static AppGroupService get instance {
    _instance ??= AppGroupService._();
    return _instance!;
  }

  /// 初始化 App Group SharedPreferences
  Future<void> initialize() async {
    try {
      await AppGroupPreferences.initialize();
      debugPrint('AppGroupService 初始化成功');
    } catch (e) {
      debugPrint('AppGroupService 初始化失敗: $e');
    }
  }

  /// 儲存課程資料到 App Group
  Future<bool> saveCourses(List<Course> courses) async {
    try {
      debugPrint('🔄 開始儲存 ${courses.length} 門課程到 App Group');
      
      final coursesJson = courses
          .map((course) => jsonEncode(course.toJson()))
          .toList();
      
      debugPrint('📋 課程 JSON 資料：');
      for (int i = 0; i < coursesJson.length && i < 3; i++) {
        debugPrint('  課程 $i: ${coursesJson[i]}');
      }
      
      // iOS
      final success = await AppGroupPreferences.setStringList(_coursesKey, coursesJson);
      if (success) {
        // 更新最後修改時間
        await AppGroupPreferences.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('✅ 已儲存 ${courses.length} 門課程到 App Group (for iOS)');
      } else {
        debugPrint('❌ 儲存課程到 App Group 失敗 (for iOS)');
      }

      // Android
      if (Platform.isAndroid) {
        try {
          // 將課程列表轉換為 JSON 字串
          final coursesDataString = jsonEncode(coursesJson);

          // 儲存資料給 Android Widget
          await HomeWidget.saveWidgetData<String>('courses_data', coursesDataString);

          // 更新 Android Widget
          await HomeWidget.updateWidget(
            name: 'TKTWidgetProvider', // 必須與您在 Android 中定義的 Provider 名稱相符
            androidName: 'TKTWidgetProvider',
          );
          debugPrint('✅ 已觸發 Android Widget 更新');
        } catch (e) {
          debugPrint('❌ 更新 Android Widget 時發生錯誤: $e');
        }
      }

      return success;
    } catch (e) {
      debugPrint('💥 儲存課程到 App Group 時發生錯誤: $e');
      return false;
    }
  }

  /// 從 App Group 載入課程資料
  Future<List<Course>> loadCourses() async {
    try {
      final coursesJson = await AppGroupPreferences.getStringList(_coursesKey) ?? [];
      debugPrint('📋 從 App Group 讀取到的原始資料數量: ${coursesJson.length}');
      
      final courses = <Course>[];
      for (int i = 0; i < coursesJson.length; i++) {
        try {
          final jsonString = coursesJson[i];
          debugPrint('🔍 處理課程資料 $i: $jsonString');
          
          if (jsonString.isNotEmpty) {
            final courseData = jsonDecode(jsonString);
            final course = Course.fromJson(courseData);
            courses.add(course);
            debugPrint('✅ 成功解析課程 $i: ${course.name}');
          } else {
            debugPrint('⚠️ 跳過空白的課程資料 $i');
          }
        } catch (e) {
          debugPrint('❌ 解析課程 $i 時發生錯誤: $e');
          debugPrint('📋 問題資料: ${coursesJson[i]}');
        }
      }
      
      debugPrint('從 App Group 載入 ${courses.length} 門課程');
      return courses;
    } catch (e) {
      debugPrint('從 App Group 載入課程時發生錯誤: $e');
      return [];
    }
  }

  /// 獲取最後更新時間
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final timestamp = await AppGroupPreferences.getInt(_lastUpdateKey);
      return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
    } catch (e) {
      debugPrint('獲取最後更新時間時發生錯誤: $e');
      return null;
    }
  }

  /// 清除所有課程資料
  Future<bool> clearCourses() async {
    try {
      final success1 = await AppGroupPreferences.remove(_coursesKey);
      final success2 = await AppGroupPreferences.remove(_lastUpdateKey);
      if (success1 && success2) {
        debugPrint('已清除 App Group 中的課程資料');
      }
      return success1 && success2;
    } catch (e) {
      debugPrint('清除 App Group 課程資料時發生錯誤: $e');
      return false;
    }
  }

  /// 檢查是否有資料
  Future<bool> hasCourseData() async {
    try {
      return await AppGroupPreferences.containsKey(_coursesKey);
    } catch (e) {
      debugPrint('檢查課程資料時發生錯誤: $e');
      return false;
    }
  }

  /// 獲取今日課程（給 Widget 使用）
  Future<List<Course>> getTodayCourses() async {
    final courses = await loadCourses();
    final now = DateTime.now();
    final todayCourses = courses
        .where((course) => course.dayOfWeek == now.weekday)
        .toList()
      ..sort((a, b) => a.startSlot.compareTo(b.startSlot));
    
    debugPrint('今日課程數量（App Group）：${todayCourses.length}');
    return todayCourses;
  }

  /// 獲取即將到來的課程（給 Widget 使用）
  Future<List<Course>> getUpcomingCourses() async {
    final todayCourses = await getTodayCourses();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    // 這裡需要導入 CourseTimeUtil，但為了避免循環依賴，我們簡化處理
    final upcomingCourses = todayCourses.where((course) {
      // 簡單的時間比較，假設每節課 50 分鐘
      final estimatedEndTime = (course.startSlot + 1) * 50 + 8 * 60; // 假設第一節課從 8:00 開始
      return estimatedEndTime > currentMinutes;
    }).toList();
    
    debugPrint('即將到來的課程數量（App Group）：${upcomingCourses.length}');
    return upcomingCourses;
  }

  /// 獲取應用程式群組 ID（供 Widget 使用）
  static String get appGroupId => _appGroupId;
}
