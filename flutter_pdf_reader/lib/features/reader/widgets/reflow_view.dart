import 'package:flutter/material.dart';

/// Reflow 文本重排视图
class ReflowView extends StatelessWidget {
  final bool reflowReady;
  final String reflowText;
  final double reflowFontSize;
  final VoidCallback onTap;

  const ReflowView({
    super.key,
    required this.reflowReady,
    required this.reflowText,
    required this.reflowFontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!reflowReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '正在提取文本...',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: kToolbarHeight + MediaQuery.of(context).padding.top + 80,
          bottom: kToolbarHeight + 80,
        ),
        child: SelectableText(
          reflowText,
          style: TextStyle(
            fontSize: reflowFontSize,
            color: theme.colorScheme.onSurface,
            height: 1.7,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
