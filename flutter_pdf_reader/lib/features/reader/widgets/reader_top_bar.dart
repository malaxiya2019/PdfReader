import 'package:flutter/material.dart';

class ReaderTopBar extends StatelessWidget {
  final String fileName;
  final bool isReflowMode;
  final bool isZoomFitWidth;
  final bool isBookmarked;
  final String zoomLabel;
  final VoidCallback onBack;
  final VoidCallback onToggleViewMode;
  final VoidCallback onToggleZoomFit;
  final VoidCallback onSearch;
  final VoidCallback onShowBookmarks;
  final VoidCallback onToggleBookmark;
  final VoidCallback onOpenAI;
  final VoidCallback onToggleFullscreen;

  const ReaderTopBar({
    super.key,
    required this.fileName,
    required this.isReflowMode,
    required this.isZoomFitWidth,
    required this.isBookmarked,
    required this.zoomLabel,
    required this.onBack,
    required this.onToggleViewMode,
    required this.onToggleZoomFit,
    required this.onSearch,
    required this.onShowBookmarks,
    required this.onToggleBookmark,
    required this.onOpenAI,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        color: t.cardColor.withOpacity(0.97),
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, bottom: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back), color: t.colorScheme.onSurface, onPressed: onBack),
            Expanded(child: Text(fileName, style: TextStyle(color: t.colorScheme.onSurface, fontSize: 16), overflow: TextOverflow.ellipsis)),
            IconButton(icon: Icon(isReflowMode ? Icons.picture_as_pdf : Icons.text_fields), color: t.colorScheme.primary, onPressed: onToggleViewMode, tooltip: isReflowMode ? '原始视图' : '文本重排'),
            if (!isReflowMode)
              IconButton(icon: const Icon(Icons.fit_screen), color: isZoomFitWidth ? t.colorScheme.primary : t.colorScheme.onSurface.withOpacity(0.7), onPressed: onToggleZoomFit, tooltip: isZoomFitWidth ? '适配页面' : '适配宽度'),
            IconButton(icon: const Icon(Icons.search), color: t.colorScheme.onSurface.withOpacity(0.7), onPressed: onSearch, tooltip: '搜索'),
            IconButton(icon: const Icon(Icons.bookmark_outline), color: t.colorScheme.onSurface.withOpacity(0.7), onPressed: onShowBookmarks, tooltip: '书签列表'),
            IconButton(
              icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200),
                child: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, key: ValueKey('bm_$isBookmarked'), color: isBookmarked ? Colors.amber : null)),
              onPressed: onToggleBookmark, tooltip: isBookmarked ? '删除书签' : '添加书签',
            ),
            IconButton(icon: const Icon(Icons.auto_awesome), color: t.colorScheme.onSurface.withOpacity(0.7), onPressed: onOpenAI, tooltip: 'AI 助手'),
            IconButton(icon: const Icon(Icons.fullscreen), color: t.colorScheme.onSurface.withOpacity(0.7), onPressed: onToggleFullscreen, tooltip: '全屏'),
          ]),
          if (!isReflowMode)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(isZoomFitWidth ? Icons.arrow_left : Icons.fullscreen, size: 12, color: t.colorScheme.primary.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(zoomLabel, style: TextStyle(color: t.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w500)),
            ])),
        ]),
      ),
    );
  }
}
