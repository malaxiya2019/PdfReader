import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Reflow 文本重排功能的 Mixin
///
/// 混入到 _PdfReaderPageState 中使用。
/// 负责：PDF 文本提取、缓存、预提取相邻页。
mixin ReflowMixin<T extends StatefulWidget> on State<T> {
  // ── Reflow 状态 ──
  bool reflowReady = false;
  String reflowText = '';
  double reflowFontSize = 18.0;
  ScrollController? reflowScrollController;

  // ── 缓存 ──
  Uint8List? pdfFileBytes;
  final Map<int, String> pageTextCache = {};
  bool pdfBytesLoading = false;
  Completer<void>? pdfBytesCompleter;

  // ── 需要在主 State 中定义的接口 ──
  String get filePath;
  int get currentPage;
  int get totalPages;

  /// 切换到 Reflow 模式
  Future<void> toggleReflowView() async {
    reflowReady = false;
    reflowText = '';
    await cachePdfBytes();
    await extractCurrentPageText();
  }

  /// 缓存 PDF 文件字节
  Future<void> cachePdfBytes() async {
    if (pdfFileBytes != null) return;
    if (pdfBytesLoading) {
      await pdfBytesCompleter?.future;
      return;
    }
    pdfBytesLoading = true;
    pdfBytesCompleter = Completer<void>();
    try {
      final file = File(filePath);
      if (await file.exists()) {
        pdfFileBytes = await file.readAsBytes();
      }
    } catch (_) {}
    pdfBytesLoading = false;
    pdfBytesCompleter?.complete();
  }

  /// 提取当前页文本
  Future<void> extractCurrentPageText() async {
    if (pageTextCache.containsKey(currentPage)) {
      setState(() {
        reflowText = pageTextCache[currentPage]!;
        reflowReady = true;
      });
      scrollReflowToTop();
      return;
    }
    final bytes = pdfFileBytes;
    if (bytes == null) {
      try {
        final file = File(filePath);
        if (!await file.exists()) {
          setState(() { reflowText = '（文件不存在）'; reflowReady = true; });
          return;
        }
        pdfFileBytes = await file.readAsBytes();
        await extractFromBytes(pdfFileBytes!);
      } catch (e) {
        setState(() { reflowText = '文本提取失败: $e'; reflowReady = true; });
      }
    } else {
      await extractFromBytes(bytes);
    }
  }

  /// 从字节数据提取文本
  Future<void> extractFromBytes(Uint8List bytes) async {
    try {
      final doc = PdfDocument(inputBytes: bytes);
      final pageIndex = (currentPage - 1).clamp(0, doc.pages.count - 1);
      final extractor = PdfTextExtractor(doc);
      final pageText = extractor.extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      doc.dispose();
      final text = pageText.trim();
      pageTextCache[currentPage] = text.isEmpty
          ? '（此页无可提取的文本，可能是扫描件或图片型 PDF）'
          : text;
      setState(() {
        reflowText = pageTextCache[currentPage]!;
        reflowReady = true;
      });
      scrollReflowToTop();
    } catch (e) {
      setState(() { reflowText = '文本提取失败: $e'; reflowReady = true; });
    }
  }

  /// 预提取相邻页文本
  Future<void> prefetchNeighborPages(int currentPageNum) async {
    final bytes = pdfFileBytes;
    if (bytes == null) return;
    for (final page in [currentPageNum + 1, currentPageNum + 2]) {
      if (page < 1 || page > totalPages) continue;
      if (pageTextCache.containsKey(page)) continue;
      try {
        final doc = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(doc);
        final text = extractor.extractText(
          startPageIndex: page - 1,
          endPageIndex: page - 1,
        );
        doc.dispose();
        pageTextCache[page] = text.trim().isEmpty ? '（无可提取文本）' : text.trim();
      } catch (_) {}
    }
  }

  /// 滚动 Reflow 视图到顶部
  void scrollReflowToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (reflowScrollController?.hasClients ?? false) {
        reflowScrollController!.animateTo(
          0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
