class PdfFileInfo {
  final String path;
  final String name;
  final int sizeInBytes;
  final DateTime lastModified;
  bool isFavorite;

  PdfFileInfo({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.lastModified,
    this.isFavorite = false,
  });

  String get sizeFormatted {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get dateFormatted {
    final now = DateTime.now();
    final diff = now.difference(lastModified);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${lastModified.year}-${_pad(lastModified.month)}-${_pad(lastModified.day)}';
  }

  String get folderName {
    final uri = Uri.file(path);
    final segments = uri.pathSegments;
    if (segments.length >= 2) {
      return segments[segments.length - 2];
    }
    return '/';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
