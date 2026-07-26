import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/reading_record_service.dart';
import '../../services/bookmark_service.dart';

/// PDF 阅读器控制逻辑（缩放、双击、书签、搜索、跳转）
///
/// 混入到 _PdfReaderPageState 中使用。
mixin ReaderControllerMixin<T extends StatefulWidget> on State<T> {
  // ── 需要主 State 提供的接口 ──
  PdfViewerController? get pdfViewerController;
  String get filePath;
  String get fileName;
  int get currentPage;
  int get totalPages;
  bool get isFullscreen;
  bool get isOriginalMode;

  // ── 缩放状态 ──
  double currentZoom = 1.0;
  double fitToWidthZoom = 1.0;
  double fitToPageZoom = 1.0;
  Size? pageSize;
  bool isZoomFitWidth = true; // true=fitToWidth, false=fitToPage

  // ── 双击检测 ──
  DateTime? lastTapTime;
  Offset? lastTapPosition;
  Timer? doubleTapTimer;
  static const Duration doubleTapTimeout = Duration(milliseconds: 300);
  static const double doubleTapDistance = 40.0;

  // ── 书签 ──
  bool isBookmarked = false;

  // ── 搜索 ──
  bool showSearchBar = false;
  bool searchInitialized = false;
  final TextEditingController searchController = TextEditingController();

  // ════════════════════════════
  // 缩放计算
  // ════════════════════════════

  /// 计算适配缩放比
  void calculateZoomLevels(Size size) {
    pageSize = size;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    fitToWidthZoom = screenW / size.width;
    final zoomH = screenW / size.width;
    final zoomV = screenH / size.height;
    fitToPageZoom = min(zoomH, zoomV) * 0.95;
    isZoomFitWidth = true;
  }

  /// 应用 Fit-to-Width
  void applyFitToWidth() {
    if (pdfViewerController == null || pageSize == null) return;
    pdfViewerController!.zoomLevel = fitToWidthZoom;
    setState(() {
      isZoomFitWidth = true;
      currentZoom = fitToWidthZoom;
    });
  }

  /// 应用 Fit-to-Page
  void applyFitToPage() {
    if (pdfViewerController == null || pageSize == null) return;
    pdfViewerController!.zoomLevel = fitToPageZoom;
    setState(() {
      isZoomFitWidth = false;
      currentZoom = fitToPageZoom;
    });
  }

  /// 双击缩放切换
  void toggleZoomFit() {
    if (isZoomFitWidth) {
      applyFitToPage();
    } else {
      applyFitToWidth();
    }
  }

  /// 缩放模式标签
  String zoomLabel() {
    final pct = '${(currentZoom * 100).toStringAsFixed(0)}%';
    if (isZoomFitWidth) return '适配宽度 $pct';
    return '适配页面 $pct';
  }

  // ════════════════════════════
  // 双击检测
  // ════════════════════════════

  void onPointerDown(PointerDownEvent event) {
    if (!isOriginalMode) return;
    final now = DateTime.now();
    final pos = event.position;
    if (lastTapTime != null &&
        now.difference(lastTapTime!) < doubleTapTimeout &&
        lastTapPosition != null &&
        (lastTapPosition! - pos).distance < doubleTapDistance) {
      doubleTapTimer?.cancel();
      doubleTapTimer = null;
      lastTapTime = null;
      lastTapPosition = null;
      toggleZoomFit();
      HapticFeedback.lightImpact();
      return;
    }
    lastTapTime = now;
    lastTapPosition = pos;
    doubleTapTimer?.cancel();
    doubleTapTimer = Timer(doubleTapTimeout, () {
      lastTapTime = null;
      lastTapPosition = null;
    });
  }

  // ════════════════════════════
  // Synfusion 回调
  // ════════════════════════════

  void onDocumentLoaded(int pageCount, Size pageSz) {
    calculateZoomLevels(pageSz);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyFitToWidth();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (pdfViewerController?.zoomLevel != fitToWidthZoom) {
          applyFitToWidth();
        }
      });
    });
  }

  void onZoomLevelChanged(double zoom) {
    setState(() {
      currentZoom = zoom;
      if (pageSize != null) {
        if ((zoom - fitToWidthZoom).abs() < 0.01) {
          isZoomFitWidth = true;
        } else if ((zoom - fitToPageZoom).abs() < 0.01) {
          isZoomFitWidth = false;
        }
      }
    });
  }

  // ════════════════════════════
  // 书签
  // ════════════════════════════

  Future<void> checkBookmark(int page) async {
    final has = await BookmarkService.hasBookmark(filePath, page);
    if (mounted) setState(() => isBookmarked = has);
  }

  Future<void> toggleBookmark(int page) async {
    if (isBookmarked) {
      await BookmarkService.removeBookmark(filePath, page);
    } else {
      await BookmarkService.addBookmark(Bookmark(
        filePath: filePath,
        page: page,
        note: '',
      ));
    }
    setState(() => isBookmarked = !isBookmarked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBookmarked ? '已添加书签 - 第 $page 页' : '已删除书签',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> showBookmarksList() async {
    final bookmarks = await BookmarkService.getBookmarks(filePath);
    if (!mounted) return;
    if (bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无书签'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('书签列表 (${bookmarks.length})', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ...bookmarks.map((b) => ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.bookmark, color: theme.colorScheme.primary, size: 18),
              ),
              title: Text('第 ${b.page} 页', style: theme.textTheme.bodyLarge),
              trailing: IconButton(
                icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 18),
                onPressed: () async {
                  await BookmarkService.removeBookmark(b.filePath, b.page);
                  Navigator.pop(ctx);
                  showBookmarksList();
                },
              ),
              onTap: () {
                Navigator.pop(ctx);
                pdfViewerController?.jumpToPage(b.page);
              },
            )),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════
  // 阅读记录
  // ════════════════════════════

  Future<void> restorePage() async {
    final record = await ReadingRecordService.loadRecord(filePath);
    if (record != null && record.page > 1 && pdfViewerController != null) {
      try { pdfViewerController!.jumpToPage(record.page); } catch (_) {}
    }
  }

  Future<void> saveRecord(int page, int total) async {
    await ReadingRecordService.saveRecord(ReadingRecord(
      filePath: filePath, page: page, totalPages: total,
    ));
  }

  // ════════════════════════════
  // 搜索
  // ════════════════════════════

  void performSearch() {
    final text = searchController.text.trim();
    if (text.isEmpty) {
      pdfViewerController?.searchText('');
      setState(() => searchInitialized = false);
      return;
    }
    pdfViewerController?.searchText(text);
    setState(() => searchInitialized = true);
  }

  void clearSearch() {
    searchController.clear();
    pdfViewerController?.searchText('');
    setState(() {
      searchInitialized = false;
      showSearchBar = false;
    });
  }

  // ════════════════════════════
  // 页面跳转
  // ════════════════════════════

  void showPageJumpDialog(int total) {
    final controller = TextEditingController(text: '$currentPage');
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('跳转到页面', style: TextStyle(
          color: theme.colorScheme.onSurface, fontSize: 18,
        )),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
          decoration: InputDecoration(
            hintText: '输入页码 (1-$total)',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            filled: true,
            fillColor: theme.colorScheme.onSurface.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            )),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= total) {
                pdfViewerController?.jumpToPage(page);
                Navigator.pop(ctx);
              }
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }
}
