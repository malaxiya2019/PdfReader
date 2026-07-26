import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import '../../services/pdf_tool_service.dart';

class SplitPdfPage extends StatefulWidget {
  const SplitPdfPage({super.key});

  @override
  State<SplitPdfPage> createState() => _SplitPdfPageState();
}

class _SplitPdfPageState extends State<SplitPdfPage> {
  String? _filePath;
  int _totalPages = 0;
  bool _isProcessing = false;
  int _splitMode = 0; // 0 = 范围, 1 = 逐页

  final TextEditingController _startCtrl = TextEditingController(text: '1');
  final TextEditingController _endCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

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
        _endCtrl.text = '$pages';
        _endCtrl.text = '$pages';
      });
    }
  }

  Future<void> _splitByRange() async {
    if (_filePath == null) return;

    final start = int.tryParse(_startCtrl.text) ?? 1;
    final end = int.tryParse(_endCtrl.text) ?? _totalPages;

    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final name = _fileName(_filePath!);
    final outName = '${name}_第${start}-${end}页.pdf';
    final outPath = '${outDir.path}/$outName';

    final result = await PdfToolService.splitPDF(
      inputPath: _filePath!,
      outputPath: outPath,
      startPage: start,
      endPage: end,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;
    _showResult(result);
  }

  Future<void> _splitAll() async {
    if (_filePath == null) return;

    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final dirPath = '${outDir.path}/${_fileName(_filePath!)}_逐页拆分';
    await Directory(dirPath).create(recursive: true);

    final result = await PdfToolService.splitPDFByPage(
      inputPath: _filePath!,
      outputDir: dirPath,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;
    _showResult(result);
  }

  void _showResult(PdfToolResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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
        title: const Text('PDF 拆分'),
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
                          color: theme.colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: theme.colorScheme.primary,
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

            const SizedBox(height: 24),

            if (_filePath != null) ...[
              Text('拆分方式', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('页码范围'),
                    icon: Icon(Icons.format_list_numbered),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('逐页拆分'),
                    icon: Icon(Icons.grid_view),
                  ),
                ],
                selected: {_splitMode},
                onSelectionChanged: (v) => setState(() => _splitMode = v.first),
              ),

              const SizedBox(height: 24),

              if (_splitMode == 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '起始页',
                          hintText: '1',
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        onChanged: (v) {
                          final p = int.tryParse(v);
                          if (p != null) _startCtrl.text = '$p';
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('—', style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 20,
                      )),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _endCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '结束页',
                          hintText: '$_totalPages',
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        onChanged: (v) {
                          final p = int.tryParse(v);
                          if (p != null) _endCtrl.text = '$p';
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '共 $_totalPages 页',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : _splitByRange,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.call_split, size: 18),
                    label: Text(_isProcessing ? '拆分中...' : '开始拆分'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ] else ...[
                Card(
                  color: theme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '将生成 $_totalPages 个独立 PDF 文件',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isProcessing ? null : _splitAll,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.call_split, size: 18),
                            label: Text(_isProcessing ? '拆分中...' : '开始逐页拆分'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
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
}
