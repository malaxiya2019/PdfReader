import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../services/pdf_tool_service.dart';

class ExtractPagePage extends StatefulWidget {
  const ExtractPagePage({super.key});

  @override
  State<ExtractPagePage> createState() => _ExtractPagePageState();
}

class _ExtractPagePageState extends State<ExtractPagePage> {
  String? _filePath;
  int _totalPages = 0;
  final Set<int> _selectedPages = {};
  bool _isProcessing = false;
  bool _loaded = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        final doc = PdfDocument(inputBytes: bytes);
        setState(() {
          _filePath = path;
          _totalPages = doc.pages.count;
          _selectedPages.clear();
          _loaded = true;
        });
        doc.dispose();
      }
    }
  }

  Future<void> _extract() async {
    if (_filePath == null || _selectedPages.isEmpty) return;
    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final name = PdfToolService.timestampFileName('extracted_', 'pdf');
    final outPath = '${outDir.path}/$name';

    final result = await PdfToolService.extractPages(
      inputPath: _filePath!,
      outputPath: outPath,
      pageNumbers: _selectedPages.toList(),
    );

    setState(() => _isProcessing = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (result.success) {
      setState(() {
        _filePath = null;
        _totalPages = 0;
        _selectedPages.clear();
        _loaded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('提取页面'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: _loaded ? _buildPageSelector(theme) : _buildEmptyState(theme),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text(_loaded ? '重新选择' : '选择 PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_loaded)
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed:
                            _selectedPages.isEmpty || _isProcessing ? null : _extract,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.content_copy, size: 18),
                        label: Text(_isProcessing
                            ? '提取中...'
                            : '提取 ${_selectedPages.length} 页'),
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.file_copy_outlined, size: 72,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text('选择要提取页面的 PDF',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPageSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(_filePath?.split('/').last ?? '',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$_totalPages 页',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('选择要提取的页面（点击选择）',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedPages.length == _totalPages) {
                      _selectedPages.clear();
                    } else {
                      _selectedPages.addAll(
                          List.generate(_totalPages, (i) => i + 1));
                    }
                  });
                },
                child: Text(
                    _selectedPages.length == _totalPages ? '取消全选' : '全选'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: _totalPages,
            itemBuilder: (context, index) {
              final pageNum = index + 1;
              final selected = _selectedPages.contains(pageNum);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedPages.remove(pageNum);
                    } else {
                      _selectedPages.add(pageNum);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.secondary.withValues(alpha: 0.15)
                        : theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.outline.withValues(alpha: 0.2),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$pageNum',
                          style: TextStyle(
                              color: selected
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.onSurface,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 18)),
                      if (selected) ...[
                        const SizedBox(height: 4),
                        Icon(Icons.check_circle,
                            color: theme.colorScheme.secondary, size: 16),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
