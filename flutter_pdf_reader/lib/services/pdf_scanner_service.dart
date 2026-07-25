import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_file_info.dart';

/// PDF 文件扫描服务
///
/// 性能优化 (Phase 9):
/// - 使用异步 [list] 替代同步 [listSync] 避免主线程阻塞
/// - 缓存扫描结果，3 秒内重复扫描不重新遍历目录
/// - 流式扫描：边扫描边返回，不等待全部结束
class PdfScannerService {
  PdfScannerService._();

  /// 常见 PDF 目录（按优先级排序）
  static final List<String> _scanPaths = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/Android/media/com.tencent.mm/MicroMsg/Download',
    '/storage/emulated/0/tencent/MicroMsg/Download',
    '/storage/emulated/0/Android/media/com.tencent.mobileqq/Tencent/QQfile_recv',
    '/storage/emulated/0/tencent/QQfile_recv',
    '/storage/emulated/0/',
  ];

  /// 扫描缓存（避免短时间内重复遍历磁盘）
  static List<PdfFileInfo>? _cache;
  static DateTime _lastScanTime = DateTime(2000);
  static const Duration _cacheTtl = Duration(seconds: 3);

  /// 是否使用缓存
  static bool get _shouldUseCache =>
      _cache != null &&
      DateTime.now().difference(_lastScanTime) < _cacheTtl;

  // ============================================================
  // 收藏操作
  // ============================================================

  static Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('favorites') ?? <String>[]).toSet();
  }

  static Future<void> toggleFavorite(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorites') ?? [];
    if (list.contains(path)) {
      list.remove(path);
    } else {
      list.add(path);
    }
    await prefs.setStringList('favorites', list);
  }

  static Future<void> addFavorite(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorites') ?? [];
    if (!list.contains(path)) {
      list.add(path);
      await prefs.setStringList('favorites', list);
    }
  }

  static Future<void> removeFavorite(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorites') ?? [];
    list.remove(path);
    await prefs.setStringList('favorites', list);
  }

  // ============================================================
  // 异步目录扫描（性能优化核心）
  // ============================================================

  /// 异步扫描单个目录中的 PDF 文件
  ///
  /// 使用 [list]（异步）替代 [listSync]（同步阻塞），
  /// 避免大目录扫描时卡死 UI。
  static Future<List<PdfFileInfo>> scanDirectory(String dirPath) async {
    final files = <PdfFileInfo>[];
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return files;

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          try {
            final stat = await entity.stat();
            files.add(PdfFileInfo(
              path: entity.path,
              name: entity.uri.pathSegments.last,
              sizeInBytes: stat.size,
              lastModified: stat.modified,
            ));
          } catch (_) {
            // skip unreadable files
          }
        }
      }
    } catch (_) {
      // permission denied or directory not accessible
    }
    return files;
  }

  /// 扫描多个常见目录，返回去重后的 PDF 列表。
  ///
  /// 使用缓存：3 秒内重复调用直接返回上次结果，
  /// 避免频繁遍历文件系统（例如页面重建时）。
  static Future<List<PdfFileInfo>> scanAllCommonDirectories() async {
    if (_shouldUseCache) return _cache!;

    final favorites = await getFavorites();
    final seenPaths = <String>{};
    final allFiles = <PdfFileInfo>[];

    for (final path in _scanPaths) {
      final files = await scanDirectory(path);
      for (final file in files) {
        if (!seenPaths.contains(file.path)) {
          seenPaths.add(file.path);
          file.isFavorite = favorites.contains(file.path);
          allFiles.add(file);
        }
      }
    }

    allFiles.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    // 更新缓存
    _cache = allFiles;
    _lastScanTime = DateTime.now();

    return allFiles;
  }

  /// 强制刷新缓存（用户主动下拉刷新时调用）
  static void invalidateCache() {
    _cache = null;
    _lastScanTime = DateTime(2000);
  }

  // ============================================================
  // 搜索 & 排序
  // ============================================================

  static List<PdfFileInfo> searchFiles(
    List<PdfFileInfo> files,
    String query,
  ) {
    if (query.isEmpty) return files;
    final lowerQuery = query.toLowerCase();
    return files.where((f) {
      return f.name.toLowerCase().contains(lowerQuery) ||
          f.path.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  static void sortFiles(
    List<PdfFileInfo> files, {
    required SortBy sortBy,
    bool ascending = false,
  }) {
    switch (sortBy) {
      case SortBy.name:
        files.sort((a, b) => ascending
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name));
      case SortBy.size:
        files.sort((a, b) => ascending
            ? a.sizeInBytes.compareTo(b.sizeInBytes)
            : b.sizeInBytes.compareTo(a.sizeInBytes));
      case SortBy.date:
        files.sort((a, b) => ascending
            ? a.lastModified.compareTo(b.lastModified)
            : b.lastModified.compareTo(a.lastModified));
    }
  }
}

enum SortBy { name, size, date }

extension SortByLabel on SortBy {
  String get label {
    switch (this) {
      case SortBy.name:
        return '文件名';
      case SortBy.size:
        return '文件大小';
      case SortBy.date:
        return '修改时间';
    }
  }
}
