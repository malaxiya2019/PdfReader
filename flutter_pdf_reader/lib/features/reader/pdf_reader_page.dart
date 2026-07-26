import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'reader_reflow.dart';
import 'reader_controller.dart';
import 'ai_assistant_page.dart';

/// 阅读视图模式
enum PdfViewMode {
  original,
  reflow,
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
    with SingleTickerProviderStateMixin, ReflowMixin, ReaderControllerMixin {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfViewerController;

  // ── 阅读状态 ──
  bool _isFullscreen = false;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  bool _showControls = true;
  late AnimationController _controlsController;
  late Animation<double> _controlsAnimation;

  // ── 视图模式 ──
  PdfViewMode _viewMode = PdfViewMode.original;

  @override
  PdfViewerController? get pdfViewerController => _pdfViewerController;
  @override
  String get filePath => widget.filePath;
  @override
  String get fileName => widget.fileName;
  @override
  int get currentPage => _currentPage;
  @override
  int get totalPages => _totalPages;
  @override
  bool get isFullscreen => _isFullscreen;
  @override
  bool get isOriginalMode => _viewMode == PdfViewMode.original;

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
    reflowScrollController = ScrollController();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    searchController.dispose();
    _controlsController.dispose();
    _pdfViewerController?.dispose();
    reflowScrollController?.dispose();
    doubleTapTimer?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════
  // Syncfusion 回调
  // ════════════════════════════════════════════

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    final pdfDoc = details.document;
    final pageSize = pdfDoc.pages[0].size;
    setState(() {
      _totalPages = pdfDoc.pages.count;
      _isLoading = false;
    });
    onDocumentLoaded(pdfDoc.pages.count, pageSize);
    restorePage();
    checkBookmark(_currentPage);
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final newPage = details.newPageNumber;
    setState(() => _currentPage = newPage);
    saveRecord(newPage, _totalPages);
    checkBookmark(newPage);
    if (_viewMode == PdfViewMode.reflow) {
      extractCurrentPageText();
      prefetchNeighborPages(newPage);
    }
  }

  void _onZoomLevelChanged(PdfZoomDetails details) {
    onZoomLevelChanged(details.newZoomLevel);
  }

  // ════════════════════════════════════════════
  // 视图模式切换
  // ════════════════════════════════════════════

  void _toggleViewMode() async {
    if (_viewMode == PdfViewMode.original) {
      setState(() {
        _viewMode = PdfViewMode.reflow;
        reflowReady = false;
        reflowText = '';
      });
      await toggleReflowView();
    } else {
      setState(() => _viewMode = PdfViewMode.original);
    }
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
  // AI 助手
  // ════════════════════════════════════════════

  Future<void> _openAIAssistant() async {
    String pdfText = '';
    try {
      final bytes = pdfFileBytes;
      if (bytes != null) {
        final doc = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(doc);
        final total = doc.pages.count;
        final endPage = total > 20 ? 20 : total;
        pdfText = extractor.extractText(startPageIndex: 0, endPageIndex: endPage - 1);
        doc.dispose();
        if (pdfText.length > 8000) pdfText = pdfText.substring(0, 8000);
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
  // UI 构建
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_viewMode == PdfViewMode.original)
            _buildPdfViewer()
          else
            _buildReflowView(theme),
          if (_isLoading) _buildLoadingIndicator(theme),
          if (_showControls) ...[
            _isFullscreen ? _buildFullscreenTopBar(theme) : _buildTopBar(theme),
            _isFullscreen ? _buildFullscreenBottomBar(theme) : _buildBottomBar(theme),
          ],
          if (showSearchBar) _buildSearchBar(theme),
          if (!_showControls && !_isFullscreen)
            _buildPageIndicator(theme),
          if (_viewMode == PdfViewMode.reflow) _buildReflowFontPanel(theme),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // PDF 原始视图
  // ════════════════════════════════════════════

  Widget _buildPdfViewer() {
    return Listener(
      onPointerDown: onPointerDown,
      child: SfPdfViewer.file(
        File(widget.filePath),
        key: _pdfViewerKey,
        controller: _pdfViewerController!,
        onDocumentLoaded: _onDocumentLoaded,
        onPageChanged: _onPageChanged,
        onZoomLevelChanged: _onZoomLevelChanged,
        onTap: (_) => _toggleControls(),
      ),
    );
  }

  // ════════════════════════════════════════════
  // Reflow 文本重排视图
  // ════════════════════════════════════════════

  Widget _buildReflowView(ThemeData theme) {
    if (!reflowReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('正在提取文本...', style: TextStyle(color: theme.colorScheme.onSurface)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _toggleControls,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: kToolbarHeight + MediaQuery.of(context).padding.top + 80,
          bottom: kToolbarHeight + 80,
        ),
        child: SelectableText(
          reflowText,
          style: TextStyle(
            fontSize: reflowFontSize,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.text_fields, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                onPressed: () {
                  setState(() => reflowFontSize = (reflowFontSize - 2).clamp(12.0, 32.0));
                },
              ),
              Text(
                '${reflowFontSize.toInt()}',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                onPressed: () {
                  setState(() => reflowFontSize = (reflowFontSize + 2).clamp(12.0, 32.0));
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                onPressed: () {
                  pageTextCache.remove(_currentPage);
                  extractCurrentPageText();
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
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('正在加载 PDF...', style: TextStyle(color: theme.colorScheme.onSurface)),
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
        color: theme.cardColor.withOpacity(0.97),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          bottom: 4,
        ),
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
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                if (_viewMode == PdfViewMode.original)
                  IconButton(
                    icon: const Icon(Icons.fit_screen),
                    color: isZoomFitWidth
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                    onPressed: toggleZoomFit,
                    tooltip: isZoomFitWidth ? '适配页面' : '适配宽度',
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  onPressed: () => setState(() => showSearchBar = !showSearchBar),
                  tooltip: '搜索',
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_outline),
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  onPressed: showBookmarksList,
                  tooltip: '书签列表',
                ),
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      key: ValueKey('bookmark_$isBookmarked'),
                      color: isBookmarked ? Colors.amber : null,
                    ),
                  ),
                  onPressed: () => toggleBookmark(_currentPage),
                  tooltip: isBookmarked ? '删除书签' : '添加书签',
                ),
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  onPressed: _openAIAssistant,
                  tooltip: 'AI 助手',
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  onPressed: _toggleFullscreen,
                  tooltip: '全屏',
                ),
              ],
            ),
            if (_viewMode == PdfViewMode.original)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isZoomFitWidth ? Icons.arrow_left : Icons.fullscreen,
                      size: 12,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      zoomLabel(),
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
    );
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
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey('fs_bookmark_$isBookmarked'),
                  color: isBookmarked ? Colors.amber : Colors.white70,
                ),
              ),
              onPressed: () => toggleBookmark(_currentPage),
              tooltip: isBookmarked ? '删除书签' : '添加书签',
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
        color: theme.cardColor.withOpacity(0.97),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (_viewMode == PdfViewMode.original)
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    onPressed: () {
                      final z = currentZoom - 0.25;
                      _pdfViewerController?.zoomLevel = z.clamp(0.5, 5.0);
                    },
                    tooltip: '缩小',
                  ),
                if (_viewMode == PdfViewMode.original)
                  IconButton(
                    icon: const Icon(Icons.fit_screen),
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    onPressed: toggleZoomFit,
                    tooltip: '适配屏幕',
                    iconSize: 20,
                  ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: theme.colorScheme.onSurface,
                  onPressed: _currentPage > 1 ? () => _pdfViewerController?.previousPage() : null,
                ),
                GestureDetector(
                  onTap: () => showPageJumpDialog(_totalPages),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_stories, size: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Text(
                          '$_currentPage / $_totalPages',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14, fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: theme.colorScheme.onSurface,
                  onPressed: _currentPage < _totalPages ? () => _pdfViewerController?.nextPage() : null,
                ),
                if (_viewMode == PdfViewMode.original)
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    onPressed: () {
                      final z = currentZoom + 0.25;
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
                final z = currentZoom - 0.25;
                _pdfViewerController?.zoomLevel = z.clamp(0.5, 5.0);
              },
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen, color: Colors.white70),
              onPressed: toggleZoomFit,
              tooltip: '适配屏幕',
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: _currentPage > 1 ? () => _pdfViewerController?.previousPage() : null,
            ),
            GestureDetector(
              onTap: () => showPageJumpDialog(_totalPages),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: _currentPage < _totalPages ? () => _pdfViewerController?.nextPage() : null,
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, color: Colors.white70),
              onPressed: () {
                final z = currentZoom + 0.25;
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
        onTap: () => showPageJumpDialog(_totalPages),
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
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500,
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
      top: _isFullscreen ? (MediaQuery.of(context).padding.top + 56) : 0,
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
                    controller: searchController,
                    autofocus: true,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索 PDF 内容...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.onSurface.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              onPressed: clearSearch,
                            )
                          : null,
                    ),
                    onSubmitted: (_) => performSearch(),
                    onChanged: (_) {
                      setState(() {});
                      performSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (searchInitialized)
                  Text(
                    '使用搜索面板导航',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  onPressed: clearSearch,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
