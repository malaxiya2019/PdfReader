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
      lastRead: DateTime.tryParse(json['lastRead'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ReadingRecordService {
  ReadingRecordService._();

  static const String _key = 'reading_records';

  /// 加载所有阅读记录
  static Future<Map<String, ReadingRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return map.map((path, data) {
        return MapEntry(path, ReadingRecord.fromJson(path, data as Map<String, dynamic>));
      });
    } catch (_) {
      return {};
    }
  }

  /// 保存阅读记录
  static Future<void> saveRecord(ReadingRecord record) async {
    final all = await loadAll();
    all[record.filePath] = record;
    await _persist(all);
  }

  /// 获取单文件记录
  static Future<ReadingRecord?> loadRecord(String filePath) async {
    final all = await loadAll();
    return all[filePath];
  }

  /// 获取最近阅读的文件列表（按时间排序）
  static Future<List<ReadingRecord>> getRecentRecords({int limit = 20}) async {
    final all = await loadAll();
    final list = all.values.toList();
    list.sort((a, b) => b.lastRead.compareTo(a.lastRead));
    return list.take(limit).toList();
  }

  static Future<void> _persist(Map<String, ReadingRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final map = records.map((path, record) => MapEntry(path, record.toJson()));
    await prefs.setString(_key, json.encode(map));
  }
}
