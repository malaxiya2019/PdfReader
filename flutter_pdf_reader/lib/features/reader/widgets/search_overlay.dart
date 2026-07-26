import 'package:flutter/material.dart';

/// 搜索覆盖层
class SearchOverlay extends StatelessWidget {
  final bool isFullscreen;
  final TextEditingController searchController;
  final bool searchInitialized;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const SearchOverlay({
    super.key,
    required this.isFullscreen,
    required this.searchController,
    required this.searchInitialized,
    required this.onSearch,
    required this.onClear,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Positioned(
      top: isFullscreen ? (MediaQuery.of(context).padding.top + 56) : 0,
      left: 0, right: 0,
      child: Material(
        color: t.cardColor,
        elevation: 4,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Padding(
            padding: EdgeInsets.only(top: isFullscreen ? 0 : MediaQuery.of(context).padding.top + 4, left: 12, right: 12, bottom: 8),
            child: Row(children: [
              Expanded(child: TextField(
                controller: searchController,
                autofocus: true,
                style: TextStyle(color: t.colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索 PDF 内容...',
                  hintStyle: TextStyle(color: t.colorScheme.onSurface.withOpacity(0.4), fontSize: 14),
                  filled: true,
                  fillColor: t.colorScheme.onSurface.withOpacity(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), color: t.colorScheme.onSurface.withOpacity(0.5), onPressed: onClear)
                      : null,
                ),
                onSubmitted: (_) => onSearch(searchController.text),
                onChanged: (_) => onSearch(searchController.text),
              )),
              const SizedBox(width: 8),
              if (searchInitialized)
                Text('使用搜索面板导航', style: TextStyle(color: t.colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
              IconButton(icon: const Icon(Icons.close, size: 20), color: t.colorScheme.onSurface.withOpacity(0.5), onPressed: onClose),
            ]),
          ),
        ),
      ),
    );
  }
}
