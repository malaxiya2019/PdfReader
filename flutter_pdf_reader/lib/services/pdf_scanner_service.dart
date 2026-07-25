import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_file_info.dart';

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

  /// 收藏文件路径集合
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

  /// 扫描指定目录中的 PDF 文件
  static Future<List<PdfFileInfo>> scanDirectory(String dirPath) async {
    final files = <PdfFileInfo>[];
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return files;

      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          try {
            final stat = entity.statSync();
            files.add(PdfFileInfo(
              path: entity.path,
              name: entity.uri.pathSegments.last,
              sizeInBytes: stat.size,
              lastModified: stat.modified,
            ));
          } catch (_) {
            // skip files that can't be read
          }
        }
      }
    } catch (_) {
      // permission denied or directory not accessible
    }
    return files;
  }

  /// 扫描多个常见目录，返回去重后的 PDF 列表
  static Future<List<PdfFileInfo>> scanAllCommonDirectories() async {
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

    // 按修改时间降序排序（最新的在前）
    allFiles.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return allFiles;
  }

  /// 搜索文件
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

  /// 按条件排序
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
        break;
      case SortBy.size:
        files.sort((a, b) => ascending
            ? a.sizeInBytes.compareTo(b.sizeInBytes)
            : b.sizeInBytes.compareTo(a.sizeInBytes));
        break;
      case SortBy.date:
        files.sort((a, b) => ascending
            ? a.lastModified.compareTo(b.lastModified)
            : b.lastModified.compareTo(a.lastModified));
        break;
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
