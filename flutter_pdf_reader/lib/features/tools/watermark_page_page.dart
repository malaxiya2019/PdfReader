import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_tool_service.dart';

class WatermarkPagePage extends StatefulWidget {
  const WatermarkPagePage({super.key});

  @override
  State<WatermarkPagePage> createState() => _WatermarkPagePageState();
}

class _WatermarkPagePageState extends State<WatermarkPagePage> {
  String? _filePath;
  final _textController = TextEditingController(text: 'CONFIDENTIAL');
  double _fontSize = 48;
  double _opacity = 0.3;
  Color _color = Colors.grey;
  bool _isProcessing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) setState(() => _filePath = path);
    }
  }

  Future<void> _apply() async {
    if (_filePath == null || _textController.text.trim().isEmpty) return;
    setState(() => _isProcessing = true);

    final outDir = await PdfToolService.getOutputDir();
    final name = PdfToolService.timestampFileName('watermarked_', 'pdf');
    final outPath = '${outDir.path}/$name';

    final result = await PdfToolService.addWatermark(
      inputPath: _filePath!,
      outputPath: outPath,
      text: _textController.text.trim(),
    );

    setState(() => _isProcessing = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (result.success) setState(() => _filePath = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('添加水印'), centerTitle: true),
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
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf, size: 20),
                ),
                title: Text(
                  _filePath?.split('/').last ?? '选择 PDF 文件',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _pickFile,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Watermark text
            Text('水印文字',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: '输入水印文字',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Font size
            Text('字体大小: ${_fontSize.toInt()}',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Slider(
              value: _fontSize,
              min: 12,
              max: 120,
              divisions: 108,
              label: '${_fontSize.toInt()}',
              onChanged: (v) => setState(() => _fontSize = v),
            ),
            const SizedBox(height: 8),

            // Opacity
            Text('透明度: ${(_opacity * 100).toInt()}%',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Slider(
              value: _opacity,
              min: 0.05,
              max: 1.0,
              divisions: 19,
              label: '${(_opacity * 100).toInt()}%',
              onChanged: (v) => setState(() => _opacity = v),
            ),
            const SizedBox(height: 8),

            // Color
            Text('颜色',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _colorChip(Colors.grey, '灰色'),
                _colorChip(Colors.red, '红色'),
                _colorChip(Colors.blue, '蓝色'),
                _colorChip(Colors.green, '绿色'),
                _colorChip(Colors.orange, '橙色'),
                _colorChip(Colors.purple, '紫色'),
                _colorChip(Colors.black, '黑色'),
                _colorChip(Colors.white, '白色'),
              ],
            ),
            const SizedBox(height: 32),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _filePath == null || _isProcessing ? null : _apply,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.water, size: 18),
                label: Text(_isProcessing ? '添加中...' : '添加水印'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorChip(Color color, String label) {
    final selected = _color.value == color.value;
    return GestureDetector(
      onTap: () => setState(() => _color = color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(selected ? 0.3 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  ThemeData get theme => Theme.of(context);
}
