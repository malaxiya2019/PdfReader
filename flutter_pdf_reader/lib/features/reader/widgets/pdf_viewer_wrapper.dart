import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// PDF 原始视图包裹组件
///
/// 封装 SfPdfViewer.file + 双击检测 Listener。
class PdfViewerWrapper extends StatelessWidget {
  final String filePath;
  final GlobalKey<SfPdfViewerState> pdfViewerKey;
  final PdfViewerController pdfViewerController;
  final PdfDocumentLoadedCallback? onDocumentLoaded;
  final PdfPageChangedCallback? onPageChanged;
  final PdfZoomCallback? onZoomLevelChanged;
  final VoidCallback onTap;
  final PointerDownEventListener? onPointerDown;

  const PdfViewerWrapper({
    super.key,
    required this.filePath,
    required this.pdfViewerKey,
    required this.pdfViewerController,
    this.onDocumentLoaded,
    this.onPageChanged,
    this.onZoomLevelChanged,
    required this.onTap,
    this.onPointerDown,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: onPointerDown,
      child: SfPdfViewer.file(
        File(filePath),
        key: pdfViewerKey,
        controller: pdfViewerController,
        onDocumentLoaded: onDocumentLoaded,
        onPageChanged: onPageChanged,
        onZoomLevelChanged: onZoomLevelChanged,
        onTap: (_) => onTap(),
      ),
    );
  }
}
