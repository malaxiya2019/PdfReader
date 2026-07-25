import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../services/reading_record_service.dart';
import '../../services/bookmark_service.dart';
import 'ai_assistant_page.dart';

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
    super.dispose();
  }

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

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
      _isLoading = false;
    });
    _restorePage();
    _checkBookmark();
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() => _currentPage = details.newPageNumber);
    _saveRecord();
    _checkBookmark();
  }

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
                    color: Colors.grey.withOpacity(0.3),
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
                        color: theme.colorScheme.primary.withOpacity(0.12),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
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

  // removed misplaced @override
  Future<void> _openAIAssistant() async {
    // 提取 PDF 文本
    String pdfText = "";
    try {
      // 使用 PdfDocument API 提取文本（Syncfusion v24+）
      final File file = File(widget.filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final PdfDocument doc = PdfDocument(inputBytes: bytes);
        final StringBuffer buf = StringBuffer();
        for (int i = 0; i < doc.pages.count; i++) {
          buf.writeln(doc.pages[i].extractText());
        }
        pdfText = buf.toString();
        doc.dispose();
      }
    } catch (e) {
      // error ignored
    }

    if (pdfText.isEmpty) {
      pdfText = "（无法自动提取 PDF 文本。请确保文档包含可提取的文字层，"
          "而非纯扫描图片。扫描件请使用 Phase 7 OCR 功能识别。）";
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIAssistantPage(
          pdfText: pdfText,
          pdfName: widget.fileName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final readerWidget = SfPdfViewer.file(
      File(widget.filePath),
      key: _pdfViewerKey,
      controller: _pdfViewerController!,
      enableDoubleTapZooming: true,
      onDocumentLoaded: _onDocumentLoaded,
      onPageChanged: _onPageChanged,
    );

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            GestureDetector(
              onTap: _toggleControls,
              child: readerWidget,
            ),
            // Fullscreen top bar
            FadeTransition(
              opacity: _controlsAnimation,
              child: _showControls ? _buildFullscreenTopBar(theme) : const SizedBox.shrink(),
            ),
            // Fullscreen bottom bar
            FadeTransition(
              opacity: _controlsAnimation,
              child: _showControls ? _buildFullscreenBottomBar(theme) : const SizedBox.shrink(),
            ),
            // Search bar
            if (_showSearchBar) _buildSearchBar(theme),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(theme),
      body: Stack(
        children: [
          readerWidget,
          if (_isLoading)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: child,
                  );
                },
                child: const CircularProgressIndicator(),
              ),
            ),
          _buildPageIndicator(theme),
          if (_showSearchBar) _buildSearchBar(theme),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Text(
        widget.fileName,
        style: const TextStyle(fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: const Color(0xFF1A1A2E),
      actions: [
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _showSearchBar ? Icons.search_off : Icons.search,
              key: ValueKey('search_$_showSearchBar'),
            ),
          ),
          onPressed: () => setState(() => _showSearchBar = !_showSearchBar),
          tooltip: '搜索',
        ),
        IconButton(
          icon: const Icon(Icons.bookmark_outline),
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
          onPressed: _openAIAssistant,
          tooltip: 'AI 助手',
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen),
          onPressed: _toggleFullscreen,
          tooltip: '全屏',
        ),
      ],
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
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: _currentPage > 1
                  ? () => _pdfViewerController?.previousPage()
                  : null,
            ),
            GestureDetector(
              onTap: _showPageJumpDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.onSurface.withOpacity(0.08),
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
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  onPressed: _clearSearch,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '输入页码 (1-$_totalPages)',
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
            child: Text(
              '取消',
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
}
