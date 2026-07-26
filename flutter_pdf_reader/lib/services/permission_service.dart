import 'dart:io';
import 'package:flutter/services.dart';

/// 存储权限管理服务
///
/// 使用 MethodChannel 调用原生 Android API，不依赖任何第三方包。
/// - Android 11+（API 30+）：检查 MANAGE_EXTERNAL_STORAGE
/// - Android 10 及以下：声明即授权
class PermissionService {
  PermissionService._();

  static const _channel = MethodChannel('com.pdfreader/permission');

  /// 检查并提示用户授权存储权限
  ///
  /// 返回 true 表示权限已获得。
  /// Android 11+：检查 MANAGE_EXTERNAL_STORAGE
  /// Android 10-：默认已授权
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 11+ 需要 MANAGE_EXTERNAL_STORAGE
    if (await _isAndroid11OrAbove()) {
      return _checkManageStorage();
    }

    // Android 10 及以下：声明即授权
    return true;
  }

  /// 检查当前存储权限状态
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    if (await _isAndroid11OrAbove()) {
      try {
        return await _channel.invokeMethod<bool>('hasManageStoragePermission')
            ?? false;
      } catch (_) {
        return false;
      }
    }

    return true;
  }

  /// 打开应用设置页面
  static Future<bool> openSettings() async {
    try {
      await _channel.invokeMethod<bool>('openAppSettings');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isAndroid11OrAbove() async {
    try {
      final version = Platform.operatingSystemVersion;
      final match = RegExp(r'Android (\d+)').firstMatch(version);
      if (match != null) {
        return (int.tryParse(match.group(1) ?? '0') ?? 0) >= 11;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> _checkManageStorage() async {
    try {
      return await _channel.invokeMethod<bool>('hasManageStoragePermission')
          ?? false;
    } catch (_) {
      return false;
    }
  }
}
