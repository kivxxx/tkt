import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/navi/navi_screen.dart';
import 'services/storage_service.dart';
import 'services/course_service.dart';
import 'services/calendar_service.dart';
import 'services/ntust_auth_service.dart';
import 'services/notification_service.dart';
import 'services/exact_alarm_service.dart';
import 'providers/theme_provider.dart';
import 'providers/announcement_provider.dart';
import 'providers/language_provider.dart';
import 'config/theme.dart';
import 'config/language.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化通知服務
  await NotificationService.initialize();
  
  // 請求通知權限
  try {
    final hasPermission = await NotificationService.areNotificationsEnabled();
    if (!hasPermission) {
      await NotificationService.requestPermissions();
    }
  } catch (e) {
    print('請求通知權限時發生錯誤: $e');
  }
  
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NtustAuthService>(
          create: (_) => NtustAuthService(),
          lazy: false,
        ),
        Provider<StorageService>(
          create: (_) => storageService,
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(storageService),
        ),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProvider(create: (_) => CourseService()),
        ChangeNotifierProvider(create: (_) => CalendarService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 在 app 啟動後嘗試預先快取校園地圖，減少使用者首次打開時的延遲
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        const imageProvider = AssetImage('assets/images/map.jpg');
        await precacheImage(imageProvider, context);
      } catch (e) {
        // 忽略快取錯誤，避免影響啟動流程
        debugPrint('Precache map failed: $e');
      }

      // Android：檢查是否允許精準鬧鐘，未開啟時引導使用者
      try {
        await ExactAlarmService.ensureExactAlarmEnabled(context);
      } catch (e) {
        debugPrint('Exact alarm check failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        return MaterialApp(
          title: languageProvider.translate('app_name'),
          theme: AppTheme.buildTheme(Brightness.light),
          darkTheme: AppTheme.buildTheme(Brightness.dark),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: languageProvider.currentLocale,
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FutureBuilder(
            future: Future.delayed(const Duration(seconds: 2)), // 初始化載入時間
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                
                return Scaffold(
                  backgroundColor: colorScheme.background,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo容器，使用ClipRRect解決黑邊問題
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              color: Colors.white,
                              child: Image.asset(
                                'assets/images/icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Loading indicator
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // 載入文字
                        Text(
                          '系統初始化中...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 副標題
                        Text(
                          'TKT 台科大校園助手',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const NaviScreen();
            },
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}