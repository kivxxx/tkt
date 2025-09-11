import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/course_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/exact_alarm_service.dart';


class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _courseNotificationEnabled = true;
  int _notificationMinutes = 15; // 預設提前15分鐘提醒
  
  final List<int> _notificationOptions = [
    5,   // 5分鐘前
    10,  // 10分鐘前
    15,  // 15分鐘前
    30,  // 30分鐘前
    60,  // 1小時前
    120, // 2小時前
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _courseNotificationEnabled = prefs.getBool('course_notification_enabled') ?? true;
      _notificationMinutes = prefs.getInt('notification_minutes') ?? 15;
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('course_notification_enabled', _courseNotificationEnabled);
    await prefs.setInt('notification_minutes', _notificationMinutes);
    
    // 重新安排課程通知
    if (mounted) {
      final courseService = context.read<CourseService>();
      await courseService.rescheduleNotifications();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知設定已儲存')),
      );
    }
  }

  String _getNotificationText(int minutes) {
    if (minutes < 60) {
      return '$minutes 分鐘前';
    } else {
      final hours = minutes ~/ 60;
      return '$hours 小時前';
    }
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService.sendTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 測試通知發送成功！請檢查您的通知欄'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 測試通知發送失敗：$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNotificationSettings,
            tooltip: '儲存設定',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '課程提醒',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在課程開始前發送提醒通知',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('啟用課程提醒'),
                    subtitle: const Text('在課程開始前發送推播通知'),
                    value: _courseNotificationEnabled,
                    onChanged: (bool value) async {
                      setState(() {
                        _courseNotificationEnabled = value;
                      });

                      // 若用戶嘗試開啟，先檢查 Android 精準鬧鐘
                      if (value) {
                        final allowed = await ExactAlarmService.isExactAlarmAllowed();
                        if (!allowed) {
                          if (!mounted) return;
                          await showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('未開啟精準鬧鐘'),
                              content: const Text('裝置尚未允許「精準鬧鐘」，將無法準時發送課程提醒。系統已為你關閉通知。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('知道了'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(ctx).pop();
                                    await ExactAlarmService.openExactAlarmSettings();
                                  },
                                  child: const Text('前往設定'),
                                ),
                              ],
                            ),
                          );

                          // 自動關回開關並儲存
                          if (!mounted) return;
                          setState(() {
                            _courseNotificationEnabled = false;
                          });
                          await _saveNotificationSettings();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('未開啟精準鬧鐘，已關閉課程提醒'),
                              ),
                            );
                          }
                          return;
                        }
                      }

                      // 直接儲存設定並重排程/取消
                      await _saveNotificationSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_courseNotificationEnabled) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '提醒時間',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '選擇在課程開始前多久發送提醒',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: _notificationOptions.map((minutes) {
                        return RadioListTile<int>(
                          title: Text(_getNotificationText(minutes)),
                          value: minutes,
                          groupValue: _notificationMinutes,
                          onChanged: (int? value) {
                            if (value != null) {
                              setState(() {
                                _notificationMinutes = value;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
                         ),
             const SizedBox(height: 16),
             Card(
               child: Padding(
                 padding: const EdgeInsets.all(16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         Icon(
                           Icons.bug_report,
                           color: Theme.of(context).primaryColor,
                           size: 20,
                         ),
                         const SizedBox(width: 8),
                         Text(
                           '測試功能',
                           style: Theme.of(context).textTheme.titleSmall?.copyWith(
                             fontWeight: FontWeight.bold,
                             color: Theme.of(context).primaryColor,
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 8),
                     Text(
                       '測試通知功能是否正常運作',
                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
                         color: Colors.grey[600],
                       ),
                     ),
                     const SizedBox(height: 12),
                     SizedBox(
                       width: double.infinity,
                       child: ElevatedButton.icon(
                         onPressed: _courseNotificationEnabled ? _testNotification : null,
                         icon: const Icon(Icons.send),
                         label: const Text('發送測試通知'),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 16),
             Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '注意事項',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 請確保您的裝置允許此應用程式發送通知\n'
                      '• 排程建立後，就算關閉或滑掉 App 也會準時提醒\n'
                      '• 課程採每週固定時間提醒（於上課前 N 分鐘）',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
