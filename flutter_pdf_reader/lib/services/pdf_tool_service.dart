import 'dart:io';
import 'dart:typed_data';
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
  /// 将多个 PDF 文件合并为一个
  static Future<PdfToolResult> mergePDFs({
    required List<String> inputPaths,
    required String outputPath,
  }) async {
    try {
      if (inputPaths.isEmpty) {
        return PdfToolResult(success: false, message: '请选择至少一个 PDF 文件');
      }
      if (inputPaths.length < 2) {
        return PdfToolResult(success: false, message: '请选择至少两个 PDF 文件进行合并');
      }

      final documents = <PdfDocument>[];
      try {
        for (final path in inputPaths) {
          final bytes = await File(path).readAsBytes();
          documents.add(PdfDocument(inputBytes: bytes));
        }

        final mergedDoc = PdfDocument.merge(documents);
        final mergedBytes = mergedDoc.save();
        await File(outputPath).writeAsBytes(mergedBytes);

        mergedDoc.dispose();

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

  /// ---- PDF 拆分 ----
  /// 按页码范围拆分 PDF（从 startPage 到 endPage，从 1 开始）
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
      for (int i = startPage; i <= endPage; i++) {
        newDoc.importPage(doc, i - 1);
      }

      final outBytes = newDoc.save();
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

  /// 按单页拆分（每页生成一个独立 PDF）
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
        newDoc.importPage(doc, i);

        final outBytes = newDoc.save();
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
  /// 使用 Syncfusion PDF 将 PDF 页面导出为图片
  static Future<PdfToolResult> pdfToImages({
    required String inputPath,
    required String outputDir,
    required String format, // 'png' 或 'jpg'
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
        final page = doc.pages[i];
        final imageBytes = page.render(
          scale: 2.0,
          keepTransparent: format == 'png',
        );

        final ext = format == 'png' ? 'png' : 'jpg';
        final outPath = '$outputDir/${nameBase}_第${i + 1}页.$ext';
        await File(outPath).writeAsBytes(imageBytes);
        exportedCount++;
      }

      doc.dispose();

      return PdfToolResult(
        success: true,
        message: '导出 $exportedCount 张图片成功',
        outputPath: outputDir,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '导出失败: $e');
    }
  }

  /// ---- 图片转 PDF ----
  /// 将多张图片合成为一个 PDF
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

        // 获取图片尺寸
        final page = doc.pages.add();
        final pageSize = page.getClientSize();

        // 计算缩放比例以适配页面
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

      final outBytes = doc.save();
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

  /// ---- 工具方法 ----
  static String _fileNameWithoutExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// 获取时间戳文件名
  static String timestampFileName(String prefix, String ext) {
    final now = DateTime.now();
    final ts = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    return '$prefix$ts.$ext';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// 获取输出目录
  static Future<Directory> getOutputDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/PDF_Tools');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }
}
