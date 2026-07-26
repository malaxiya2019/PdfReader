import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 存储权限管理服务
///
/// Android 版本差异：
/// - Android 11+（API 30+）：需要 MANAGE_EXTERNAL_STORAGE 特殊权限
/// - Android 10（API 29）：需要 READ_EXTERNAL_STORAGE 运行时权限
/// - Android 9 及以下：安装时授权，无需运行时请求
class PermissionService {
  PermissionService._();

  /// 检查并请求存储权限
  ///
  /// 返回 true 表示已获得权限，false 表示被拒绝。
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 11+：请求 MANAGE_EXTERNAL_STORAGE
    if (await _isAndroid11OrAbove()) {
      return _requestManageStorage();
    }

    // Android 10：请求 READ_EXTERNAL_STORAGE
    if (await _isAndroid10()) {
      return _requestReadStorage();
    }

    // Android 9 及以下：无需运行时请求
    return true;
  }

  /// 检查当前存储权限状态
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    if (await _isAndroid11OrAbove()) {
      return await Permission.manageExternalStorage.isGranted;
    }

    if (await _isAndroid10()) {
      return await Permission.storage.isGranted;
    }

    return true;
  }

  /// 打开应用设置页面
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  static Future<bool> _isAndroid11OrAbove() async {
    try {
      final version = Platform.operatingSystemVersion;
      final match = RegExp(r'Android (\d+)').firstMatch(version);
      if (match != null) {
        final major = int.tryParse(match.group(1) ?? '0') ?? 0;
        return major >= 11;
      }
    } catch (_) {}
    // 回退检测
    final mgmt = await Permission.manageExternalStorage.status;
    final storage = await Permission.storage.status;
    return mgmt == PermissionStatus.denied && storage == PermissionStatus.denied;
  }

  static Future<bool> _isAndroid10() async {
    try {
      final version = Platform.operatingSystemVersion;
      final match = RegExp(r'Android (\d+)').firstMatch(version);
      if (match != null) {
        final major = int.tryParse(match.group(1) ?? '0') ?? 0;
        return major == 10;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> _requestManageStorage() async {
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      return false;
    }

    status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  static Future<bool> _requestReadStorage() async {
    var status = await Permission.storage.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      return false;
    }

    status = await Permission.storage.request();
    return status.isGranted;
  }
}
