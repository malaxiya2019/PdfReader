import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Offset, Rect;
import 'dart:ui' as ui show Image, ImageByteFormat;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf_render/pdf_render.dart' as pdf_render;

import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfToolResult {
  final bool success;
  final String message;
  final String? outputPath;
  final int? exportedCount;

  PdfToolResult({
    required this.success,
    required this.message,
    this.outputPath,
    this.exportedCount,
  });
}

/// PDF 工具服务
///
/// 支持 PDF 编辑、转换、合并/拆分等功能
/// PDF 转图片使用 pdf_render 纯 Dart 方案
class PdfToolService {
  PdfToolService._();

  static const int _largeFileThreshold = 50 * 1024 * 1024; // 50MB

  // ============================================================
  // Isolate 辅助
  // ============================================================

  static Future<List<int>> _readBytesInIsolate(String path) async {
    final file = File(path);
    final length = await file.length();
    if (length < _largeFileThreshold) {
      return await file.readAsBytes();
    }
    return await Isolate.run(() => File(path).readAsBytesSync());
  }

  static Future<void> _writeBytesInIsolate(
      String path, List<int> bytes) async {
    if (bytes.length < _largeFileThreshold) {
      await File(path).writeAsBytes(bytes);
    } else {
      await Isolate.run(() => File(path).writeAsBytesSync(bytes));
    }
  }

  /// 检查总文件大小
  static Future<String?> checkFileSizes(List<String> paths) async {
    int total = 0;
    for (final p in paths) {
      final f = File(p);
      if (await f.exists()) {
        total += await f.length();
      }
    }
    if (total > 200 * 1024 * 1024) {
      return '文件总大小 ${(total / (1024 * 1024)).toStringAsFixed(1)} MB，'
          '较大文件可能需要较长时间处理';
    }
    if (total > _largeFileThreshold) {
      return '文件总大小 ${(total / (1024 * 1024)).toStringAsFixed(1)} MB，'
          '建议耐心等待';
    }
    return null;
  }

  static void _disposeDocuments(List<PdfDocument> docs) {
    for (final doc in docs) {
      try { doc.dispose(); } catch (_) {}
    }
  }

  // ============================================================
  // 获取输出目录
  // ============================================================

  /// 获取输出目录（缓存目录）
  static Future<Directory> getOutputDir() async {
    final dir = Directory.systemTemp;
    final outDir = Directory('${dir.path}/pdf_tools');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }

  /// 获取图库保存目录（公共 Pictures 目录）
  static Future<Directory> getGalleryDir() async {
    // 优先使用外部存储的 Pictures 目录
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      // 用上级目录的 Pictures/AllPDFReader
      // Android/data/<package>/files -> 往上到 Android 同级
      final baseDir = Directory(
        '/storage/emulated/0/Pictures/AllPDFReader',
      );
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }
      return baseDir;
    }
    // 回退到缓存目录
    final dir = Directory('/storage/emulated/0/Pictures/AllPDFReader');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 生成时间戳文件名
  static String timestampFileName(String prefix, String ext) {
    final now = DateTime.now();
    return '${prefix}${now.millisecondsSinceEpoch}.$ext';
  }

  /// 通知媒体库扫描新文件（让图片出现在相册中）
  static Future<void> _notifyMediaScanner(String path) async {
    try {
      await Process.run('am', [
        'broadcast',
        '-a',
        'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
        '-d',
        'file://$path',
      ]);
    } catch (_) {}
  }


  // ============================================================
  // Phase 5: 基础工具
  // ============================================================

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
          final bytes = await _readBytesInIsolate(path);
          documents.add(PdfDocument(inputBytes: bytes));
        }

        final newDoc = PdfDocument();
        for (final doc in documents) {
          for (int i = 0; i < doc.pages.count; i++) {
            final newPage = newDoc.pages.add();
            final template = doc.pages[i].createTemplate();
            newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
          }
        }

        final mergedBytes = newDoc.saveSync();
        newDoc.dispose();
        await _writeBytesInIsolate(outputPath, mergedBytes);
        _disposeDocuments(documents);

        return PdfToolResult(
          success: true,
          message: '合并成功，共 ${inputPaths.length} 个文件',
          outputPath: outputPath,
        );
      } finally {
        _disposeDocuments(documents);
      }
    } catch (e) {
      return PdfToolResult(success: false, message: '合并失败: $e');
    }
  }

  /// ---- PDF 拆分（按页范围） ----
  static Future<PdfToolResult> splitPDF({
    required String inputPath,
    required String outputPath,
    required int startPage,
    required int endPage,
  }) async {
    try {
      final bytes = await _readBytesInIsolate(inputPath);
      final doc = PdfDocument(inputBytes: bytes);
      if (startPage < 1) startPage = 1;
      if (endPage > doc.pages.count) endPage = doc.pages.count;
      if (startPage > endPage) {
        doc.dispose();
        return PdfToolResult(success: false, message: '页码范围无效');
      }

      final newDoc = PdfDocument();
      for (int i = startPage - 1; i < endPage; i++) {
        final newPage = newDoc.pages.add();
        final template = doc.pages[i].createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      final outBytes = newDoc.saveSync();
      newDoc.dispose();
      doc.dispose();
      await _writeBytesInIsolate(outputPath, outBytes);

      return PdfToolResult(
        success: true,
        message: '拆分成功，共 ${endPage - startPage + 1} 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '拆分失败: $e');
    }
  }

  /// ---- PDF 拆分（每页单独文件） ----
  static Future<PdfToolResult> splitPDFByPage({
    required String inputPath,
    required String outputDir,
  }) async {
    try {
      final bytes = await _readBytesInIsolate(inputPath);
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      for (int i = 0; i < totalPages; i++) {
        final newDoc = PdfDocument();
        final newPage = newDoc.pages.add();
        final template = doc.pages[i].createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));

        final outBytes = newDoc.saveSync();
        newDoc.dispose();
        final outPath = '$outputDir/page_${i + 1}.pdf';
        await _writeBytesInIsolate(outPath, outBytes);
      }

      doc.dispose();
      return PdfToolResult(
        success: true,
        message: '逐页拆分成功，共 $totalPages 页',
        outputPath: outputDir,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '逐页拆分失败: $e');
    }
  }

  // ============================================================
  // PDF 转图片（使用 pdf_render 纯 Dart 方案，不依赖 Syncfusion 付费 API）
  // ============================================================
  static Future<PdfToolResult> pdfToImages({
    required String inputPath,
    required String outputDir,
    required String imageFormat,
    required bool saveToGallery,
  }) async {
    try {
      final doc = await pdf_render.PdfDocument.openFile(inputPath);
      final totalPages = doc.countPages;
      final ext = imageFormat.toLowerCase() == 'jpg' ? 'jpg' : 'png';

      // 准备图库目录
      Directory? galleryDir;
      if (saveToGallery) {
        galleryDir = await getGalleryDir();
        final pdfName = inputPath.split('/').last.replaceAll('.pdf', '');
        final subDir = Directory('${galleryDir.path}/$pdfName');
        if (!await subDir.exists()) {
          await subDir.create(recursive: true);
        }
        galleryDir = subDir;
      }

      int exportedCount = 0;
      for (int i = 0; i < totalPages; i++) {
        final page = await doc.getPage(i);
        final pageImage = await page.render(scale: 2.0);
        final image = pageImage.image;

        Uint8List imageBytes;
        if (imageFormat == 'jpg') {
          // 获取原始 RGBA 数据 → 用 image 包编码为 JPEG
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final rawBytes = byteData!.buffer.asUint8List();
          final decoded = img.Image.fromBytes(
            width: pageImage.width,
            height: pageImage.height,
            bytes: rawBytes,
            numChannels: 4,
          );
          imageBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
        } else {
          // PNG：直接使用 toByteData
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          imageBytes = byteData!.buffer.asUint8List();
        }

        // 保存到输出目录或相册目录
        final outPath = galleryDir != null
            ? '${galleryDir.path}/page_${i + 1}.$ext'
            : '$outputDir/page_${i + 1}.$ext';
        await File(outPath).writeAsBytes(imageBytes);
        exportedCount++;

        page.dispose();
      }

      doc.dispose();

      // 通知媒体库扫描
      if (galleryDir != null) {
        await _notifyMediaScanner(galleryDir.path);
      }

      return PdfToolResult(
        success: true,
        message: saveToGallery
            ? '已导出 $totalPages 页为 $imageFormat 格式并保存到相册'
            : '已导出 $totalPages 页为 $imageFormat 格式',
        outputPath: outputDir,
        exportedCount: totalPages,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: 'PDF 转图片失败: $e');
    }
  }

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
        final imageBytes = await _readBytesInIsolate(imagePath);
        final image = PdfBitmap(imageBytes);
        final page = doc.pages.add();
        page.graphics.drawImage(
            image,
            Rect.fromLTWH(0, 0, page.size.width, page.size.height));
      }

      final outBytes = doc.saveSync();
      doc.dispose();
      await _writeBytesInIsolate(outputPath, outBytes);

      return PdfToolResult(
        success: true,
        message: '成功转换 ${imagePaths.length} 张图片为 PDF',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '图片转 PDF 失败: $e');
    }
  }

  // ============================================================
  // Phase 6: PDF 编辑功能
  // ============================================================

  /// ---- 删除页面 ----
  static Future<PdfToolResult> deletePages({
    required String inputPath,
    required String outputPath,
    required List<int> pageNumbers,
  }) async {
    try {
      final bytes = await _readBytesInIsolate(inputPath);
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      final deleteSet = pageNumbers
          .where((n) => n >= 1 && n <= totalPages)
          .map((n) => n - 1)
          .toSet();

      final newDoc = PdfDocument();
      for (int i = 0; i < totalPages; i++) {
        if (!deleteSet.contains(i)) {
          final newPage = newDoc.pages.add();
          final template = doc.pages[i].createTemplate();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
      }

      final outBytes = newDoc.saveSync();
      newDoc.dispose();
      doc.dispose();
      await _writeBytesInIsolate(outputPath, outBytes);

      return PdfToolResult(
        success: true,
        message: '已删除 ${deleteSet.length} 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '删除页面失败: $e');
    }
  }

  /// ---- 旋转页面 ----
  static Future<PdfToolResult> rotatePages({
    required String inputPath,
    required String outputPath,
    required List<int> pageNumbers,
    required int rotation,
  }) async {
    try {
      final bytes = await _readBytesInIsolate(inputPath);
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      final newDoc = PdfDocument();
      for (int i = 0; i < totalPages; i++) {
        final newPage = newDoc.pages.add();
        final template = doc.pages[i].createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));

        if (pageNumbers.contains(i + 1)) {
          newPage.graphics.rotateTransform(rotation * 3.14159 / 180);
        }
      }

      final outBytes = newDoc.saveSync();
      newDoc.dispose();
      doc.dispose();
      await _writeBytesInIsolate(outputPath, outBytes);

      return PdfToolResult(
        success: true, message: '旋转成功', outputPath: outputPath);
    } catch (e) {
      return PdfToolResult(success: false, message: '旋转页面失败: $e');
    }
  }

  /// ---- 提取页面 ----
  static Future<PdfToolResult> extractPages({
    required String inputPath,
    required String outputPath,
    required List<int> pageNumbers,
  }) async {
    try {
      final bytes = await _readBytesInIsolate(inputPath);
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      final extractSet = pageNumbers
          .where((n) => n >= 1 && n <= totalPages)
          .map((n) => n - 1)
          .toSet();

      final newDoc = PdfDocument();
      for (int i = 0; i < totalPages; i++) {
        if (extractSet.contains(i)) {
          final newPage = newDoc.pages.add();
          final template = doc.pages[i].createTemplate();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
      }

      final outBytes = newDoc.saveSync();
      newDoc.dispose();
      doc.dispose();
      await _writeBytesInIsolate(outputPath, outBytes);

      return PdfToolResult(
        success: true,
        message: '已提取 ${extractSet.length} 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '提取页面失败: $e');
    }
  }

  /// ---- 添加水印 ----
  static Future<PdfToolResult> addWatermark({
    required String inputPath,
    required String outputPath,
    required String text,
  }) async {
    try {
      final bytes = await _readBytesInIsolate(inputPath);
      final doc = PdfDocument(inputBytes: bytes);
      final totalPages = doc.pages.count;

      for (int i = 0; i < totalPages; i++) {
        final page = doc.pages[i];
        final graphics = page.graphics;
        graphics.save();
        graphics.translateTransform(
            page.size.width / 2, page.size.height / 2);
        graphics.rotateTransform(-45 * 3.14159 / 180);
        graphics.drawString(
          text,
          PdfStandardFont(PdfFontFamily.helvetica, 40),
          brush: PdfBrushes.lightGray,
          bounds: Rect.fromLTWH(-150, 0, 300, 50),
        );
        graphics.restore();
      }

      final outBytes = doc.saveSync();
      doc.dispose();
      await _writeBytesInIsolate(outputPath, outBytes);

      return PdfToolResult(
        success: true,
        message: '水印添加成功，共 $totalPages 页',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '添加水印失败: $e');
    }
  }

  /// ---- PDF 压缩 ----
  static Future<PdfToolResult> compressPDF({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final bytes = await _readBytesInIsolate(inputPath);
      final doc = PdfDocument(inputBytes: bytes);
      final outBytes = doc.saveSync();
      doc.dispose();
      await _writeBytesInIsolate(outputPath, outBytes);

      final originalSize = await File(inputPath).length();
      final compressedSize = await File(outputPath).length();

      return PdfToolResult(
        success: true,
        message: '压缩完成，${(originalSize / 1024).toStringAsFixed(1)} KB → '
            '${(compressedSize / 1024).toStringAsFixed(1)} KB '
            '（减少 ${((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)}%）',
        outputPath: outputPath,
      );
    } catch (e) {
      return PdfToolResult(success: false, message: '压缩失败: $e');
    }
  }
}
