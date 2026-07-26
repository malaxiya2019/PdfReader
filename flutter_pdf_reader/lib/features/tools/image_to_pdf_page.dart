import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_tool_service.dart';

class ImageToPdfPage extends StatefulWidget {
  const ImageToPdfPage({super.key});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  List<String> _selectedImages = [];
  bool _isProcessing = false;

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null && !_selectedImages.contains(file.path)) {
            _selectedImages.add(file.path!);
          }
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = _selectedImages[index];
        _selectedImages[index] = _selectedImages[index - 1];
        _selectedImages[index - 1] = temp;
      });
    }
  }

  void _moveDown(int index) {
    if (index < _selectedImages.length - 1) {
      setState(() {
        final temp = _selectedImages[index];
        _selectedImages[index] = _selectedImages[index + 1];
        _selectedImages[index + 1] = temp;
      });
    }
  }

  Future<void> _generate() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择至少一张图片'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final outName = PdfToolService.timestampFileName('images_', 'pdf');
    final outPath = '${outDir.path}/$outName';

    final result = await PdfToolService.imagesToPDF(
      imagePaths: _selectedImages,
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
      setState(() => _selectedImages.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('图片转 PDF'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 72,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '选择要转换为 PDF 的图片',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '支持 PNG、JPG、BMP、WebP',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _selectedImages.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _selectedImages.removeAt(oldIndex);
                        _selectedImages.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = _selectedImages[index];
                      return Card(
                        key: ValueKey(path),
                        color: theme.cardColor,
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(path),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 40,
                                height: 40,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                child: Icon(Icons.broken_image,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                              ),
                            ),
                          ),
                          title: Text(
                            path.split('/').last,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '第 ${index + 1} 页',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                IconButton(
                                  icon: Icon(Icons.arrow_upward,
                                      size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                  onPressed: () => _moveUp(index),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              if (index < _selectedImages.length - 1)
                                IconButton(
                                  icon: Icon(Icons.arrow_downward,
                                      size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                  onPressed: () => _moveDown(index),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              IconButton(
                                icon: Icon(Icons.close, size: 18,
                                    color: theme.colorScheme.error),
                                onPressed: () => _removeImage(index),
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
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('添加图片'),
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
                      onPressed: _isProcessing ? null : _generate,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf, size: 18),
                      label: Text(_isProcessing ? '生成中...' : '生成 PDF'),
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
}
