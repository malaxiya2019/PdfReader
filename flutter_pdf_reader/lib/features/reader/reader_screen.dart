import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'reader_reflow.dart';
import 'reader_controller.dart';
import 'ai_assistant_page.dart';
import 'widgets/pdf_viewer_wrapper.dart';
import 'widgets/reflow_view.dart';
import 'widgets/reflow_font_panel.dart';
import 'widgets/reader_loading.dart';
import 'widgets/reader_top_bar.dart';
import 'widgets/reader_fullscreen_bar.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/page_indicator.dart';
import 'widgets/search_overlay.dart';

enum PdfViewMode { original, reflow }

class PdfReaderPage extends StatefulWidget {
  final String filePath;
  final String fileName;
  const PdfReaderPage({super.key, required this.filePath, required this.fileName});
  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage>
    with SingleTickerProviderStateMixin, ReflowMixin, ReaderControllerMixin {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfViewerController;
  bool _isFullscreen = false, _isLoading = true, _showControls = true;
  int _currentPage = 1, _totalPages = 0;
  late AnimationController _controlsController;
  PdfViewMode _viewMode = PdfViewMode.original;

  @override PdfViewerController? get pdfViewerController => _pdfViewerController;
  @override String get filePath => widget.filePath;
  @override String get fileName => widget.fileName;
  @override int get currentPage => _currentPage;
  @override int get totalPages => _totalPages;
  @override bool get isFullscreen => _isFullscreen;
  @override bool get isOriginalMode => _viewMode == PdfViewMode.original;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _controlsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _controlsController.value = 1.0;
    reflowScrollController = ScrollController();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    searchController.dispose();
    _controlsController.dispose();
    _pdfViewerController?.dispose();
    reflowScrollController?.dispose();
    doubleTapTimer?.cancel();
    super.dispose();
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    final pdfDoc = details.document;
    setState(() { _totalPages = pdfDoc.pages.count; _isLoading = false; });
    onDocumentLoaded(pdfDoc.pages.count, pdfDoc.pages[0].size);
    restorePage();
    checkBookmark(_currentPage);
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final newPage = details.newPageNumber;
    setState(() => _currentPage = newPage);
    saveRecord(newPage, _totalPages);
    checkBookmark(newPage);
    if (_viewMode == PdfViewMode.reflow) { extractCurrentPageText(); prefetchNeighborPages(newPage); }
  }

  void _onZoomLevelChanged(PdfZoomDetails details) => onZoomLevelChanged(details.newZoomLevel);

  void _toggleViewMode() async {
    if (_viewMode == PdfViewMode.original) {
      setState(() { _viewMode = PdfViewMode.reflow; reflowReady = false; reflowText = ''; });
      await toggleReflowView();
    } else {
      setState(() => _viewMode = PdfViewMode.original);
    }
  }

  void _toggleControls() {
    _showControls ? _controlsController.reverse() : _controlsController.forward();
    setState(() => _showControls = !_showControls);
  }

  void _toggleFullscreen() {
    final gf = !_isFullscreen;
    setState(() => _isFullscreen = gf);
    if (gf) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight, DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      _controlsController.forward();
    }
  }

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
    Navigator.push(context, MaterialPageRoute(builder: (_) => AIAssistantPage(pdfName: widget.fileName, pdfText: pdfText)));
  }

  void _toggleSearchBar() => setState(() => showSearchBar = !showSearchBar);
  void _handleSearch(String text) { searchController.text = text; performSearch(); }
  void _handleClearSearch() { clearSearch(); }
  void _handleCloseSearch() { clearSearch(); setState(() => showSearchBar = false); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (_viewMode == PdfViewMode.original)
          PdfViewerWrapper(filePath: widget.filePath, pdfViewerKey: _pdfViewerKey, pdfViewerController: _pdfViewerController!,
            onDocumentLoaded: _onDocumentLoaded, onPageChanged: _onPageChanged, onZoomLevelChanged: _onZoomLevelChanged,
            onTap: _toggleControls, onPointerDown: onPointerDown)
        else
          ReflowView(reflowReady: reflowReady, reflowText: reflowText, reflowFontSize: reflowFontSize, onTap: _toggleControls),
        if (_isLoading) const ReaderLoading(),
        if (_showControls) ...[
          _isFullscreen
              ? ReaderFullscreenBar(fileName: widget.fileName, isReflowMode: _viewMode == PdfViewMode.reflow, isBookmarked: isBookmarked,
                  onBack: () => Navigator.pop(context), onToggleViewMode: _toggleViewMode,
                  onToggleBookmark: () => toggleBookmark(_currentPage), onToggleFullscreen: _toggleFullscreen)
              : ReaderTopBar(fileName: widget.fileName, isReflowMode: _viewMode == PdfViewMode.reflow, isZoomFitWidth: isZoomFitWidth,
                  isBookmarked: isBookmarked, zoomLabel: zoomLabel(), onBack: () => Navigator.pop(context),
                  onToggleViewMode: _toggleViewMode, onToggleZoomFit: toggleZoomFit, onSearch: _toggleSearchBar,
                  onShowBookmarks: showBookmarksList, onToggleBookmark: () => toggleBookmark(_currentPage),
                  onOpenAI: _openAIAssistant, onToggleFullscreen: _toggleFullscreen),
          ReaderBottomBar(currentPage: _currentPage, totalPages: _totalPages, currentZoom: currentZoom,
            isFullscreen: _isFullscreen, isReflowMode: _viewMode == PdfViewMode.reflow,
            onZoomOut: () { final z = currentZoom - 0.25; _pdfViewerController?.zoomLevel = z.clamp(0.5, 5.0); },
            onZoomIn: () { final z = currentZoom + 0.25; _pdfViewerController?.zoomLevel = z.clamp(0.5, 5.0); },
            onToggleZoomFit: toggleZoomFit, onPrevPage: () => _pdfViewerController?.previousPage(),
            onNextPage: () => _pdfViewerController?.nextPage(), onPageJump: () => showPageJumpDialog(_totalPages)),
        ],
        if (showSearchBar)
          SearchOverlay(isFullscreen: _isFullscreen, searchController: searchController, searchInitialized: searchInitialized,
            onSearch: _handleSearch, onClear: _handleClearSearch, onClose: _handleCloseSearch),
        if (!_showControls && !_isFullscreen)
          PageIndicator(currentPage: _currentPage, totalPages: _totalPages, onTap: () => showPageJumpDialog(_totalPages)),
        if (_viewMode == PdfViewMode.reflow)
          ReflowFontPanel(reflowFontSize: reflowFontSize,
            onFontSizeChanged: (v) => setState(() => reflowFontSize = v),
            onRefresh: () { pageTextCache.remove(_currentPage); extractCurrentPageText(); }),
      ]),
    );
  }
}
