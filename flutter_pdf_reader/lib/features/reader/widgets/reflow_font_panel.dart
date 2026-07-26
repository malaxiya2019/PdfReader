import 'package:flutter/material.dart';

/// Reflow 字体大小调节面板
class ReflowFontPanel extends StatelessWidget {
  final double reflowFontSize;
  final ValueChanged<double> onFontSizeChanged;
  final VoidCallback onRefresh;

  const ReflowFontPanel({
    super.key,
    required this.reflowFontSize,
    required this.onFontSizeChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      bottom: kToolbarHeight + 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.text_fields,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                onPressed: () => onFontSizeChanged(
                  (reflowFontSize - 2).clamp(12.0, 32.0),
                ),
              ),
              Text(
                '${reflowFontSize.toInt()}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                onPressed: () => onFontSizeChanged(
                  (reflowFontSize + 2).clamp(12.0, 32.0),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                onPressed: onRefresh,
                tooltip: '重新提取文本',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
