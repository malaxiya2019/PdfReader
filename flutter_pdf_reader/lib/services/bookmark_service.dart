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
      created: DateTime.tryParse(json['created'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class BookmarkService {
  BookmarkService._();

  static const String _key = 'bookmarks';

  /// 获取某个文件的所有书签
  static Future<List<Bookmark>> getBookmarks(String filePath) async {
    final all = await _loadAll();
    return all[filePath] ?? [];
  }

  /// 获取所有书签（按文件分组）
  static Future<Map<String, List<Bookmark>>> getAllBookmarks() async {
    return _loadAll();
  }

  /// 添加书签
  static Future<void> addBookmark(Bookmark bookmark) async {
    final all = await _loadAll();
    final list = all[bookmark.filePath] ?? [];
    // 检查是否已存在同页书签
    final exists = list.any((b) => b.page == bookmark.page);
    if (!exists) {
      list.add(bookmark);
      all[bookmark.filePath] = list;
      await _persist(all);
    }
  }

  /// 删除书签
  static Future<void> removeBookmark(String filePath, int page) async {
    final all = await _loadAll();
    final list = all[filePath] ?? [];
    list.removeWhere((b) => b.page == page);
    if (list.isEmpty) {
      all.remove(filePath);
    } else {
      all[filePath] = list;
    }
    await _persist(all);
  }

  /// 判断某页是否有书签
  static Future<bool> hasBookmark(String filePath, int page) async {
    final all = await _loadAll();
    final list = all[filePath] ?? [];
    return list.any((b) => b.page == page);
  }

  /// 获取所有文件的带页码书签集合（用于快速判断）
  static Future<Set<int>> getBookmarkPages(String filePath) async {
    final list = await getBookmarks(filePath);
    return list.map((b) => b.page).toSet();
  }

  static Future<Map<String, List<Bookmark>>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return map.map((path, data) {
        final list = (data as List).map((e) {
          return Bookmark.fromJson(path, e as Map<String, dynamic>);
        }).toList();
        return MapEntry(path, list);
      });
    } catch (_) {
      return {};
    }
  }

  static Future<void> _persist(Map<String, List<Bookmark>> all) async {
    final prefs = await SharedPreferences.getInstance();
    final map = all.map((path, list) {
      return MapEntry(path, list.map((b) => b.toJson()).toList());
    });
    await prefs.setString(_key, json.encode(map));
  }
}
