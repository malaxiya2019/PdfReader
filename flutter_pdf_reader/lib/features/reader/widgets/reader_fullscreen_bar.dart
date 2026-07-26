import 'package:flutter/material.dart';

/// 顶部控制栏（全屏模式）
class ReaderFullscreenBar extends StatelessWidget {
  final String fileName;
  final bool isReflowMode;
  final bool isBookmarked;
  final VoidCallback onBack;
  final VoidCallback onToggleViewMode;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleFullscreen;

  const ReaderFullscreenBar({
    super.key,
    required this.fileName,
    required this.isReflowMode,
    required this.isBookmarked,
    required this.onBack,
    required this.onToggleViewMode,
    required this.onToggleBookmark,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        color: Colors.black87,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, bottom: 8, left: 8, right: 8),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
          Expanded(child: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)),
          IconButton(icon: Icon(isReflowMode ? Icons.picture_as_pdf : Icons.text_fields, color: Colors.white70), onPressed: onToggleViewMode, tooltip: isReflowMode ? '原始视图' : '文本重排'),
          IconButton(
            icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200),
              child: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, key: ValueKey('fs_bm_$isBookmarked'), color: isBookmarked ? Colors.amber : Colors.white70)),
            onPressed: onToggleBookmark, tooltip: isBookmarked ? '删除书签' : '添加书签',
          ),
          IconButton(icon: const Icon(Icons.fullscreen_exit, color: Colors.white), onPressed: onToggleFullscreen, tooltip: '退出全屏'),
        ]),
      ),
    );
  }
}
