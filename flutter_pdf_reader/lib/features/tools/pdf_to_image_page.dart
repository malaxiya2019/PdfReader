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
      });
    }
  }

  Future<void> _convert() async {
    if (_filePath == null) return;

    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final imgDir = Directory('${outDir.path}/${_fileName(_filePath!)}_图片导出');
    await imgDir.create(recursive: true);

    final format = _formats[_formatIndex];
    final result = await PdfToolService.pdfToImages(
      inputPath: _filePath!,
      outputDir: imgDir.path,
      imageFormat: format,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
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
            // File selection
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
                          color: Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.image,
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
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.folder_open,
                          color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    ],
                  ),
                ),
              ),
            ),

            if (_filePath != null) ...[
              const SizedBox(height: 24),
              Text('输出格式', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('PNG'), icon: Icon(Icons.image_outlined)),
                  ButtonSegment(value: 1, label: Text('JPG'), icon: Icon(Icons.image)),
                ],
                selected: {_formatIndex},
                onSelectionChanged: (v) => setState(() => _formatIndex = v.first),
              ),
              const SizedBox(height: 24),
              // 升级提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '功能提示',
                            style: TextStyle(
                              color: Colors.amber.shade200,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '当前 Syncfusion v24 不支持直接导出为图片。'
                            '导出将生成页面占位标记文件。'
                            '如需完整图片导出功能，请升级到 Syncfusion v25+。',
                            style: TextStyle(
                              color: Colors.amber.shade100.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _convert,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.image, size: 18),
                  label: Text(_isProcessing ? '导出中...' : '导出页面标记'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
