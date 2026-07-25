import 'dart:io';
import 'dart:collection' show LinkedHashMap;
import 'package:path_provider/path_provider.dart';

/// 缩略图磁盘缓存服务
///
/// 性能优化 (Phase 9):
/// - LRU 淘汰策略：最久未访问的文件缩略图自动删除
/// - 最大缓存 50MB，超过时按 LRU 顺序淘汰
/// - 缩略图按 PDF 文件路径哈希存储
class ThumbnailCacheService {
  ThumbnailCacheService._();

  /// 缓存目录
  static Directory? _cacheDir;

  /// LRU 跟踪（key = 文件路径 → lastAccessTime）
  static final LinkedHashMap<String, int> _lruMap =
      LinkedHashMap<String, int>();

  /// 缓存元数据文件路径
  static String? _metaFilePath;

  /// 最大缓存字节数（50MB）
  static const int maxCacheBytes = 50 * 1024 * 1024;

  /// 已初始化的 Future（防止竞态）
  static Future<void>? _initFuture;

  // ============================================================
  // 初始化
  // ============================================================

  /// 初始化缓存目录（应用启动时调用一次）
  static Future<void> init() async {
    if (_initFuture != null) return _initFuture!;

    _initFuture = _doInit();
    return _initFuture;
  }

  static Future<void> _doInit() async {
    final appDir = await getTemporaryDirectory();
    _cacheDir = Directory('${appDir.path}/pdf_thumbnails');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    _metaFilePath = '${_cacheDir!.path}/.lru_meta';
    await _loadLruMeta();
  }

  /// 确保已初始化
  static Future<void> _ensureInit() async {
    if (_cacheDir == null) await init();
  }

  // ============================================================
  // LRU 元数据持久化
  // ============================================================

  /// 从磁盘加载 LRU 元数据
  static Future<void> _loadLruMeta() async {
    if (_metaFilePath == null) return;
    final file = File(_metaFilePath!);
    if (!await file.exists()) return;

    try {
      final lines = await file.readAsLines();
      _lruMap.clear();
      for (final line in lines) {
        final parts = line.split('\t');
        if (parts.length == 2) {
          _lruMap[parts[0]] = int.tryParse(parts[1]) ?? 0;
        }
      }
    } catch (_) {
      _lruMap.clear();
    }
  }

  /// 保存 LRU 元数据到磁盘
  static Future<void> _saveLruMeta() async {
    if (_metaFilePath == null) return;
    try {
      final buffer = StringBuffer();
      for (final entry in _lruMap.entries) {
        buffer.writeln('${entry.key}\t${entry.value}');
      }
      await File(_metaFilePath!).writeAsString(buffer.toString());
    } catch (_) {
      // metadata save failure is non-critical
    }
  }

  // ============================================================
  // 核心 API
  // ============================================================

  /// 获取缩略图缓存路径
  static String _thumbPath(String filePath) {
    final hash = filePath.hashCode.toRadixString(16).padLeft(8, '0');
    final name = '${hash}_thumb.png';
    return '${_cacheDir!.path}/$name';
  }

  /// 检查缓存是否存在
  static Future<bool> has(String filePath) async {
    await _ensureInit();
    final thumbFile = File(_thumbPath(filePath));
    return await thumbFile.exists();
  }

  /// 读取缓存缩略图路径（不存在返回 null）
  static Future<String?> get(String filePath) async {
    await _ensureInit();
    final thumbFile = File(_thumbPath(filePath));
    if (!await thumbFile.exists()) return null;

    // 更新 LRU 访问时间
    _lruMap[filePath] = DateTime.now().millisecondsSinceEpoch;
    _scheduleMetaSave();

    return thumbFile.path;
  }

  /// 写入缩略图缓存
  static Future<void> put(String filePath, List<int> pngBytes) async {
    await _ensureInit();
    final path = _thumbPath(filePath);
    await File(path).writeAsBytes(pngBytes);

    // 更新 LRU
    _lruMap[filePath] = DateTime.now().millisecondsSinceEpoch;
    _scheduleMetaSave();

    // 检查总大小并淘汰
    await _evictIfNeeded();
  }

  /// 删除单个文件缩略图
  static Future<void> remove(String filePath) async {
    await _ensureInit();
    final thumbFile = File(_thumbPath(filePath));
    if (await thumbFile.exists()) {
      await thumbFile.delete();
    }
    _lruMap.remove(filePath);
    _scheduleMetaSave();
  }

  /// 清除全部缓存
  static Future<void> clear() async {
    await _ensureInit();
    if (_cacheDir == null || !await _cacheDir!.exists()) return;

    final files = _cacheDir!.listSync();
    for (final f in files) {
      if (f is File) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    _lruMap.clear();
    _scheduleMetaSave();
  }

  /// 获取当前缓存大小（字节）
  static Future<int> getCacheSize() async {
    await _ensureInit();
    if (_cacheDir == null || !await _cacheDir!.exists()) return 0;

    int total = 0;
    await for (final entity in _cacheDir!.list()) {
      if (entity is File && entity.path != _metaFilePath) {
        total += await entity.length();
      }
    }
    return total;
  }

  // ============================================================
  // LRU 淘汰
  // ============================================================

  /// 防抖元数据保存
  static int _metaTimerId = 0;

  static void _scheduleMetaSave() {
    _metaTimerId++;
    final currentId = _metaTimerId;
    Future.delayed(const Duration(seconds: 2), () async {
      if (currentId == _metaTimerId) {
        await _saveLruMeta();
      }
    });
  }

  /// 检查总大小，超过限制时淘汰最久未使用的
  static Future<void> _evictIfNeeded() async {
    final size = await getCacheSize();
    if (size <= maxCacheBytes) return;

    // 按 LRU 顺序淘汰（最久未访问的排前面）
    final sorted = _lruMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    int freed = 0;
    final targetFree = size - (maxCacheBytes * 80 ~/ 100); // 释放到 80%

    for (final entry in sorted) {
      final thumbFile = File(_thumbPath(entry.key));
      if (await thumbFile.exists()) {
        freed += await thumbFile.length();
        await thumbFile.delete();
      }
      _lruMap.remove(entry.key);

      if (freed >= targetFree) break;
    }

    _scheduleMetaSave();
  }
}
