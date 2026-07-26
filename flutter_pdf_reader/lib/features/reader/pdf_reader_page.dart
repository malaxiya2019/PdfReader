import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../services/reading_record_service.dart';
import '../../services/bookmark_service.dart';
import 'ai_assistant_page.dart';

/// 阅读视图模式
enum PdfViewMode {
  /// 原始 PDF 页面（Bitmap 渲染）
  original,

  /// 文本重排流式视图
  reflow,
}

/// 缩放适配模式
enum ZoomFitMode {
  /// 适配宽度 — 页面宽度填满屏幕，无水平滚动
  fitToWidth,

  /// 适配页面 — 整页完整可见（保留适当边距）
  fitToPage,

  /// 自由缩放 — 用户手动缩放
  free,
}

class PdfReaderPage extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfReaderPage({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfViewerController;

  // ── 阅读状态 ──
  bool _isFullscreen = false;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isBookmarked = false;
  bool _showSearchBar = false;
  bool _searchInitialized = false;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _controlsController;
  late Animation<double> _controlsAnimation;

  // ── 视图模式 ──
  PdfViewMode _viewMode = PdfViewMode.original;

  // ── 缩放状态 ──
  ZoomFitMode _zoomFitMode = ZoomFitMode.fitToWidth;
  double _currentZoom = 1.0;
  double _fitToWidthZoom = 1.0;
  double _fitToPageZoom = 1.0;
  Size? _pageSize; // PDF 页面原始尺寸（pt）

  // ── 双击检测（Listener 原始事件，不参与手势竞技场） ──
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  Timer? _doubleTapTimer;
  static const Duration _doubleTapTimeout = Duration(milliseconds: 300);
  static const double _doubleTapDistance = 40.0;

  // ── Reflow 文本重排 ──
  bool _reflowReady = false;
  String _reflowText = '';
  double _reflowFontSize = 18.0;
  ScrollController? _reflowScrollController;

  // ── Reflow 性能优化：字节缓存 + 页面文本缓存 ──
  Uint8List? _pdfFileBytes;
  final Map<int, String> _pageTextCache = {};
  bool _pdfBytesLoading = false;
  Completer<void>? _pdfBytesCompleter;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _controlsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsController,
      curve: Curves.easeInOut,
    );
    _controlsController.value = 1.0;
    _reflowScrollController = ScrollController();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _searchController.dispose();
    _controlsController.dispose();
    _pdfViewerController?.dispose();
    _reflowScrollController?.dispose();
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════
  // 缩放计算
  // ════════════════════════════════════════════

  /// 根据 PDF 页面尺寸计算适配缩放比
  void _calculateZoomLevels(Size pageSize) {
    _pageSize = pageSize;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // 适配宽度：页面宽度 = 屏幕宽度
    _fitToWidthZoom = screenW / pageSize.width;

    // 适配页面：整页完整可见（留有 5% 边距）
    final zoomH = screenW / pageSize.width;
    final zoomV = screenH / pageSize.height;
    _fitToPageZoom = min(zoomH, zoomV) * 0.95;

    // 默认使用 fit-to-width
    _zoomFitMode = ZoomFitMode.fitToWidth;
  }

  /// 应用 Fit-to-Width（页面宽度适配屏幕）
  void _applyFitToWidth() {
    if (_pdfViewerController == null || _pageSize == null) return;
    _pdfViewerController!.zoomLevel = _fitToWidthZoom;
    setState(() {
      _zoomFitMode = ZoomFitMode.fitToWidth;
      _currentZoom = _fitToWidthZoom;
    });
  }

  /// 应用 Fit-to-Page（整页完整可见）
  void _applyFitToPage() {
    if (_pdfViewerController == null || _pageSize == null) return;
    _pdfViewerController!.zoomLevel = _fitToPageZoom;
    setState(() {
      _zoomFitMode = ZoomFitMode.fitToPage;
      _currentZoom = _fitToPageZoom;
    });
  }

  /// 双击缩放切换：Fit-to-Width ↔ Fit-to-Page
  void _toggleZoomFit() {
    if (_zoomFitMode == ZoomFitMode.fitToWidth) {
      _applyFitToPage();
    } else {
      _applyFitToWidth();
    }
  }

  // ════════════════════════════════════════════
  // 双击检测（通过 Listener 原始指针事件，零手势冲突）
  // ════════════════════════════════════════════

  void _onPointerDown(PointerDownEvent event) {
    // 只在原始视图模式下响应双击
    if (_viewMode != PdfViewMode.original) return;

    final now = DateTime.now();
    final pos = event.position;

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapTimeout &&
        _lastTapPosition != null &&
        (_lastTapPosition! - pos).distance < _doubleTapDistance) {
      // ✅ 检测到双击
      _doubleTapTimer?.cancel();
      _doubleTapTimer = null;
      _lastTapTime = null;
      _lastTapPosition = null;

      _toggleZoomFit();
      HapticFeedback.lightImpact();
      return;
    }

    _lastTapTime = now;
    _lastTapPosition = pos;

    // 超时重置，防止误触
    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(_doubleTapTimeout, () {
      _lastTapTime = null;
      _lastTapPosition = null;
    });
  }

  // ════════════════════════════════════════════
  // Reflow 文本重排
  // ════════════════════════════════════════════

  /// 切换视图模式
  void _toggleViewMode() async {
    if (_viewMode == PdfViewMode.original) {
      setState(() {
        _viewMode = PdfViewMode.reflow;
        _reflowReady = false;
        _reflowText = '';
      });
      await _cachePdfBytes();
      await _extractCurrentPageText();
    } else {
      setState(() => _viewMode = PdfViewMode.original);
    }
  }

  /// 缓存 PDF 文件字节（避免反复读磁盘）
  Future<void> _cachePdfBytes() async {
    if (_pdfFileBytes != null) return;
    if (_pdfBytesLoading) {
      await _pdfBytesCompleter?.future;
      return;
    }

    _pdfBytesLoading = true;
    _pdfBytesCompleter = Completer<void>();
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        _pdfFileBytes = await file.readAsBytes();
      }
    } catch (_) {
      // 读取失败，后续会单独处理
    }
    _pdfBytesLoading = false;
    _pdfBytesCompleter?.complete();
  }

  /// 提取当前页文本（带缓存）
  Future<void> _extractCurrentPageText() async {
    // 先查缓存
    if (_pageTextCache.containsKey(_currentPage)) {
      setState(() {
        _reflowText = _pageTextCache[_currentPage]!;
        _reflowReady = true;
      });
      _scrollReflowToTop();
      return;
    }

    final bytes = _pdfFileBytes;
    if (bytes == null) {
      // 回退：直接读文件
      try {
        final file = File(widget.filePath);
        if (!await file.exists()) {
          setState(() {
            _reflowText = '（文件不存在）';
            _reflowReady = true;
          });
          return;
        }
        final fileBytes = await file.readAsBytes();
        _pdfFileBytes = fileBytes;
        await _extractFromBytes(fileBytes);
      } catch (e) {
        setState(() {
          _reflowText = '文本提取失败: $e';
          _reflowReady = true;
        });
      }
    } else {
      await _extractFromBytes(bytes);
    }
  }

  /// 从字节数据中提取文本
  Future<void> _extractFromBytes(Uint8List bytes) async {
    try {
      final doc = PdfDocument(inputBytes: bytes);
      final pageIndex = (_currentPage - 1).clamp(0, doc.pages.count - 1);

      final extractor = PdfTextExtractor(doc);
      final pageText = extractor.extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      doc.dispose();

      final text = pageText.trim();
      if (text.isEmpty) {
        _pageTextCache[_currentPage] = '（此页无可提取的文本，可能是扫描件或图片型 PDF）';
      } else {
        _pageTextCache[_currentPage] = text;
      }

      setState(() {
        _reflowText = _pageTextCache[_currentPage]!;
        _reflowReady = true;
      });
      _scrollReflowToTop();
    } catch (e) {
      setState(() {
        _reflowText = '文本提取失败: $e';
        _reflowReady = true;
      });
    }
  }

  /// 预提取相邻页文本
  Future<void> _prefetchNeighborPages(int currentPage) async {
    final bytes = _pdfFileBytes;
    if (bytes == null) return;

    final pagesToPrefetch = [
      currentPage + 1, // 下一页
      currentPage + 2, // 下下页
    ];

    for (final page in pagesToPrefetch) {
      if (page < 1 || page > _totalPages) continue;
      if (_pageTextCache.containsKey(page)) continue;

      try {
        final doc = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(doc);
        final text = extractor.extractText(
          startPageIndex: page - 1,
          endPageIndex: page - 1,
        );
        doc.dispose();
        final trimmed = text.trim();
        _pageTextCache[page] =
            trimmed.isEmpty ? '（无可提取文本）' : trimmed;
      } catch (_) {
        // 预提取失败不阻塞 UI
      }
    }
  }

  void _scrollReflowToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reflowScrollController?.hasClients ?? false) {
        _reflowScrollController!.animateTo(
          0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ════════════════════════════════════════════
  // Syncfusion 回调
  // ════════════════════════════════════════════

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    final pdfDoc = details.document;

    // 获取页面尺寸（PDF points）
    final pageSize = pdfDoc.pages[0].size;

    setState(() {
      _totalPages = pdfDoc.pages.count;
      _isLoading = false;
    });

    // 计算缩放比
    _calculateZoomLevels(pageSize);

    // 延迟一帧应用 fit-to-width，确保渲染器就绪
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFitToWidth();

      // 再延迟 100ms 确认一次（部分设备需要）
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_pdfViewerController?.zoomLevel != _fitToWidthZoom) {
          _applyFitToWidth();
        }
      });
    });

    _restorePage();
    _checkBookmark();
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final newPage = details.newPageNumber;
    setState(() => _currentPage = newPage);
    _saveRecord();
    _checkBookmark();

    // Reflow 模式：提取当前页文本 + 预提取相邻页
    if (_viewMode == PdfViewMode.reflow) {
      _extractCurrentPageText();
      _prefetchNeighborPages(newPage);
    }
  }

  void _onZoomLevelChanged(PdfZoomDetails details) {
    final zoom = details.newZoomLevel;
    setState(() {
      _currentZoom = zoom;
      // 判断当前缩放模式
      if (_pageSize != null) {

        if ((zoom - _fitToWidthZoom).abs() < 0.01) {
          _zoomFitMode = ZoomFitMode.fitToWidth;
        } else if ((zoom - _fitToPageZoom).abs() < 0.01) {
          _zoomFitMode = ZoomFitMode.fitToPage;
        } else {
          _zoomFitMode = ZoomFitMode.free;
        }
      }
    });
  }

  // ════════════════════════════════════════════
  // 控制栏
  // ════════════════════════════════════════════

  void _toggleControls() {
    if (_showControls) {
      _controlsController.reverse();
    } else {
      _controlsController.forward();
    }
    setState(() => _showControls = !_showControls);
  }

  void _toggleFullscreen() {
    final goingFullscreen = !_isFullscreen;
    setState(() => _isFullscreen = goingFullscreen);
    if (goingFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _controlsController.forward();
    }
  }

  // ════════════════════════════════════════════
  // 书签 / 记录 / 搜索
  // ════════════════════════════════════════════

  Future<void> _restorePage() async {
    final record = await ReadingRecordService.loadRecord(widget.filePath);
    if (record != null && record.page > 1 && _pdfViewerController != null) {
      try {
        _pdfViewerController!.jumpToPage(record.page);
      } catch (_) {}
    }
  }

  Future<void> _saveRecord() async {
    await ReadingRecordService.saveRecord(ReadingRecord(
      filePath: widget.filePath,
      page: _currentPage,
      totalPages: _totalPages,
    ));
  }

  Future<void> _checkBookmark() async {
    final has = await BookmarkService.hasBookmark(widget.filePath, _currentPage);
    if (mounted) setState(() => _isBookmarked = has);
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await BookmarkService.removeBookmark(widget.filePath, _currentPage);
    } else {
      await BookmarkService.addBookmark(Bookmark(
        filePath: widget.filePath,
        page: _currentPage,
        note: '',
      ));
    }
    setState(() => _isBookmarked = !_isBookmarked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBookmarked ? '已添加书签 - 第 $_currentPage 页' : '已删除书签',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _performSearch() {
    final text = _searchController.text.trim();
    if (text.isEmpty) {
      _pdfViewerController?.searchText('');
      setState(() => _searchInitialized = false);
      return;
    }
    _pdfViewerController?.searchText(text);
    setState(() => _searchInitialized = true);
  }

  void _clearSearch() {
    _searchController.clear();
    _pdfViewerController?.searchText('');
    setState(() {
      _searchInitialized = false;
      _showSearchBar = false;
    });
  }

  void _showBookmarksList() async {
    final bookmarks = await BookmarkService.getBookmarks(widget.filePath);
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
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '书签列表 (${bookmarks.length})',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...bookmarks.map((b) => ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${b.page}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      '第 ${b.page} 页',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      _formatTime(b.created),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        size: 20,
                      ),
                      onPressed: () async {
                        await BookmarkService.removeBookmark(
                            widget.filePath, b.page);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _checkBookmark();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已删除第 ${b.page} 页书签'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                    onTap: () {
                      _pdfViewerController?.jumpToPage(b.page);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openAIAssistant() async {
    String pdfText = "";
    try {
      final bytes = _pdfFileBytes;
      if (bytes != null) {
        final doc = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(doc);
        final totalPages = doc.pages.count;
        final endPage = totalPages > 20 ? 20 : totalPages;
        pdfText = extractor.extractText(
          startPageIndex: 0,
          endPageIndex: endPage - 1,
        );
        doc.dispose();
        if (pdfText.length > 8000) {
          pdfText = pdfText.substring(0, 8000);
        }
      } else {
        final File file = File(widget.filePath);
        if (await file.exists()) {
          final fileBytes = await file.readAsBytes();
          _pdfFileBytes = fileBytes;
          final doc = PdfDocument(inputBytes: fileBytes);
          final extractor = PdfTextExtractor(doc);
          final totalPages = doc.pages.count;
          final endPage = totalPages > 20 ? 20 : totalPages;
          pdfText = extractor.extractText(
            startPageIndex: 0,
            endPageIndex: endPage - 1,
          );
          doc.dispose();
          if (pdfText.length > 8000) {
            pdfText = pdfText.substring(0, 8000);
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIAssistantPage(
          pdfName: widget.fileName,
          pdfText: pdfText,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // 页面跳转
  // ════════════════════════════════════════════

  void _showPageJumpDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          '跳转到页面',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '输入页码 (1-$_totalPages)',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style:
                  TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                _pdfViewerController?.jumpToPage(page);
                Navigator.pop(ctx);
              }
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // UI 构建
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // ── PDF 内容区域 ──
          if (_viewMode == PdfViewMode.original)
            _buildPdfViewer()
          else
            _buildReflowView(theme),

          // ── 加载指示器 ──
          if (_isLoading) _buildLoadingIndicator(theme),

          // ── 顶部栏 ──
          if (_isFullscreen)
            FadeTransition(
              opacity: _controlsAnimation,
              child: _buildFullscreenTopBar(theme),
            )
          else
            FadeTransition(
              opacity: _controlsAnimation,
              child: _buildTopBar(theme),
            ),

          // ── 搜索栏 ──
          if (_showSearchBar) _buildSearchBar(theme),

          // ── 底部栏 ──
          if (_isFullscreen)
            FadeTransition(
              opacity: _controlsAnimation,
              child: _buildFullscreenBottomBar(theme),
            )
          else
            FadeTransition(
              opacity: _controlsAnimation,
              child: _buildBottomBar(theme),
            ),

          // ── 页码指示器 ──
          if (!_showControls && !_isFullscreen)
            _buildPageIndicator(theme),

          // ── Reflow 字体调节面板 ──
          if (_viewMode == PdfViewMode.reflow) _buildReflowFontPanel(theme),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // PDF 原始视图（关键修复：Listener 替代 GestureDetector）
  // ════════════════════════════════════════════

  Widget _buildPdfViewer() {
    // 使用 Listener 捕获原始指针事件 → 零手势竞技场冲突
    // SfPdfViewer 内部的所有手势（缩放、拖动）正常工作
    return Listener(
      onPointerDown: _onPointerDown,
      child: SfPdfViewer.file(
        File(widget.filePath),
        key: _pdfViewerKey,
        controller: _pdfViewerController!,
        onDocumentLoaded: _onDocumentLoaded,
        onPageChanged: _onPageChanged,
        onZoomLevelChanged: _onZoomLevelChanged,
        onTap: (_) => _toggleControls(),
        pageLayoutMode: PdfPageLayoutMode.continuous,

      ),
    );
  }

  // ════════════════════════════════════════════
  // Reflow 文本重排视图
  // ════════════════════════════════════════════

  Widget _buildReflowView(ThemeData theme) {
    if (!_reflowReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '正在提取文本...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        controller: _reflowScrollController,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: kToolbarHeight +
              MediaQuery.of(context).padding.top +
              80,
          bottom: kToolbarHeight + 80,
        ),
        child: SelectableText(
          _reflowText,
          style: TextStyle(
            fontSize: _reflowFontSize,
            color: theme.colorScheme.onSurface,
            height: 1.7,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildReflowFontPanel(ThemeData theme) {
    return Positioned(
      bottom: kToolbarHeight + 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.text_decrease, size: 20),
                color: theme.colorScheme.primary,
                onPressed: () {
                  setState(() {
                    _reflowFontSize = (_reflowFontSize - 2).clamp(12.0, 36.0);
                  });
                },
              ),
              Text(
                '${_reflowFontSize.round()}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.text_increase, size: 20),
                color: theme.colorScheme.primary,
                onPressed: () {
                  setState(() {
                    _reflowFontSize = (_reflowFontSize + 2).clamp(12.0, 36.0);
                  });
                },
              ),
              const SizedBox(width: 4),
              Container(
                width: 1,
                height: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                onPressed: () {
                  _pageTextCache.remove(_currentPage);
                  _extractCurrentPageText();
                },
                tooltip: '重新提取文本',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // 加载指示器
  // ════════════════════════════════════════════

  Widget _buildLoadingIndicator(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '加载中...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // 顶部栏
  // ════════════════════════════════════════════

  Widget _buildTopBar(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: theme.cardColor.withValues(alpha: _isFullscreen ? 0.95 : 0.97),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: theme.colorScheme.onSurface,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 视图模式切换
                  if (_viewMode == PdfViewMode.original)
                    IconButton(
                      icon: const Icon(Icons.text_fields),
                      color: theme.colorScheme.primary,
                      onPressed: _toggleViewMode,
                      tooltip: '文本重排',
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf),
                      color: theme.colorScheme.primary,
                      onPressed: _toggleViewMode,
                      tooltip: '原始视图',
                    ),
                  // Fit-to-Width / Fit-to-Page 切换
                  if (_viewMode == PdfViewMode.original)
                    IconButton(
                      icon: const Icon(Icons.fit_screen),
                      color: _zoomFitMode == ZoomFitMode.fitToWidth
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      onPressed: _toggleZoomFit,
                      tooltip: _zoomFitMode == ZoomFitMode.fitToWidth
                          ? '适配页面'
                          : '适配宽度',
                    ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    onPressed: () =>
                        setState(() => _showSearchBar = !_showSearchBar),
                    tooltip: '搜索',
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_outline),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    onPressed: _showBookmarksList,
                    tooltip: '书签列表',
                  ),
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        key: ValueKey('bookmark_$_isBookmarked'),
                        color: _isBookmarked ? Colors.amber : null,
                      ),
                    ),
                    onPressed: _toggleBookmark,
                    tooltip: _isBookmarked ? '删除书签' : '添加书签',
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    onPressed: _openAIAssistant,
                    tooltip: 'AI 助手',
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    onPressed: _toggleFullscreen,
                    tooltip: '全屏',
                  ),
                ],
              ),
              // 缩放百分比指示器
              if (_viewMode == PdfViewMode.original)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _zoomFitMode == ZoomFitMode.fitToWidth
                            ? Icons.arrow_left
                            : _zoomFitMode == ZoomFitMode.fitToPage
                                ? Icons.fullscreen
                                : Icons.touch_app,
                        size: 12,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _zoomLabel(),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 缩放模式标签
  String _zoomLabel() {
    final pct = '${(_currentZoom * 100).toStringAsFixed(0)}%';
    switch (_zoomFitMode) {
      case ZoomFitMode.fitToWidth:
        return '适配宽度 $pct';
      case ZoomFitMode.fitToPage:
        return '适配页面 $pct';
      case ZoomFitMode.free:
        return '$pct';
    }
  }

  Widget _buildFullscreenTopBar(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black87,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          bottom: 8,
          left: 8,
          right: 8,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.fileName,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_viewMode == PdfViewMode.original)
              IconButton(
                icon: const Icon(Icons.text_fields, color: Colors.white70),
                onPressed: _toggleViewMode,
                tooltip: '文本重排',
              )
            else
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white70),
                onPressed: _toggleViewMode,
                tooltip: '原始视图',
              ),
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey('fs_bookmark_$_isBookmarked'),
                  color: _isBookmarked ? Colors.amber : Colors.white70,
                ),
              ),
              onPressed: _toggleBookmark,
              tooltip: _isBookmarked ? '删除书签' : '添加书签',
            ),
            IconButton(
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              onPressed: _toggleFullscreen,
              tooltip: '退出全屏',
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // 底部栏
  // ════════════════════════════════════════════

  Widget _buildBottomBar(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: theme.cardColor.withValues(alpha: 0.97),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // 缩小
                if (_viewMode == PdfViewMode.original)
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    onPressed: () {
                      final z = _currentZoom - 0.25;
                      _pdfViewerController?.zoomLevel = z.clamp(0.5, 5.0);
                    },
                    tooltip: '缩小',
                  ),
                // 快速适配按钮
                if (_viewMode == PdfViewMode.original)
                  IconButton(
                    icon: const Icon(Icons.fit_screen),
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    onPressed: _toggleZoomFit,
                    tooltip: '适配屏幕',
                    iconSize: 20,
                  ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: theme.colorScheme.onSurface,
                  onPressed: _currentPage > 1
                      ? () => _pdfViewerController?.previousPage()
                      : null,
                ),
                GestureDetector(
                  onTap: _showPageJumpDialog,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_stories,
                            size: 14,
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          '$_currentPage / $_totalPages',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: theme.colorScheme.onSurface,
                  onPressed: _currentPage < _totalPages
                      ? () => _pdfViewerController?.nextPage()
                      : null,
                ),
                // 放大
                if (_viewMode == PdfViewMode.original)
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    onPressed: () {
                      final z = _currentZoom + 0.25;
                      _pdfViewerController?.zoomLevel = z.clamp(0.5, 5.0);
                    },
                    tooltip: '放大',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenBottomBar(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black87,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 8,
          left: 16,
          right: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_out, color: Colors.white70),
              onPressed: () {
                final z = _currentZoom - 0.25;
                _pdfViewerController?.zoomLevel = z.clamp(0.5, 5.0);
              },
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen, color: Colors.white70),
              onPressed: _toggleZoomFit,
              tooltip: '适配屏幕',
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: _currentPage > 1
                  ? () => _pdfViewerController?.previousPage()
                  : null,
            ),
            GestureDetector(
              onTap: _showPageJumpDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: _currentPage < _totalPages
                  ? () => _pdfViewerController?.nextPage()
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, color: Colors.white70),
              onPressed: () {
                final z = _currentZoom + 0.25;
                _pdfViewerController?.zoomLevel = z.clamp(0.5, 5.0);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(ThemeData theme) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: GestureDetector(
        onTap: _showPageJumpDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // 搜索栏
  // ════════════════════════════════════════════

  Widget _buildSearchBar(ThemeData theme) {
    return Positioned(
      top: _isFullscreen
          ? (MediaQuery.of(context).padding.top + 56)
          : 0,
      left: 0,
      right: 0,
      child: Material(
        color: theme.cardColor,
        elevation: 4,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Padding(
            padding: EdgeInsets.only(
              top: _isFullscreen ? 0 : MediaQuery.of(context).padding.top + 4,
              left: 12,
              right: 12,
              bottom: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索 PDF 内容...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              onPressed: _clearSearch,
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _performSearch(),
                    onChanged: (_) {
                      setState(() {});
                      _performSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (_searchInitialized)
                  Text(
                    '使用搜索面板导航',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  onPressed: _clearSearch,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
