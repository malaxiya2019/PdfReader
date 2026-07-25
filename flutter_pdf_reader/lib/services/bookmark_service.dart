import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Bookmark {
  final String filePath;
  final int page;
  final String note;
  final DateTime created;

  Bookmark({
    required this.filePath,
    required this.page,
    this.note = '',
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'page': page,
        'note': note,
        'created': created.toIso8601String(),
      };

  factory Bookmark.fromJson(String filePath, Map<String, dynamic> json) {
    return Bookmark(
      filePath: filePath,
      page: json['page'] as int? ?? 1,
      note: json['note'] as String? ?? '',
      created:
          DateTime.tryParse(json['created'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// 书签服务
///
/// 性能优化 (Phase 9):
/// - 内存缓存 + 防抖批量写入，避免频繁 SharedPreferences 读写
/// - 单文件书签快速查询不走全量反序列化
class BookmarkService {
  BookmarkService._();

  static const String _key = 'bookmarks';

  /// 内存缓存
  static Map<String, List<Bookmark>>? _cache;

  /// 脏标记
  static bool _dirty = false;

  /// 防抖 Timer ID
  static int _debounceTimerId = 0;

  /// 从磁盘加载到内存缓存
  static Future<Map<String, List<Bookmark>>> _ensureLoaded() async {
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
        final list = (data as List).map((e) {
          return Bookmark.fromJson(path, e as Map<String, dynamic>);
        }).toList();
        return MapEntry(path, list);
      });
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  /// 防抖批量写回
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
    final map = _cache!.map((path, list) {
      return MapEntry(path, list.map((b) => b.toJson()).toList());
    });
    await prefs.setString(_key, json.encode(map));
  }

  /// 强制立即写回
  static Future<void> flush() => _persistNow();

  /// 获取某个文件的所有书签
  static Future<List<Bookmark>> getBookmarks(String filePath) async {
    final all = await _ensureLoaded();
    return all[filePath] ?? [];
  }

  /// 获取所有书签（按文件分组）
  static Future<Map<String, List<Bookmark>>> getAllBookmarks() async {
    return _ensureLoaded();
  }

  /// 添加书签
  static Future<void> addBookmark(Bookmark bookmark) async {
    final all = await _ensureLoaded();
    final list = all[bookmark.filePath] ?? [];
    final exists = list.any((b) => b.page == bookmark.page);
    if (!exists) {
      list.add(bookmark);
      all[bookmark.filePath] = list;
      _schedulePersist();
    }
  }

  /// 删除书签
  static Future<void> removeBookmark(String filePath, int page) async {
    final all = await _ensureLoaded();
    final list = all[filePath] ?? [];
    list.removeWhere((b) => b.page == page);
    if (list.isEmpty) {
      all.remove(filePath);
    } else {
      all[filePath] = list;
    }
    _schedulePersist();
  }

  /// 判断某页是否有书签
  static Future<bool> hasBookmark(String filePath, int page) async {
    final all = await _ensureLoaded();
    final list = all[filePath] ?? [];
    return list.any((b) => b.page == page);
  }

  /// 获取某文件所有带页码的书签集合（快速判断用）
  static Future<Set<int>> getBookmarkPages(String filePath) async {
    final list = await getBookmarks(filePath);
    return list.map((b) => b.page).toSet();
  }
}
