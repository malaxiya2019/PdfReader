import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_tool_service.dart';

class MergePdfPage extends StatefulWidget {
  const MergePdfPage({super.key});

  @override
  State<MergePdfPage> createState() => _MergePdfPageState();
}

class _MergePdfPageState extends State<MergePdfPage> {
  List<String> _selectedFiles = [];
  bool _isProcessing = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null && !_selectedFiles.contains(file.path)) {
            _selectedFiles.add(file.path!);
          }
        }
      });
    }
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = _selectedFiles[index];
        _selectedFiles[index] = _selectedFiles[index - 1];
        _selectedFiles[index - 1] = temp;
      });
    }
  }

  void _moveDown(int index) {
    if (index < _selectedFiles.length - 1) {
      setState(() {
        final temp = _selectedFiles[index];
        _selectedFiles[index] = _selectedFiles[index + 1];
        _selectedFiles[index + 1] = temp;
      });
    }
  }

  Future<void> _merge() async {
    if (_selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择至少两个 PDF 文件'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final outName = PdfToolService.timestampFileName('merged_', 'pdf');
    final outPath = '${outDir.path}/$outName';

    final result = await PdfToolService.mergePDFs(
      inputPaths: _selectedFiles,
      outputPath: outPath,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: result.success
            ? SnackBarAction(
                label: '打开',
                onPressed: () {
                  // TODO: 用阅读器打开
                },
              )
            : null,
      ),
    );

    if (result.success) {
      setState(() => _selectedFiles.clear());
    }
  }

  String _shortName(String path) {
    final name = path.split('/').last;
    return name.length > 30 ? '${name.substring(0, 27)}...' : name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 合并'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // File list
          Expanded(
            child: _selectedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 72,
                          color: theme.colorScheme.onSurface.withOpacity(0.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '选择要合并的 PDF 文件',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '至少选择 2 个文件',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _selectedFiles.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _selectedFiles.removeAt(oldIndex);
                        _selectedFiles.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = _selectedFiles[index];
                      return Card(
                        key: ValueKey(path),
                        color: theme.cardColor,
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            _shortName(path),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatSize(File(path).lengthSync()),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                IconButton(
                                  icon: Icon(Icons.arrow_upward,
                                      size: 18, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                  onPressed: () => _moveUp(index),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              if (index < _selectedFiles.length - 1)
                                IconButton(
                                  icon: Icon(Icons.arrow_downward,
                                      size: 18, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                  onPressed: () => _moveDown(index),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              IconButton(
                                icon: Icon(Icons.close, size: 18,
                                    color: theme.colorScheme.error),
                                onPressed: () => _removeFile(index),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加文件'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : _merge,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.merge, size: 18),
                      label: Text(_isProcessing ? '合并中...' : '开始合并'),
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
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
