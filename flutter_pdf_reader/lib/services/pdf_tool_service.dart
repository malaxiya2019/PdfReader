import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Offset, Size;
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

  /// ---- PDF 转图片 ----
  /// Syncfusion v24 不直接支持 PdfPage.render()，该功能需 v25+
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
        // 标记文件 - 完整导出需 Syncfusion v25+
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

  static Future<Directory> getOutputDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/PDF_Tools');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }
}
