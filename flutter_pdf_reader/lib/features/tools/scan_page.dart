import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _picker = ImagePicker();
  File? _imageFile;
  String? _ocrResult;
  bool _isProcessing = false;
  bool _isEnhanced = false;
  bool _isGray = false;

  Future<void> _pickFromCamera() async {
    final xFile = await _picker.pickImage(source: ImageSource.camera);
    if (xFile != null) {
      setState(() {
        _imageFile = File(xFile.path);
        _ocrResult = null;
        _isEnhanced = false;
        _isGray = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      setState(() {
        _imageFile = File(xFile.path);
        _ocrResult = null;
        _isEnhanced = false;
        _isGray = false;
      });
    }
  }

  Future<void> _enhanceImage() async {
    if (_imageFile == null) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await _imageFile!.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('无法解码图片');

      // 自动裁剪（去除四周空白）
      final cropped = _autoCrop(image);

      // 对比度增强（自适应直方图均衡化简化版）
      final enhanced = _enhanceContrast(cropped);

      // 保存增强后的图片
      final outBytes = img.encodeJpg(enhanced, quality: 90);
      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(outBytes);

      setState(() {
        _imageFile = File(outPath);
        _isEnhanced = true;
        _isGray = false;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('增强失败: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _toGrayscale() async {
    if (_imageFile == null) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await _imageFile!.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('无法解码图片');

      final gray = img.grayscale(image);
      final outBytes = img.encodeJpg(gray, quality: 90);
      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/gray_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(outBytes);

      setState(() {
        _imageFile = File(outPath);
        _isGray = true;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转灰度失败: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  img.Image _autoCrop(img.Image src) {
    // 自动裁剪四周空白（像素值 > 240 的视为空白）
    final threshold = 240;
    int? top, bottom, left, right;

    // Find top
    for (int y = 0; y < src.height; y++) {
      bool allWhite = true;
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        if (p.r < threshold || p.g < threshold || p.b < threshold) {
          allWhite = false;
          break;
        }
      }
      if (!allWhite) { top = y; break; }
    }

    // Find bottom
    for (int y = src.height - 1; y >= 0; y--) {
      bool allWhite = true;
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        if (p.r < threshold || p.g < threshold || p.b < threshold) {
          allWhite = false;
          break;
        }
      }
      if (!allWhite) { bottom = y; break; }
    }

    // Find left
    for (int x = 0; x < src.width; x++) {
      bool allWhite = true;
      for (int y = 0; y < src.height; y++) {
        final p = src.getPixel(x, y);
        if (p.r < threshold || p.g < threshold || p.b < threshold) {
          allWhite = false;
          break;
        }
      }
      if (!allWhite) { left = x; break; }
    }

    // Find right
    for (int x = src.width - 1; x >= 0; x--) {
      bool allWhite = true;
      for (int y = 0; y < src.height; y++) {
        final p = src.getPixel(x, y);
        if (p.r < threshold || p.g < threshold || p.b < threshold) {
          allWhite = false;
          break;
        }
      }
      if (!allWhite) { right = x; break; }
    }

    top ??= 0;
    bottom ??= src.height - 1;
    left ??= 0;
    right ??= src.width - 1;

    // 加 10px 边距防止裁剪过度
    final margin = 10;
    final cropX = (left - margin).clamp(0, src.width - 1);
    final cropY = (top - margin).clamp(0, src.height - 1);
    final cropW = (right - left + margin * 2).clamp(1, src.width - cropX);
    final cropH = (bottom - top + margin * 2).clamp(1, src.height - cropY);

    return img.copyCrop(src, x: cropX, y: cropY, width: cropW, height: cropH);
  }

  img.Image _enhanceContrast(img.Image src) {
    // 简单对比度增强：线性拉伸
    int minR = 255, maxR = 0, minG = 255, maxG = 0, minB = 255, maxB = 0;

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        if (p.r < minR) minR = p.r.toInt();
        if (p.r > maxR) maxR = p.r.toInt();
        if (p.g < minG) minG = p.g.toInt();
        if (p.g > maxG) maxG = p.g.toInt();
        if (p.b < minB) minB = p.b.toInt();
        if (p.b > maxB) maxB = p.b.toInt();
      }
    }

    final dst = img.Image.from(src);
    final rangeR = (maxR - minR).toDouble();
    final rangeG = (maxG - minG).toDouble();
    final rangeB = (maxB - minB).toDouble();

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final r = (rangeR > 0 ? ((p.r - minR) / rangeR * 255).round().clamp(0, 255) : p.r).toInt();
        final g = (rangeG > 0 ? ((p.g - minG) / rangeG * 255).round().clamp(0, 255) : p.g).toInt();
        final b = (rangeB > 0 ? ((p.b - minB) / rangeB * 255).round().clamp(0, 255) : p.b).toInt();
        dst.setPixelRgb(x, y, r, g, b);
      }
    }

    return dst;
  }

  Future<void> _runOCR() async {
    if (_imageFile == null) return;
    setState(() => _isProcessing = true);

    try {
      final inputImage = InputImage.fromFile(_imageFile!);
      final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      final recognizedText = await recognizer.processImage(inputImage);
      await recognizer.close();

      setState(() {
        _ocrResult = recognizedText.text;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR 识别失败: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _exportSearchablePDF() async {
    if (_imageFile == null || _ocrResult == null || _ocrResult!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先识别文字后再导出'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final imageBytes = await _imageFile!.readAsBytes();
      final doc = PdfDocument();
      final page = doc.pages.add();
      final pageSize = page.getClientSize();

      // 1. 添加扫描图片到页面
      final pdfImage = PdfBitmap(imageBytes);
      final imgAspect = pdfImage.width / pdfImage.height;
      final pageAspect = pageSize.width / pageSize.height;

      double drawW, drawH;
      if (imgAspect > pageAspect) {
        drawW = pageSize.width;
        drawH = pageSize.width / imgAspect;
      } else {
        drawH = pageSize.height;
        drawW = pageSize.height * imgAspect;
      }
      final x = (pageSize.width - drawW) / 2;
      final y = (pageSize.height - drawH) / 2;

      page.graphics.drawImage(pdfImage, Rect.fromLTWH(x, y, drawW, drawH));

      // 2. 添加不可见文本层（用于搜索）
      final hiddenFont = PdfStandardFont(PdfFontFamily.helvetica, 1);
      final hiddenBrush = PdfSolidBrush(PdfColor(255, 255, 255));

      // 将 OCR 结果按分行写入不可见文本
      final lines = _ocrResult!.split('\n');
      double textY = y + 10;
      final lineHeight = drawH / (lines.length + 1).clamp(1, 999);

      for (final line in lines) {
        if (line.trim().isEmpty) {
          textY += lineHeight;
          continue;
        }
        page.graphics.drawString(
          line.trim(),
          hiddenFont,
          brush: hiddenBrush,
          bounds: Rect.fromLTWH(x + 5, textY, drawW - 10, lineHeight),
        );
        textY += lineHeight;
      }

      final outBytes = await doc.save();
      doc.dispose();

      final outDir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${outDir.path}/PDF_Scan');
      if (!await pdfDir.exists()) await pdfDir.create(recursive: true);
      final outPath = '${pdfDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(outPath).writeAsBytes(outBytes);

      setState(() => _isProcessing = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('可搜索 PDF 已导出'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: '打开', onPressed: () {
            // TODO: 用阅读器打开
          }),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('扫描 / OCR'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            if (_imageFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 300,
                    color: theme.cardColor,
                    child: const Center(child: Text('无法预览图片')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_isEnhanced)
                    _badge('已增强', theme.colorScheme.primary),
                  if (_isGray)
                    _badge('灰度', theme.colorScheme.secondary),
                  const Spacer(),
                  Text(
                    '${_imageFile!.lengthSync() ~/ 1024} KB',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            if (_imageFile == null) ...[
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.document_scanner,
                        size: 72,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                    const SizedBox(height: 16),
                    Text('扫描文档或选择图片进行 OCR',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 15)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _actionCard(
                          icon: Icons.camera_alt,
                          label: '拍照',
                          color: theme.colorScheme.primary,
                          onTap: _pickFromCamera,
                        ),
                        const SizedBox(width: 16),
                        _actionCard(
                          icon: Icons.photo_library,
                          label: '相册',
                          color: theme.colorScheme.secondary,
                          onTap: _pickFromGallery,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Image processing buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toolChip(Icons.enhance_photo_translate, '图像增强', _isProcessing ? null : _enhanceImage),
                  _toolChip(Icons.filter_b_and_w, '转灰度', _isProcessing ? null : _toGrayscale),
                  _toolChip(Icons.text_snippet, '识别文字 (OCR)', _isProcessing ? null : _runOCR),
                  _toolChip(Icons.camera_alt, '重拍', _isProcessing ? null : _pickFromCamera),
                  _toolChip(Icons.photo_library, '选择', _isProcessing ? null : _pickFromGallery),
                ],
              ),
              const SizedBox(height: 16),

              // OCR result
              if (_ocrResult != null) ...[
                Row(
                  children: [
                    Icon(Icons.text_fields, size: 18,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('OCR 识别结果',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${_ocrResult!.length} 字符',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    _ocrResult!,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 14,
                        height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),

                // Export searchable PDF
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : _exportSearchablePDF,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text(_isProcessing ? '导出中...' : '导出可搜索 PDF'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _toolChip(IconData icon, String label, VoidCallback? onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}
