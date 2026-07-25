import 'package:flutter/material.dart';
import 'merge_pdf_page.dart';
import 'split_pdf_page.dart';
import 'pdf_to_image_page.dart';
import 'image_to_pdf_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  static const _tools = <_ToolItem>[
    _ToolItem(
      title: 'PDF 合并',
      subtitle: '多个 PDF 合并为一个',
      icon: Icons.merge,
      color: Color(0xFF4CAF50),
      page: MergePdfPage(),
    ),
    _ToolItem(
      title: 'PDF 拆分',
      subtitle: '按页范围或逐页拆分',
      icon: Icons.call_split,
      color: Color(0xFFFF9800),
      page: SplitPdfPage(),
    ),
    _ToolItem(
      title: 'PDF 转图片',
      subtitle: '导出为 PNG / JPG',
      icon: Icons.image,
      color: Color(0xFF2196F3),
      page: PdfToImagePage(),
    ),
    _ToolItem(
      title: '图片转 PDF',
      subtitle: '多张图片合成 PDF',
      icon: Icons.picture_as_pdf,
      color: Color(0xFF9C27B0),
      page: ImageToPdfPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PDF 工具箱',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '实用工具',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '选择下方工具进行操作',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _tools.length,
                itemBuilder: (context, index) {
                  final tool = _tools[index];
                  return _buildToolCard(context, theme, tool);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, ThemeData theme, _ToolItem tool) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (tool.index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => tool.page,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tool.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    tool.icon,
                    color: tool.color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tool.title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tool.subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;

  const _ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });

  int get index => ToolsPage._tools.indexOf(this);
}
