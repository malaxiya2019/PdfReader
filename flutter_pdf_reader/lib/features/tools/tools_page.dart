import 'package:flutter/material.dart';
import 'merge_pdf_page.dart';
import 'split_pdf_page.dart';
import 'pdf_to_image_page.dart';
import 'image_to_pdf_page.dart';
import 'delete_page_page.dart';
import 'rotate_page_page.dart';
import 'extract_page_page.dart';
import 'watermark_page_page.dart';
import 'compress_pdf_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  static const _utilities = <_ToolItem>[
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

  static const _edits = <_ToolItem>[
    _ToolItem(
      title: '删除页面',
      subtitle: '移除指定页面',
      icon: Icons.auto_delete,
      color: Color(0xFFE53935),
      page: DeletePagePage(),
    ),
    _ToolItem(
      title: '旋转页面',
      subtitle: '90°/180°/270° 旋转',
      icon: Icons.rotate_right,
      color: Color(0xFF42A5F5),
      page: RotatePagePage(),
    ),
    _ToolItem(
      title: '提取页面',
      subtitle: '提取指定页为新 PDF',
      icon: Icons.content_copy,
      color: Color(0xFF66BB6A),
      page: ExtractPagePage(),
    ),
    _ToolItem(
      title: '添加水印',
      subtitle: '文字水印/自定义样式',
      icon: Icons.water,
      color: Color(0xFFAB47BC),
      page: WatermarkPagePage(),
    ),
    _ToolItem(
      title: 'PDF 压缩',
      subtitle: '减小文件体积',
      icon: Icons.compress,
      color: Color(0xFF78909C),
      page: CompressPdfPage(),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 实用工具 ----
            Row(
              children: [
                Icon(Icons.build_outlined,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  '实用工具',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'PDF 转换与处理工具',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _utilities.length,
              itemBuilder: (context, index) {
                return _ToolCard(
                  tool: _utilities[index],
                  index: index,
                  isFirstSection: true,
                );
              },
            ),

            const SizedBox(height: 28),

            // ---- 编辑工具 ----
            Row(
              children: [
                Icon(Icons.edit_outlined,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  '编辑工具',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'PDF 页面编辑与优化',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _edits.length,
              itemBuilder: (context, index) {
                return _ToolCard(
                  tool: _edits[index],
                  index: index,
                  isFirstSection: false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final _ToolItem tool;
  final int index;
  final bool isFirstSection;

  const _ToolCard({
    required this.tool,
    required this.index,
    required this.isFirstSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delay = isFirstSection ? index * 100 : (index + 4) * 100;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + delay),
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
              MaterialPageRoute(builder: (_) => tool.page),
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
                  child: Icon(tool.icon, color: tool.color, size: 28),
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
}
