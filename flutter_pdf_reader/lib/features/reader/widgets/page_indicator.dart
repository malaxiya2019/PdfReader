import 'package:flutter/material.dart';

/// 页面指示器（控制栏隐藏时显示在右下角）
class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onTap;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '$currentPage / $totalPages',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
