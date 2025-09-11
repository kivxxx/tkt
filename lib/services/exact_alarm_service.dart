import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 提供 Android 精準鬧鐘狀態檢查與引導開啟的服務
class ExactAlarmService {
  static const MethodChannel _channel = MethodChannel('com.example.tkt/exact_alarm');

  /// 是否允許排程精準鬧鐘（Android 12+ 才有意義；其他平台預設為 true）
  static Future<bool> isExactAlarmAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? allowed = await _channel.invokeMethod<bool>('isExactAlarmAllowed');
      return allowed ?? true;
    } catch (_) {
      // 無法取得狀態時，不阻斷流程
      return true;
    }
  }

  /// 開啟系統設定頁，讓使用者授權精準鬧鐘（僅 Android 有效）
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (_) {
      // 忽略錯誤，避免干擾主流程
    }
  }

  /// 若未開啟精準鬧鐘，彈窗提示並引導使用者前往設定
  static Future<bool> ensureExactAlarmEnabled(BuildContext context) async {
    final allowed = await isExactAlarmAllowed();
    if (allowed) return true;

    if (!context.mounted) return false;

    final bool? goToSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要允許精準鬧鐘'),
        content: const Text('為了準時發送課程提醒，請前往系統設定開啟「精準鬧鐘」。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('稍後'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('前往設定'),
          ),
        ],
      ),
    );

    if (goToSettings == true) {
      await openExactAlarmSettings();
    }
    return false;
  }
}


