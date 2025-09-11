import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tkt/connector/check_login.dart';
import 'package:tkt/debug/log/log.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tkt/models/course_model.dart';
import 'package:tkt/services/course_service.dart';
import 'package:tkt/services/schedule_service.dart';
import 'package:tkt/utils/course_time_util.dart';
import 'package:tkt/widgets/ntust_login_prompt_dialog.dart';
import 'package:tkt/pages/webview_screen.dart';


class CourseScheduleScreen extends StatefulWidget {
  const CourseScheduleScreen({super.key});

  @override
  State<CourseScheduleScreen> createState() => _CourseScheduleScreenState();
}

class _CourseScheduleScreenState extends State<CourseScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _weekdays = ['一', '二', '三', '四', '五', '六'];
  final List<String> _weekdayNames = ['週一', '週二', '週三', '週四', '週五', '週六'];
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    // 計算初始索引，確保在週日時不會超出範圍
    int currentWeekday = DateTime.now().weekday; // 1=週一, 7=週日
    int initialIndex = 0; // 預設為週一
    
    if (currentWeekday >= 1 && currentWeekday <= 6) {
      // 週一到週六
      initialIndex = currentWeekday - 1;
    } else {
      // 週日，預設顯示週一
      initialIndex = 0;
    }
    
    _tabController = TabController(
      length: _weekdays.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridView = prefs.getBool('course_grid_view') ?? false;
    });
  }

  Future<void> _saveViewMode(bool isGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('course_grid_view', isGrid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  Future<void> _importCourses(BuildContext context) async {
    if (!context.mounted) return;
    
    // 顯示載入中對話框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );

    var loginStatus = await CheckLogin.course_login();
    Log.d('Login Status: ${loginStatus.toString()}');

    if (loginStatus == CourseConnectorStatus.loginFail) {
      if (!context.mounted) return;
      // 關閉載入中對話框
      Navigator.pop(context);
      // 直接開啟選課系統登入頁面
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewScreen(
            initialUrl: 'https://stuinfosys.ntust.edu.tw/NTUSTSSOServ/SSO/Login/CourseSelection',
            title: '選課系統登入',
            onLoginResult: (success) async {
              if (success) {
                // 登入成功後自動返回
                Navigator.pop(context, true);
              }
            },
          ),
        ),
      );

      if (result == true) {
        // 使用者從選課系統返回，先等待一下讓登入完成
        // 顯示載入中對話框
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        );

        await Future.delayed(const Duration(seconds: 2));
        
        // 關閉載入中對話框
        if (!context.mounted) return;
        Navigator.pop(context);
        
        // 開啟選課系統頁面
        final courseResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              initialUrl: 'https://courseselection.ntust.edu.tw/ChooseList/D01/D01',
              title: '選課系統',
              onLoginResult: (success) async {
                if (success) {
                  // 等待選課系統載入
                  await Future.delayed(const Duration(seconds: 3));
                  Navigator.pop(context, true);
                }
              },
            ),
          ),
        );

        if (courseResult == true) {
          // 使用者從選課系統返回，重新檢查登入狀態
          // 顯示載入中對話框
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return WillPopScope(
                onWillPop: () async => false,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在重新檢查登入狀態...')),
          );

          // 重新檢查一次登入狀態
          loginStatus = await CheckLogin.course_login();
          Log.d('Rechecked Login Status: ${loginStatus.toString()}');

          if (loginStatus == CourseConnectorStatus.loginFail) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登入後仍無法檢測到有效的課程系統 Session，請稍後再試或登出後重試。')),
          );
          // 關閉載入中對話框
          Navigator.pop(context);
          return;
          }
          // 如果重新檢查成功，繼續匯入流程
        } else {
          return;
        }
      } else {
        // 使用者取消登入
        return;
      }
    } else if (loginStatus == CourseConnectorStatus.unknownError) {
      if (!context.mounted) return;
      // 關閉載入中對話框
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('檢查登入狀態時發生未知錯誤，請稍後再試')),
      );
      return;
    }

    try {
      final courseService = context.read<CourseService>();
      final schedule = await ScheduleService.fetchSchedule(); 

      // 用於儲存處理和合併後的課程列表
      List<Course> processedCourses = [];

      // 遍歷每一天 (週一到週日，但我們通常只關心週一到週五)
      for (int dayIndex = 0; dayIndex < _weekdays.length; dayIndex++) {
        final dayString = _weekdays[dayIndex]; // "一", "二", ...
        final currentDayOfWeek = dayIndex + 1; // 1 for 週一, 2 for 週二, ...

        // 暫存當天的所有原始課程資訊 (名稱, 教室, 節次)
        List<Map<String, dynamic>> coursesOnThisDay = [];

        for (final timeSlot in schedule.timeSlots) {
          final courseInfo = timeSlot.schedule[dayString];
          if (courseInfo != null && courseInfo.name.isNotEmpty) {
            final slotIndex = _getTimeSlotIndex(timeSlot.period); // 假設此方法能正確轉換節次為 1-14
            // 找到原始課程定義以獲取老師和備註等資訊
            String teacherName = '';
            String? courseNote;
            try {
              final originalCourseDef = schedule.courses.firstWhere(
                (c) => c.name == courseInfo.name,
              );
              teacherName = originalCourseDef.teacher;
              courseNote = originalCourseDef.note;
            } catch (e) {
              // 找不到原始課程定義，老師和備註留空
              debugPrint('警告：在 schedule.courses 中找不到課程 "${courseInfo.name}" 的詳細定義。');
            }

            coursesOnThisDay.add({
              'name': courseInfo.name,
              'teacher': teacherName,
              'classroom': courseInfo.classroom,
              'slot': slotIndex,
              'note': courseNote,
            });
          }
        }

        // 對當天的課程按節次排序
        coursesOnThisDay.sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));

        // 合併連續課程
        if (coursesOnThisDay.isNotEmpty) {
          Map<String, dynamic> currentGroupStart = coursesOnThisDay.first;
          int currentGroupEndSlot = currentGroupStart['slot'] as int;

          for (int i = 1; i < coursesOnThisDay.length; i++) {
            final prevCourseInDay = coursesOnThisDay[i-1];
            final currentCourseInDay = coursesOnThisDay[i];

            if (currentCourseInDay['name'] == currentGroupStart['name'] &&
                currentCourseInDay['teacher'] == currentGroupStart['teacher'] &&
                currentCourseInDay['classroom'] == currentGroupStart['classroom'] &&
                (currentCourseInDay['slot'] as int) == (prevCourseInDay['slot'] as int) + 1) {
              // 連續，擴展當前群組
              currentGroupEndSlot = currentCourseInDay['slot'] as int;
            } else {
              // 不連續或課程不同，結束上一個群組並添加到 processedCourses
              processedCourses.add(Course(
                id: DateTime.now().millisecondsSinceEpoch.toString() + currentGroupStart['name'] + currentDayOfWeek.toString() + (currentGroupStart['slot'] as int).toString(), // 確保 ID 唯一性
                name: currentGroupStart['name'] as String,
                teacher: currentGroupStart['teacher'] as String,
                classroom: currentGroupStart['classroom'] as String,
                dayOfWeek: currentDayOfWeek,
                startSlot: currentGroupStart['slot'] as int,
                endSlot: currentGroupEndSlot,
                note: currentGroupStart['note'] as String?,
              ));
              // 開始新群組
              currentGroupStart = currentCourseInDay;
              currentGroupEndSlot = currentGroupStart['slot'] as int;
            }
          }
          // 添加最後一個群組
          processedCourses.add(Course(
            id: DateTime.now().millisecondsSinceEpoch.toString() + currentGroupStart['name'] + currentDayOfWeek.toString() + (currentGroupStart['slot'] as int).toString(),
            name: currentGroupStart['name'] as String,
            teacher: currentGroupStart['teacher'] as String,
            classroom: currentGroupStart['classroom'] as String,
            dayOfWeek: currentDayOfWeek,
            startSlot: currentGroupStart['slot'] as int,
            endSlot: currentGroupEndSlot,
            note: currentGroupStart['note'] as String?,
          ));
        }
      }

      // 將處理後的課程添加到 CourseService (先清空原有課程，再新增)
      await courseService.clearAllCourses();
      for (final courseToAdd in processedCourses) {
        final conflicts = courseService.checkTimeConflicts(courseToAdd);
        if (conflicts.isEmpty) {
          await courseService.addCourse(courseToAdd); // 注意 addCourse 可能是異步的
        } else {
          // 可以選擇性地處理衝突，例如提示使用者
          debugPrint('課程衝突未加入: ${courseToAdd.name} (${courseToAdd.dayOfWeekString} ${courseToAdd.timeSlotString})');
        }
      }
      
      if (!context.mounted) return;
      // 關閉載入中對話框
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課表匯入成功 (已自動合併連續課程)')),
      );
    } catch (e) {
      if (!context.mounted) return;
      // 關閉載入中對話框
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('匯入失敗：$e')),
      );
      debugPrint('匯入課表時發生錯誤: $e'); // 打印更詳細的錯誤到控制台
    }
  }

  Future<bool?> _showLoginPromptDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return NtustLoginPromptDialog();
      },
    );
  }

  // 輔助方法：將節次轉換為時間槽索引 (1-14)
  // 確保這個方法能正確處理 ScheduleService 回傳的 timeSlot.period (例如 "1", "2", ..., "A", "B", ...)
  int _getTimeSlotIndex(String period) {
    // 根據 CourseTimeUtil.timeSlots 找到對應的 index
    try {
      return CourseTimeUtil.timeSlots.firstWhere((slot) => slot.label == period).index;
    } catch (e) {
      // 如果找不到，給一個預設值或拋出錯誤，這裡先給1，但最好能處理所有情況
      debugPrint('無法轉換節次 "$period" 為索引，預設為1');
      return 1; 
    }
  }

  Future<void> _showAddCourseDialog(BuildContext context, [Course? courseToEdit]) async {
    final formKey = GlobalKey<FormState>();
    String name = courseToEdit?.name ?? '';
    String teacher = courseToEdit?.teacher ?? '';
    String classroom = courseToEdit?.classroom ?? '';
    int dayOfWeek = courseToEdit?.dayOfWeek ?? DateTime.now().weekday;
    if (dayOfWeek > 6) dayOfWeek = 1; // 僅允許週一至週六
    int startSlot = courseToEdit?.startSlot ?? 1;
    int endSlot = courseToEdit?.endSlot ?? 1;
    String? note = courseToEdit?.note;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(courseToEdit == null ? '新增課程' : '編輯課程'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: '課程名稱'),
                    validator: (value) => value?.isEmpty ?? true ? '請輸入課程名稱' : null,
                    initialValue: name,
                    onSaved: (value) => name = value!,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: '教師'),
                    initialValue: teacher,
                    onSaved: (value) => teacher = value!,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: '教室'),
                    initialValue: classroom,
                    onSaved: (value) => classroom = value!,
                  ),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: '星期'),
                    value: dayOfWeek,
                    items: List.generate(
                      6,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('週${_weekdays[index]}'),
                      ),
                    ),
                    onChanged: (value) => dayOfWeek = value!,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: '開始節次',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: startSlot,
                          items: CourseTimeUtil.timeSlots.map((slot) {
                            return DropdownMenuItem(
                              value: slot.index,
                              child: Text('${slot.label} (${slot.formattedStartTime})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                startSlot = value;
                                // 如果結束時間早於開始時間，自動調整結束時間
                                if (endSlot < startSlot) {
                                  endSlot = startSlot;
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: '結束節次',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: endSlot,
                          items: CourseTimeUtil.timeSlots
                              .where((slot) => slot.index >= startSlot)
                              .map((slot) {
                            return DropdownMenuItem(
                              value: slot.index,
                              child: Text('${slot.label} (${slot.formattedEndTime})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && value >= startSlot) {
                              setState(() {
                                endSlot = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: '備註（選填）'),
                    initialValue: note,
                    onSaved: (value) => note = value,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState!.save();
                  final courseService = context.read<CourseService>();
                  final course = Course(
                    id: courseToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    teacher: teacher,
                    classroom: classroom,
                    dayOfWeek: dayOfWeek,
                    startSlot: startSlot,
                    endSlot: endSlot,
                    note: note,
                  );

                  // 檢查時間衝突（排除自己）
                  final conflicts = courseService.checkTimeConflicts(course)
                      .where((c) => c.id != course.id)
                      .toList();
                      
                  if (conflicts.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('時間衝突'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('此課程與以下課程時間衝突：'),
                            const SizedBox(height: 8),
                            ...conflicts.map((c) => Text('• ${c.name} (${c.timeSlotString})')),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('返回修改'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  if (courseToEdit != null) {
                    courseService.updateCourse(course);
                  } else {
                    courseService.addCourse(course);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(courseToEdit == null ? '儲存' : '更新'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final today = DateTime.now().weekday - 1; // 0-6 for TabBar index

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '我的課表',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isGridView ? 1 : kToolbarHeight + 1),
          child: Column(
            children: [
              if (!_isGridView)
                Container(
                  color: colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    dividerColor: Colors.transparent,
                    tabAlignment: TabAlignment.center,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 3,
                      ),
                      insets: const EdgeInsets.only(bottom: 0),
                    ),
                    tabs: List.generate(
                      _weekdays.length,
                      (index) => Tab(
                        height: kToolbarHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: index == today
                                      ? colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _weekdays[index],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: index == today 
                                          ? colorScheme.primary 
                                          : colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      index == today ? '今天' : _weekdayNames[index],
                                      style: TextStyle(
                                        color: index == today
                                            ? colorScheme.primary.withOpacity(0.7)
                                            : colorScheme.onSurfaceVariant.withOpacity(0.7),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                height: 1,
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
              ),
              tooltip: _isGridView ? '切換為分日檢視' : '切換為網格檢視',
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
                _saveViewMode(_isGridView);
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'add':
                    _showAddCourseDialog(context);
                    break;
                  case 'import':
                    _importCourses(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add',
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('新增課程'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.school),
                    title: Text('匯入台科大課表'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isGridView
          ? _WeeklyGridView(
              onEditCourse: (course) => _showAddCourseDialog(context, course),
            )
          : TabBarView(
              controller: _tabController,
              children: List.generate(
                _weekdays.length,
                (index) => _DayScheduleView(
                  dayOfWeek: index + 1,
                  onEditCourse: (course) => _showAddCourseDialog(context, course),
                ),
              ),
            ),
    );
  }
}

class _DayScheduleView extends StatelessWidget {
  final int dayOfWeek;
  final Function(Course) onEditCourse;

  const _DayScheduleView({
    required this.dayOfWeek,
    required this.onEditCourse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<CourseService>(
      builder: (context, courseService, child) {
        final dailyCourses = courseService.getCoursesByDay(dayOfWeek);
        
        if (dailyCourses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 80,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  '今天沒有課程',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '好好休息一下，或新增課程吧！', 
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                )
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: dailyCourses.length,
          itemBuilder: (context, index) {
            final course = dailyCourses[index];
            final startTime = CourseTimeUtil.getTimeSlotByIndex(course.startSlot);
            final endTime = CourseTimeUtil.getTimeSlotByIndex(course.endSlot);
            
            return Card(
              elevation: 2.5,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onEditCourse(course),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 90,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  course.timeSlotString,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${startTime.formattedStartTime}\n-\n${endTime.formattedEndTime}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  theme,
                                  icon: Icons.person_outline,
                                  text: course.teacher.isNotEmpty ? course.teacher : '-',
                                ),
                                const SizedBox(height: 6),
                                _buildInfoRow(
                                  theme,
                                  icon: Icons.location_on_outlined,
                                  text: course.classroom.isNotEmpty ? course.classroom : '-',
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton(
                            icon: Icon(
                              Icons.more_vert,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (context) => [
                              _buildPopupMenuItem(
                                theme,
                                value: 'edit',
                                icon: Icons.edit_outlined,
                                text: '編輯',
                                color: theme.colorScheme.primary,
                              ),
                              _buildPopupMenuItem(
                                theme,
                                value: 'delete',
                                icon: Icons.delete_outline,
                                text: '刪除',
                                color: theme.colorScheme.error,
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEditCourse(course);
                              } else if (value == 'delete') {
                                _showDeleteConfirmationDialog(context, courseService, course, theme);
                              }
                            },
                          ),
                        ],
                      ),
                      if (course.note != null && course.note!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                size: 20,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  course.note!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(ThemeData theme, {required String value, required IconData icon, required String text, Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? theme.colorScheme.onSurface),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color ?? theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, {required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context, CourseService courseService, Course course, ThemeData theme) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${course.name} (${course.timeSlotString})」這門課程嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              courseService.removeCourse(course.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('「${course.name} (${course.timeSlotString})」已刪除')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGridView extends StatelessWidget {
  const _WeeklyGridView({required this.onEditCourse});

  final Function(Course) onEditCourse;

  static const List<String> _weekdays = ['一', '二', '三', '四', '五', '六'];

  static const List<Color> _colorPool = [
    Color(0xFFFFCDD2),
    Color(0xFFFFF9C4),
    Color(0xFFB2EBF2),
    Color(0xFFC8E6C9),
    Color(0xFFD1C4E9),
    Color(0xFFFFE0B2),
    Color(0xFFFFF8E1),
    Color(0xFFB2DFDB),
    Color(0xFFFFF176),
    Color(0xFFB39DDB),
  ];

  Color _getCourseColor(String name, Map<String, Color> colorMap) {
    if (colorMap.containsKey(name)) return colorMap[name]!;
    final idx = colorMap.length % _colorPool.length;
    final color = _colorPool[idx];
    colorMap[name] = color;
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseService = Provider.of<CourseService>(context);
    final courses = courseService.courses;
    final colorMap = <String, Color>{};

    final slotCount = CourseTimeUtil.timeSlots.length; // 14 (含 A-D)
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.6);
    final rowMinHeight = 48.0 * textScale; // 最小列高，內容多會自適應增高

    // 建立格子資料
    List<List<Course?>> grid = List.generate(
      slotCount,
      (_) => List.filled(_weekdays.length, null),
    );
    for (final course in courses) {
      if (course.dayOfWeek >= 1 && course.dayOfWeek <= 6) {
        for (int slot = course.startSlot; slot <= course.endSlot; slot++) {
          if (slot >= 1 && slot <= slotCount) {
            grid[slot - 1][course.dayOfWeek - 1] = course;
          }
        }
      }
    }

    final todayWeekday = DateTime.now().weekday; // 1=Mon..7=Sun

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 左側節次較窄，其餘平均分配，確保總寬不超出可視寬
          const horizontalPadding = 16.0;
          final availableWidth = constraints.maxWidth - horizontalPadding;
          const leftWidth = 28.0;
          final dayWidth = ((availableWidth - leftWidth) / _weekdays.length).floorToDouble();
          final totalTableWidth = leftWidth + dayWidth * _weekdays.length;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SizedBox(
                    width: totalTableWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3), width: 0.6),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(6.0),
                      child: Table(
                        border: TableBorder.symmetric(
                          inside: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.25), width: 0.6),
                          outside: BorderSide(color: Colors.transparent, width: 0),
                        ),
                        columnWidths: {
                          0: const FixedColumnWidth(leftWidth),
                          for (int i = 1; i <= _weekdays.length; i++) i: FixedColumnWidth(dayWidth),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
                              _buildHeaderCell('節次', theme, minHeight: 40),
                              for (int d = 0; d < _weekdays.length; d++)
                                _buildHeaderCell(
                                  _weekdays[d],
                                  theme,
                                  minHeight: 40,
                                  highlight: (todayWeekday >= 1 && todayWeekday <= 6) && (d + 1 == todayWeekday),
                                ),
                            ],
                          ),
                          for (int i = 0; i < slotCount; i++)
                            TableRow(
                              children: [
                                _buildHeaderCell(
                                  CourseTimeUtil.timeSlots[i].label,
                                  theme,
                                  isTimeSlot: true,
                                  minHeight: rowMinHeight,
                                ),
                                ...List.generate(_weekdays.length, (j) {
                                  final course = grid[i][j];
                                  if (course == null) {
                                    return _buildEmptyCell(theme, rowMinHeight);
                                  }
                                  final base = _getCourseColor(course.name, colorMap);
                                  final pillBg = base.withOpacity(0.18);
                                  final pillBorder = base.withOpacity(0.35);
                                  return _buildCoursePill(
                                    course: course,
                                    theme: theme,
                                    minHeight: rowMinHeight,
                                    background: pillBg,
                                    borderColor: pillBorder,
                                    onTap: () => onEditCourse(course),
                                  );
                                }),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCell(String text, ThemeData theme, {bool isTimeSlot = false, double minHeight = 48, bool highlight = false}) {
    final child = Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: highlight ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        fontSize: isTimeSlot ? 12.0 : null, // 節次欄位使用更小的字體
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: isTimeSlot ? 2 : 6, vertical: 6),
      color: isTimeSlot ? theme.colorScheme.surfaceVariant.withOpacity(0.15) : Colors.transparent,
      child: highlight
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 0.8),
              ),
              child: child,
            )
          : child,
    );
  }

  Widget _buildEmptyCell(ThemeData theme, double minHeight) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      alignment: Alignment.center,
      color: Colors.transparent,
    );
  }

  Widget _buildCoursePill({
    required Course course,
    required ThemeData theme,
    required double minHeight,
    required Color background,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        alignment: Alignment.center,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Text(
          course.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}