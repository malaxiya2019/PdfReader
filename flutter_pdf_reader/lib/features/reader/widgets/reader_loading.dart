import 'package:flutter/material.dart';

/// PDF 加载中指示器
class ReaderLoading extends StatelessWidget {
  const ReaderLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '正在加载 PDF...',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
