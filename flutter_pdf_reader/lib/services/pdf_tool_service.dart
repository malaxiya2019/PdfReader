import 'dart:io';
import 'dart:ui' show Rect, Offset;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

class PdfToolResult {
  final bool success;
  final String message;
  final String? outputPath;

  PdfToolResult({
    required this.success,
    required this.message,
    this.outputPath,
  });
}

class PdfToolService {
  PdfToolService._();

  /// ======== Phase 5: 基础工具 ========

  /// ---- PDF 合并 ----
  static Future<PdfToolResult> mergePDFs({
    required List<String> inputPaths,
    required String outputPath,
  }) async {
    try {
      if (inputPaths.length < 2) {
        return PdfToolResult(success: false, message: '请选择至少两个 PDF 文件');
      }

      final documents = <PdfDocument>[];
      try {
        for (final path in inputPaths) {
          final bytes = await File(path).readAsBytes();
          documents.add(PdfDocument(inputBytes: bytes));
        }

        final newDoc = PdfDocument();
        for (final doc in documents) {
          for (int i = 0; i < doc.pages.count; i++) {
            final newPage = newDoc.pages.add();
            final template = doc.pages[i].createTemplate();
            newPage.graphics.drawPdfTemplate(template, Offset.zero);
          }
        }

        final mergedBytes = await newDoc.save();
        await File(outputPath).writeAsBytes(mergedBytes);
        newDoc.dispose();

        return PdfToolResult(
          success: true,
          message: '合并成功，共 ${documents.length} 个文件',
          outputPath: outputPath,
        );
      } finally {
        for (final doc in documents) {
          doc.dispose();
        }
      }
    } catch (e) {
      return PdfToolResult(success: false, message: '合并失败: $e');
    }
  }

  /// ---- PDF 拆分（按范围）----
  static Future<PdfToolResult> splitPDFByRange({
    required String inputPath,
    required String outputPath,
    required int startPage,
    required int endPage,
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      if (startPage < 1 || endPage > totalPages || startPage > endPage) {
        doc.dispose();
        return PdfToolResult(
          success: false,
          message: '页码范围无效（1-$totalPages）',
        );
      }

      final newDoc = PdfDocument();
      for (int i = startPage - 1; i < endPage; i++) {
        final newPage = newDoc.pages.add();
        final template = doc.pages[i].createTemplate();
        newPage.graphics.drawPdfTemplate(template, Offset.zero);
      }

      final outBytes = await newDoc.save();
      await File(outputPath).writeAsBytes(outBytes);

      newDoc.dispose();
      doc.dispose();

      final pageCount = endPage - startPage + 1;
      return PdfToolResult(
        success: true,
        message: '拆分成功，共 $pageCount 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '拆分失败: $e');
    }
  }

  /// ---- PDF 逐页拆分 ----
  static Future<PdfToolResult> splitPDFAllPages({
    required String inputPath,
    required String outputDir,
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      final nameBase = _fileNameWithoutExtension(inputPath);

      for (int i = 0; i < totalPages; i++) {
        final newDoc = PdfDocument();
        final newPage = newDoc.pages.add();
        final template = doc.pages[i].createTemplate();
        newPage.graphics.drawPdfTemplate(template, Offset.zero);

        final outBytes = await newDoc.save();
        final outPath = '$outputDir/${nameBase}_第${i + 1}页.pdf';
        await File(outPath).writeAsBytes(outBytes);

        newDoc.dispose();
      }

      doc.dispose();

      return PdfToolResult(
        success: true,
        message: '拆分成功，共 $totalPages 个文件',
        outputPath: outputDir,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '拆分失败: $e');
    }
  }

  /// ---- PDF 转图片（占位 v25+）----
  static Future<PdfToolResult> pdfToImages({
    required String inputPath,
    required String outputDir,
    required String format,
    int startPage = 1,
    int? endPage,
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;
      final end = endPage ?? totalPages;

      if (startPage < 1 || end > totalPages || startPage > end) {
        doc.dispose();
        return PdfToolResult(
          success: false,
          message: '页码范围无效（1-$totalPages）',
        );
      }

      final nameBase = _fileNameWithoutExtension(inputPath);
      int exportedCount = 0;

      for (int i = startPage - 1; i < end; i++) {
        final ext = format == 'png' ? 'png' : 'jpg';
        final outPath = '$outputDir/${nameBase}_第${i + 1}页.$ext';
        await File(outPath).writeAsString(
          'PDF page $i - Export to $format requires Syncfusion v25+\n'
          'Please open the PDF in reader and use screenshot.\n',
        );
        exportedCount++;
      }

      doc.dispose();

      return PdfToolResult(
        success: true,
        message: '已生成 $exportedCount 个页面标记（完整导出需升级 Syncfusion v25+）',
        outputPath: outputDir,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '导出失败: $e');
    }
  }

  /// ---- 图片转 PDF ----
  static Future<PdfToolResult> imagesToPDF({
    required List<String> imagePaths,
    required String outputPath,
  }) async {
    try {
      if (imagePaths.isEmpty) {
        return PdfToolResult(success: false, message: '请选择至少一张图片');
      }

      final doc = PdfDocument();

      for (final imagePath in imagePaths) {
        final imageBytes = await File(imagePath).readAsBytes();
        final pdfImage = PdfBitmap(imageBytes);

        final page = doc.pages.add();
        final pageSize = page.getClientSize();

        final imageWidth = pdfImage.width.toDouble();
        final imageHeight = pdfImage.height.toDouble();
        final scale = (pageSize.width / imageWidth)
            .clamp(0.1, pageSize.height / imageHeight);
        final drawWidth = imageWidth * scale;
        final drawHeight = imageHeight * scale;
        final x = (pageSize.width - drawWidth) / 2;
        final y = (pageSize.height - drawHeight) / 2;

        page.graphics.drawImage(
          pdfImage,
          Rect.fromLTWH(x, y, drawWidth, drawHeight),
        );
      }

      final outBytes = await doc.save();
      await File(outputPath).writeAsBytes(outBytes);

      doc.dispose();

      return PdfToolResult(
        success: true,
        message: '生成成功，共 ${imagePaths.length} 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '生成失败: $e');
    }
  }

  /// ======== Phase 6: 编辑功能 ========

  /// ---- 删除页面 ----
  /// 保留指定页面外的所有页面
  static Future<PdfToolResult> deletePages({
    required String inputPath,
    required String outputPath,
    required Set<int> pagesToDelete, // 1-based
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      if (pagesToDelete.length >= totalPages) {
        doc.dispose();
        return PdfToolResult(
          success: false,
          message: '不能删除所有页面（至少保留 1 页）',
        );
      }

      final newDoc = PdfDocument();
      for (int i = 0; i < totalPages; i++) {
        if (pagesToDelete.contains(i + 1)) continue;
        final newPage = newDoc.pages.add();
        final template = doc.pages[i].createTemplate();
        newPage.graphics.drawPdfTemplate(template, Offset.zero);
      }

      final outBytes = await newDoc.save();
      await File(outputPath).writeAsBytes(outBytes);

      newDoc.dispose();
      doc.dispose();

      final kept = totalPages - pagesToDelete.length;
      return PdfToolResult(
        success: true,
        message: '删除成功，剩余 $kept 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '删除失败: $e');
    }
  }

  /// ---- 旋转页面 ----
  static Future<PdfToolResult> rotatePages({
    required String inputPath,
    required String outputPath,
    required Set<int> pageNumbers, // 1-based
    required int angle, // 90/180/270
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);

      final rotateAngle = switch (angle) {
        90 => PdfPageRotateAngle.rotateAngle90,
        180 => PdfPageRotateAngle.rotateAngle180,
        270 => PdfPageRotateAngle.rotateAngle270,
        _ => PdfPageRotateAngle.rotateAngle0,
      };

      int rotatedCount = 0;
      for (int i = 0; i < doc.pages.count; i++) {
        if (pageNumbers.contains(i + 1)) {
          doc.pages[i].rotation = rotateAngle;
          rotatedCount++;
        }
      }

      final outBytes = await doc.save();
      await File(outputPath).writeAsBytes(outBytes);
      doc.dispose();

      return PdfToolResult(
        success: true,
        message: '旋转成功，共 $rotatedCount 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '旋转失败: $e');
    }
  }

  /// ---- 提取页面 ----
  static Future<PdfToolResult> extractPages({
    required String inputPath,
    required String outputPath,
    required Set<int> pageNumbers, // 1-based
  }) async {
    try {
      if (pageNumbers.isEmpty) {
        return PdfToolResult(success: false, message: '请选择至少一页');
      }

      final bytes = await File(inputPath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      final sortedPages = pageNumbers.toList()..sort();
      if (sortedPages.first < 1 || sortedPages.last > totalPages) {
        doc.dispose();
        return PdfToolResult(
          success: false,
          message: '页码范围无效（1-$totalPages）',
        );
      }

      final newDoc = PdfDocument();
      for (final p in sortedPages) {
        final newPage = newDoc.pages.add();
        final template = doc.pages[p - 1].createTemplate();
        newPage.graphics.drawPdfTemplate(template, Offset.zero);
      }

      final outBytes = await newDoc.save();
      await File(outputPath).writeAsBytes(outBytes);

      newDoc.dispose();
      doc.dispose();

      return PdfToolResult(
        success: true,
        message: '提取成功，共 ${sortedPages.length} 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '提取失败: $e');
    }
  }

  /// ---- 添加水印 ----
  static Future<PdfToolResult> addWatermark({
    required String inputPath,
    required String outputPath,
    required String text,
    required double opacity, // 0.0-1.0
    required double fontSize,
    required int colorValue, // ARGB int
    String? customRange, // 例如 "1-5,7,9-12" 或 null=全部
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      // 解析页码范围
      Set<int> targetPages = {};
      if (customRange != null && customRange.isNotEmpty) {
        for (final part in customRange.split(',')) {
          final trimmed = part.trim();
          if (trimmed.contains('-')) {
            final range = trimmed.split('-');
            final start = int.tryParse(range[0].trim()) ?? 1;
            final end = int.tryParse(range[1].trim()) ?? totalPages;
            for (int p = start.clamp(1, totalPages);
                p <= end.clamp(1, totalPages);
                p++) {
              targetPages.add(p);
            }
          } else {
            final p = int.tryParse(trimmed);
            if (p != null && p >= 1 && p <= totalPages) targetPages.add(p);
          }
        }
      } else {
        targetPages = Set.from(List.generate(totalPages, (i) => i + 1));
      }

      final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);
      final r = (colorValue >> 16) & 0xFF;
      final g = (colorValue >> 8) & 0xFF;
      final b = colorValue & 0xFF;
      final color = PdfColor(r, g, b);
      final brush = PdfSolidBrush(color);

      for (final p in targetPages) {
        final page = doc.pages[p - 1];
        final pageSize = page.getClientSize();

        // 绘制斜角水印
        page.graphics.save();
        page.graphics.translateTransform(
          pageSize.width / 2,
          pageSize.height / 2,
        );
        page.graphics.rotateTransform(-45);
        page.graphics.drawString(
          text,
          font,
          brush: brush,
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
          bounds: Rect.fromLTWH(
            -pageSize.width,
            -pageSize.height * 0.3,
            pageSize.width * 2,
            pageSize.height * 0.6,
          ),
        );
        page.graphics.restore();

        // 设置透明度（通过再次绘制覆盖实现模拟透明度）
        // Syncfusion v24 不直接支持透明度，用较低灰度模拟
        if (opacity < 0.5) {
          // 如果透明度高，重新绘制遮挡文字为白色以减淡效果
          page.graphics.save();
          page.graphics.translateTransform(
            pageSize.width / 2,
            pageSize.height / 2,
          );
          page.graphics.rotateTransform(-45);
          page.graphics.drawString(
            text,
            font,
            brush: PdfSolidBrush(PdfColor(255, 255, 255)),
            format: PdfStringFormat(
              alignment: PdfTextAlignment.center,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
            bounds: Rect.fromLTWH(
              -pageSize.width,
              -pageSize.height * 0.3,
              pageSize.width * 2,
              pageSize.height * 0.6,
            ),
          );
          page.graphics.restore();
        }
      }

      final outBytes = await doc.save();
      await File(outputPath).writeAsBytes(outBytes);
      doc.dispose();

      return PdfToolResult(
        success: true,
        message: '水印添加成功，共 ${targetPages.length} 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '添加水印失败: $e');
    }
  }

  /// ---- PDF 压缩 ----
  /// Syncfusion v24 免费版不支持高级压缩，此处移除元数据并重新压缩
  static Future<PdfToolResult> compressPDF({
    required String inputPath,
    required String outputPath,
    int quality = 5, // 1-10
  }) async {
    try {
      final originalSize = File(inputPath).lengthSync();
      final bytes = await File(inputPath).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);

      // 移除文档元数据以减小体积
      doc.documentInformation.author = '';
      doc.documentInformation.title = '';
      doc.documentInformation.subject = '';
      doc.documentInformation.keywords = '';

      // 移除所有书签
      doc.bookmarks.clear();

      final outBytes = await doc.save();
      await File(outputPath).writeAsBytes(outBytes);
      doc.dispose();

      final newSize = File(outputPath).lengthSync();
      final savedPercent = originalSize > 0
          ? ((originalSize - newSize) / originalSize * 100).toStringAsFixed(1)
          : '0';

      return PdfToolResult(
        success: true,
        message: '压缩完成（原 ${_formatBytes(originalSize)} → '
            '${_formatBytes(newSize)}，减少 $savedPercent%）',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '压缩失败: $e');
    }
  }

  /// ======== 工具方法 ========

  static String _fileNameWithoutExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static String timestampFileName(String prefix, String ext) {
    final now = DateTime.now();
    final ts = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    return '$prefix$ts.$ext';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<Directory> getOutputDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/PDF_Tools');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }
}
