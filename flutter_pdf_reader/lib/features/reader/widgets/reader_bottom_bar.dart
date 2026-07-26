import 'package:flutter/material.dart';

class ReaderBottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final double currentZoom;
  final bool isFullscreen;
  final bool isReflowMode;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onToggleZoomFit;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final VoidCallback onPageJump;

  const ReaderBottomBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.currentZoom,
    required this.isFullscreen,
    required this.isReflowMode,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onToggleZoomFit,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onPageJump,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: isFullscreen ? _buildFullscreenBar(context) : _buildNormalBar(context),
    );
  }

  Widget _buildNormalBar(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      color: t.cardColor.withOpacity(0.97),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          if (!isReflowMode)
            IconButton(icon: const Icon(Icons.zoom_out), color: t.colorScheme.onSurface.withOpacity(0.6),
              onPressed: onZoomOut, tooltip: '缩小'),
          if (!isReflowMode)
            IconButton(icon: const Icon(Icons.fit_screen), color: t.colorScheme.primary.withOpacity(0.7),
              onPressed: onToggleZoomFit, tooltip: '适配屏幕', iconSize: 20),
          IconButton(icon: const Icon(Icons.chevron_left), color: t.colorScheme.onSurface,
            onPressed: currentPage > 1 ? onPrevPage : null),
          GestureDetector(
            onTap: onPageJump,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: t.colorScheme.onSurface.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_stories, size: 14, color: t.colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text('$currentPage / $totalPages', style: TextStyle(color: t.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), color: t.colorScheme.onSurface,
            onPressed: currentPage < totalPages ? onNextPage : null),
          if (!isReflowMode)
            IconButton(icon: const Icon(Icons.zoom_in), color: t.colorScheme.onSurface.withOpacity(0.6),
              onPressed: onZoomIn, tooltip: '放大'),
        ]),
      )),
    );
  }

  Widget _buildFullscreenBar(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8, top: 8, left: 16, right: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.zoom_out, color: Colors.white70), onPressed: onZoomOut),
        IconButton(icon: const Icon(Icons.fit_screen, color: Colors.white70), onPressed: onToggleZoomFit, tooltip: '适配屏幕'),
        IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: currentPage > 1 ? onPrevPage : null),
        GestureDetector(
          onTap: onPageJump,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$currentPage / $totalPages', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: currentPage < totalPages ? onNextPage : null),
        IconButton(icon: const Icon(Icons.zoom_in, color: Colors.white70), onPressed: onZoomIn),
      ]),
    );
  }
}
