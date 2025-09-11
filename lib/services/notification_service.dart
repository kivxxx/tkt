import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/course_model.dart';
import 'exact_alarm_service.dart';

class NotificationService {
  static const String _enabledKey = 'course_notification_enabled';
  static const String _minutesKey = 'notification_minutes';
  
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

  /// 為 iOS 配置通知設定
  static Future<void> _configureiOSNotifications() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      if (ios != null) {
        final permissions = await ios.checkPermissions();
        if (kDebugMode) {
          print('📱 iOS 通知權限詳情:');
          print('- 整體啟用: ${permissions?.isEnabled}');
          print('- Alert: ${permissions?.isAlertEnabled}');
          print('- Badge: ${permissions?.isBadgeEnabled}');
          print('- Sound: ${permissions?.isSoundEnabled}');
          print('- Provisional: ${permissions?.isProvisionalEnabled}');
        }
      }
    }
  }

  /// 初始化通知服務
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化時區
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      // 讓前景時也能顯示通知（可被單則通知覆蓋）
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 為 iOS 進行額外配置
    await _configureiOSNotifications();

    _isInitialized = true;
    if (kDebugMode) {
      print('📱 NotificationService initialized');
    }
  }

  /// 請求通知權限
  static Future<bool> requestPermissions() async {
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      final bool? result = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: false,
        provisional: false,
      );
      
      if (kDebugMode) {
        print('📱 iOS 通知權限請求結果: $result');
      }
      
      return result ?? false;
    }
    return true;
  }

  /// 處理通知被點擊
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    if (kDebugMode) {
      print('📱 Notification tapped: ${notificationResponse.payload}');
    }
    // TODO: 實現通知點擊後的導航邏輯
  }

  /// 獲取通知是否啟用
  static Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// 獲取提醒時間（分鐘）
  static Future<int> getNotificationMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_minutesKey) ?? 15;
  }

  /// 設定通知啟用狀態
  static Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// 設定提醒時間
  static Future<void> setNotificationMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minutesKey, minutes);
  }

  /// 計算課程的提醒時間
  static DateTime calculateNotificationTime(Course course, int minutesBefore) {
    return course.startTime.subtract(Duration(minutes: minutesBefore));
  }

  /// 檢查是否需要為課程設定提醒
  static bool shouldScheduleNotification(Course course) {
    final now = DateTime.now();
    final courseDateTime = course.startTime;

    // 只為今天和明天的課程設定提醒
    final isToday = courseDateTime.year == now.year &&
        courseDateTime.month == now.month &&
        courseDateTime.day == now.day;

    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = courseDateTime.year == tomorrow.year &&
        courseDateTime.month == tomorrow.month &&
        courseDateTime.day == tomorrow.day;

    return (isToday || isTomorrow) && courseDateTime.isAfter(now);
  }

  /// 格式化通知內容
  static String formatNotificationTitle(Course course, int minutesBefore) {
    if (minutesBefore < 60) {
      return '課程提醒：${course.name} 將在 $minutesBefore 分鐘後開始';
    } else {
      final hours = minutesBefore ~/ 60;
      return '課程提醒：${course.name} 將在 $hours 小時後開始';
    }
  }

  /// 格式化通知詳細內容
  static String formatNotificationBody(Course course) {
    return '時間：${course.formattedTimeRange}\n'
           '地點：${course.classroom}\n'
           '授課教師：${course.teacher}';
  }

  /// 發送即時通知（測試用）
  static Future<void> sendNotification({
    required String title,
    required String body,
    required Course course,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'course_reminder_channel',
      '課程提醒',
      channelDescription: '課程開始前的提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      course.id.hashCode, // 使用課程ID的hash作為通知ID
      title,
      body,
      platformChannelSpecifics,
      payload: course.id,
    );

    if (kDebugMode) {
      print('📱 即時通知已發送：');
      print('標題：$title');
      print('內容：$body');
      print('課程：${course.name}');
    }
  }

  /// 安排定時通知
  static Future<void> scheduleNotification({
    required Course course,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    await initialize();
    
    // Android：若未允許精準鬧鐘，避免觸發未捕捉例外
    if (defaultTargetPlatform == TargetPlatform.android) {
      final allowed = await ExactAlarmService.isExactAlarmAllowed();
      if (!allowed) {
        if (kDebugMode) {
          print('⚠️ 略過排程：未允許精準鬧鐘（scheduleNotification）');
        }
        return;
      }
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'course_reminder_channel',
      '課程提醒',
      channelDescription: '課程開始前的提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        course.id.hashCode,
        title,
        body,
        tzScheduledTime,
        platformChannelSpecifics,
        payload: course.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        if (kDebugMode) {
          print('⚠️ 無法使用精準鬧鐘，退回非精準排程（單次）');
        }
        // 退回使用非精準排程以避免崩潰
        await _notificationsPlugin.zonedSchedule(
          course.id.hashCode,
          title,
          body,
          tzScheduledTime,
          platformChannelSpecifics,
          payload: course.id,
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
      } else {
        rethrow;
      }
    }

    if (kDebugMode) {
      print('⏰ 定時通知已安排：');
      print('課程：${course.name}');
      print('標題：$title');
      print('內容：$body');
      print('通知時間：${scheduledTime.toString()}');
      print('---');
    }
  }

  /// 計算下一次「指定星期+時間」的觸發點，並提前 minutesBefore 分鐘
  static tz.TZDateTime _nextInstanceOfWeekdayTime({
    required int weekday, // 1=Mon..7=Sun
    required int hour,
    required int minute,
    required int minutesBefore,
  }) {
    final now = tz.TZDateTime.now(tz.local);

    // 先定位到今天同一時間
    tz.TZDateTime candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 跳到目標星期
    int daysToAdd = (weekday - candidate.weekday) % 7;
    candidate = candidate.add(Duration(days: daysToAdd));

    // 提前 minutesBefore 分鐘
    candidate = candidate.subtract(Duration(minutes: minutesBefore));

    // 若時間已經過去，推遲一週
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  /// 針對單一課程建立「每週重複」通知
  static Future<void> scheduleWeeklyNotificationForCourse(Course course) async {
    await initialize();

    final minutesBefore = await getNotificationMinutes();

    // 從課程物件取得開始時間的 時:分
    final startHour = course.startTime.hour;
    final startMinute = course.startTime.minute;

    final tz.TZDateTime firstTrigger = _nextInstanceOfWeekdayTime(
      weekday: course.dayOfWeek.clamp(1, 7),
      hour: startHour,
      minute: startMinute,
      minutesBefore: minutesBefore,
    );

    final title = formatNotificationTitle(course, minutesBefore);
    final body = formatNotificationBody(course);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'course_reminder_channel',
      '課程提醒',
      channelDescription: '課程開始前的提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // 可選：threadIdentifier 讓同課程通知分組
      // threadIdentifier: 'course_reminder',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Android：若未允許精準鬧鐘，避免觸發未捕捉例外
    if (defaultTargetPlatform == TargetPlatform.android) {
      final allowed = await ExactAlarmService.isExactAlarmAllowed();
      if (!allowed) {
        if (kDebugMode) {
          print('⚠️ 略過排程：未允許精準鬧鐘（weekly）');
        }
        return;
      }
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        course.id.hashCode,
        title,
        body,
        firstTrigger,
        platformDetails,
        payload: course.id,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        if (kDebugMode) {
          print('⚠️ 無法使用精準鬧鐘，退回非精準排程（weekly）');
        }
        await _notificationsPlugin.zonedSchedule(
          course.id.hashCode,
          title,
          body,
          firstTrigger,
          platformDetails,
          payload: course.id,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
      } else {
        rethrow;
      }
    }

    if (kDebugMode) {
      print('📆 已為課程建立每週提醒: ${course.name}');
      print('  星期: ${course.dayOfWeek}, 時間: $startHour:$startMinute, 提前: $minutesBefore 分鐘');
      print('  首次觸發: $firstTrigger');
    }
  }

  /// 與既有呼叫點相容：為所有課程安排通知（改為每週重複）
  static Future<void> scheduleNotificationsForCourses(List<Course> courses) async {
    await scheduleWeeklyNotificationsForCourses(courses);
  }

  /// 針對多個課程建立「每週重複」通知（建議啟動時或課表變更時呼叫）
  static Future<void> scheduleWeeklyNotificationsForCourses(List<Course> courses) async {
    await initialize();

    // 檢查開關
    final enabled = await isNotificationEnabled();
    if (!enabled) {
      if (kDebugMode) print('🔕 通知開關為關閉狀態，略過排程');
      return;
    }

    // 檢查權限
    final hasPermission = await areNotificationsEnabled();
    if (!hasPermission) {
      final granted = await requestPermissions();
      if (!granted) {
        if (kDebugMode) print('❌ 用戶未授權通知，略過排程');
        return;
      }
    }

    for (final c in courses) {
      // 先用同 ID 取消，避免重複排程
      await _notificationsPlugin.cancel(c.id.hashCode);
      await scheduleWeeklyNotificationForCourse(c);
    }
  }

  /// 取消所有課程通知
  static Future<void> cancelAllNotifications() async {
    await initialize();
    await _notificationsPlugin.cancelAll();
    if (kDebugMode) {
      print('🚫 已取消所有課程通知');
    }
  }

  /// 取消特定課程的通知
  static Future<void> cancelCourseNotification(Course course) async {
    await initialize();
    await _notificationsPlugin.cancel(course.id.hashCode);
    if (kDebugMode) {
      print('🚫 已取消課程通知：${course.name}');
    }
  }

  /// 檢查通知權限狀態
  static Future<bool> areNotificationsEnabled() async {
    await initialize();
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      final permissions = await ios?.checkPermissions();
      final isEnabled = permissions?.isEnabled ?? false;
      
      if (kDebugMode) {
        print('📱 iOS 通知權限狀態: $isEnabled');
        print('📱 詳細權限: alert=${permissions?.isAlertEnabled}, '
              'badge=${permissions?.isBadgeEnabled}, '
              'sound=${permissions?.isSoundEnabled}');
      }
      
      return isEnabled;
    }
    
    return false;
  }

  /// 發送測試通知
  static Future<void> sendTestNotification() async {
    await initialize();
    
    if (kDebugMode) {
      print('📱 開始發送測試通知...');
    }
    
    // 檢查權限
    final hasPermission = await areNotificationsEnabled();
    if (kDebugMode) {
      print('📱 當前通知權限狀態: $hasPermission');
    }
    
    if (!hasPermission) {
      if (kDebugMode) {
        print('📱 權限不足，嘗試請求權限...');
      }
      final granted = await requestPermissions();
      if (kDebugMode) {
        print('📱 權限請求結果: $granted');
      }
      if (!granted) {
        throw Exception('通知權限被拒絕');
      }
    }

    // 創建測試課程
    final testCourse = Course(
      id: 'test_notification_${DateTime.now().millisecondsSinceEpoch}',
      name: '測試課程',
      teacher: '測試老師',
      classroom: '測試教室',
      dayOfWeek: DateTime.now().weekday <= 5 ? DateTime.now().weekday : 1,
      startSlot: 1,
      endSlot: 2,
      note: '這是一個測試通知',
    );

    final minutesBefore = await getNotificationMinutes();
    final title = formatNotificationTitle(testCourse, minutesBefore);
    final body = formatNotificationBody(testCourse);

    if (kDebugMode) {
      print('📱 準備發送通知:');
      print('標題: $title');
      print('內容: $body');
    }

    await sendNotification(
      title: title,
      body: body,
      course: testCourse,
    );
    
    if (kDebugMode) {
      print('📱 測試通知發送完成');
    }
  }
}