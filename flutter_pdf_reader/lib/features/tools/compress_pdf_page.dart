import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_tool_service.dart';

class CompressPdfPage extends StatefulWidget {
  const CompressPdfPage({super.key});

  @override
  State<CompressPdfPage> createState() => _CompressPdfPageState();
}

class _CompressPdfPageState extends State<CompressPdfPage> {
  String? _filePath;
  int _quality = 5;
  bool _isProcessing = false;
  int? _originalSize;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        setState(() {
          _filePath = path;
          _originalSize = File(path).lengthSync();
        });
      }
    }
  }

  Future<void> _compress() async {
    if (_filePath == null) return;
    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final name = PdfToolService.timestampFileName('compressed_', 'pdf');
    final outPath = '${outDir.path}/$name';

    final result = await PdfToolService.compressPDF(
      inputPath: _filePath!,
      outputPath: outPath,
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
    if (result.success) setState(() => _filePath = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedEstimate = _originalSize != null
        ? '预计节省 ${_quality < 3 ? "5-10%" : _quality < 7 ? "10-20%" : "20-30%"}'
        : '';

    return Scaffold(
      appBar: AppBar(title: const Text('PDF 压缩'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File selection
            Card(
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.compress, size: 20),
                ),
                title: Text(
                  _filePath?.split('/').last ?? '选择 PDF 文件',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: _originalSize != null
                    ? Text(
                        _formatBytes(_originalSize!),
                        style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12),
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _pickFile,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quality slider
            Text('压缩强度',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _qualityLabel(),
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13),
            ),
            Slider(
              value: _quality.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_quality',
              onChanged: (v) => setState(() => _quality = v.round()),
            ),
            const SizedBox(height: 8),

            // Quality descriptions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('最小压缩',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 12)),
                Text('最大压缩',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 12)),
              ],
            ),

            if (savedEstimate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        savedEstimate,
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Compress button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _filePath == null || _isProcessing ? null : _compress,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.compress, size: 18),
                label: Text(_isProcessing ? '压缩中...' : '开始压缩'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              '通过移除冗余元数据减小 PDF 文件体积。',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _qualityLabel() {
    return switch (_quality) {
      1 => '轻度 - 仅移除元数据',
      2 => '轻度+',
      3 => '中等',
      4 => '中等+',
      5 => '标准',
      6 => '良好',
      7 => '较强',
      8 => '较强+',
      9 => '强力',
      10 => '最大压缩',
      _ => '标准',
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
