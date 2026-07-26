import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import '../../services/pdf_tool_service.dart';

class PdfToImagePage extends StatefulWidget {
  const PdfToImagePage({super.key});

  @override
  State<PdfToImagePage> createState() => _PdfToImagePageState();
}

class _PdfToImagePageState extends State<PdfToImagePage> {
  String? _filePath;
  int _totalPages = 0;
  bool _isProcessing = false;
  int _formatIndex = 0; // 0 = PNG, 1 = JPG
  bool _saveToGallery = true;
  String? _exportPath;
  int? _exportedCount;
  final List<String> _formats = ['png', 'jpg'];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final bytes = await File(path).readAsBytes();
      final doc = pdf.PdfDocument(inputBytes: bytes);
      final pages = doc.pages.count;
      doc.dispose();

      setState(() {
        _filePath = path;
        _totalPages = pages;
        _exportPath = null;
        _exportedCount = null;
      });
    }
  }

  Future<void> _convert() async {
    if (_filePath == null) return;

    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final imgDir = Directory('${outDir.path}/${_fileName(_filePath!)}_images');
    await imgDir.create(recursive: true);

    final format = _formats[_formatIndex];
    final result = await PdfToolService.pdfToImages(
      inputPath: _filePath!,
      outputDir: imgDir.path,
      imageFormat: format,
      saveToGallery: _saveToGallery,
    );

    setState(() {
      _isProcessing = false;
      if (result.success) {
        _exportPath = imgDir.path;
        _exportedCount = result.exportedCount;
      }
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(result.message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _fileName(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  IconData _formatIcon(String fmt) {
    return fmt == 'png' ? Icons.image_outlined : Icons.image;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 转图片'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 文件选择 ──
            Card(
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickFile,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _filePath != null
                                  ? _filePath!.split('/').last
                                  : '选择 PDF 文件',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_filePath != null)
                              Text(
                                '$_totalPages 页',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.folder_open,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ),
            ),

            if (_filePath != null) ...[
              const SizedBox(height: 24),

              // ── 输出格式 ──
              Text('输出格式', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('PNG'),
                    icon: Icon(Icons.image_outlined),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('JPG'),
                    icon: Icon(Icons.image),
                  ),
                ],
                selected: {_formatIndex},
                onSelectionChanged: (v) =>
                    setState(() => _formatIndex = v.first),
              ),

              const SizedBox(height: 24),

              // ── 渲染质量信息 ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade300, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formats[_formatIndex].toUpperCase()} 高清导出',
                            style: TextStyle(
                              color: Colors.blue.shade200,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formats[_formatIndex] == 'png'
                                ? '无损 PNG (透明通道支持)'
                                : '高质量 JPG (92% 品质, 文件更小)',
                            style: TextStyle(
                              color: Colors.blue.shade100.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── 保存到相册开关 ──
              Card(
                color: theme.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SwitchListTile(
                    title: const Text('保存到相册'),
                    subtitle: Text(
                      '图片将保存到 Pictures/AllPDFReader/ 目录',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    secondary: Icon(
                      Icons.photo_album_outlined,
                      color: _saveToGallery
                          ? Colors.amber.shade300
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    value: _saveToGallery,
                    onChanged: (v) => setState(() => _saveToGallery = v),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── 导出按钮 ──
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _convert,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _formatIcon(_formats[_formatIndex]),
                          size: 18,
                        ),
                  label: Text(
                    _isProcessing
                        ? '导出中 ($_totalPages 页)...'
                        : '导出为 ${_formats[_formatIndex].toUpperCase()} 图片',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15),
                  ),
                ),
              ),

              // ── 导出结果 ──
              if (_exportPath != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '导出成功',
                              style: TextStyle(
                                color: Colors.green.shade300,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '共 $_exportedCount 页，保存至:',
                              style: TextStyle(
                                color: Colors.green.shade100.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _saveToGallery
                                    ? '📁 相册: Pictures/AllPDFReader/'
                                    : '📁 $_exportPath',
                                style: TextStyle(
                                  color: Colors.green.shade100,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
