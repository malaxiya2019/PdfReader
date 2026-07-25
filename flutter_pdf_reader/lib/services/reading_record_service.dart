import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 单文件阅读记录
class ReadingRecord {
  final String filePath;
  int page;
  int totalPages;
  final DateTime lastRead;

  ReadingRecord({
    required this.filePath,
    this.page = 1,
    this.totalPages = 0,
    DateTime? lastRead,
  }) : lastRead = lastRead ?? DateTime.now();

  double get progress => totalPages > 0 ? page / totalPages : 0;

  Map<String, dynamic> toJson() => {
        'page': page,
        'totalPages': totalPages,
        'lastRead': lastRead.toIso8601String(),
      };

  factory ReadingRecord.fromJson(String path, Map<String, dynamic> json) {
    return ReadingRecord(
      filePath: path,
      page: json['page'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 0,
      lastRead:
          DateTime.tryParse(json['lastRead'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// 阅读记录服务
///
/// 性能优化 (Phase 9):
/// - 内存缓存：首次加载后驻留内存，后续操作不读 SharedPreferences
/// - 批量写入防抖：连续保存只写一次磁盘
class ReadingRecordService {
  ReadingRecordService._();

  static const String _key = 'reading_records';

  /// 内存缓存（避免重复反序列化）
  static Map<String, ReadingRecord>? _cache;

  /// 脏标记：有未写回磁盘的修改
  static bool _dirty = false;

  /// 防抖 Timer
  static int _debounceTimerId = 0;

  /// 读取内存缓存，未加载时从磁盘加载
  static Future<Map<String, ReadingRecord>> _ensureLoaded() async {
    if (_cache != null) return _cache!;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _cache = {};
      return _cache!;
    }

    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      _cache = map.map((path, data) {
        return MapEntry(
            path, ReadingRecord.fromJson(path, data as Map<String, dynamic>));
      });
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  /// 异步防抖批量写回磁盘
  static void _schedulePersist() {
    _dirty = true;
    _debounceTimerId++;
    final currentId = _debounceTimerId;
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (_dirty && currentId == _debounceTimerId) {
        await _persistNow();
      }
    });
  }

  static Future<void> _persistNow() async {
    if (_cache == null) return;
    _dirty = false;
    final prefs = await SharedPreferences.getInstance();
    final map =
        _cache!.map((path, record) => MapEntry(path, record.toJson()));
    await prefs.setString(_key, json.encode(map));
  }

  /// 强制立即写回（程序退出时调用）
  static Future<void> flush() => _persistNow();

  /// 加载所有阅读记录
  static Future<Map<String, ReadingRecord>> loadAll() => _ensureLoaded();

  /// 保存阅读记录
  static Future<void> saveRecord(ReadingRecord record) async {
    final all = await _ensureLoaded();
    all[record.filePath] = record;
    _schedulePersist();
  }

  /// 获取单文件记录
  static Future<ReadingRecord?> loadRecord(String filePath) async {
    final all = await _ensureLoaded();
    return all[filePath];
  }

  /// 获取最近阅读的文件列表（按时间排序）
  static Future<List<ReadingRecord>> getRecentRecords({int limit = 20}) async {
    final all = await _ensureLoaded();
    final list = all.values.toList();
    list.sort((a, b) => b.lastRead.compareTo(a.lastRead));
    return list.take(limit).toList();
  }
}
