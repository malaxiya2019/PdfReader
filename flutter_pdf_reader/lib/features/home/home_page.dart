import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/pdf_file_info.dart';
import '../../services/pdf_scanner_service.dart';
import '../../router/app_router.dart';
import '../../core/app_logo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<PdfFileInfo> _recentFiles = const [];
  List<PdfFileInfo> _favoriteFiles = const [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final allFiles = await PdfScannerService.scanAllCommonDirectories();
      if (mounted) {
        setState(() {
          _recentFiles = allFiles.take(10).toList();
          _favoriteFiles =
              allFiles.where((f) => f.isFavorite).take(10).toList();
          _isLoading = false;
        });
        _fadeController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = '扫描失败: $e';
        });
      }
    }
  }

  Future<void> _forceRefresh() async {
    PdfScannerService.invalidateCache();
    await _loadData();
  }

  Future<void> _pickAndOpenFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        if (mounted) {
          Navigator.pushNamed(
            context,
            AppRouter.reader,
            arguments: {'path': path, 'name': name},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开文件失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openFile(PdfFileInfo file) {
    if (!File(file.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件不存在或已被移动'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRouter.reader,
      arguments: {'path': file.path, 'name': file.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All PDF Reader',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefresh,
            tooltip: '刷新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _forceRefresh,
        color: theme.colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 统一品牌 Logo
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const AppLogo(size: 72),
                ),
              ),
              const SizedBox(height: 8),

              // Open file button
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: 220,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: _pickAndOpenFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('打开 PDF 文件'),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              if (_isLoading)
                _buildShimmerLoading(theme)
              else if (_hasError)
                _buildErrorState(theme)
              else ...[
                if (_favoriteFiles.isNotEmpty) ...[
                  _buildSectionHeader('收藏文件', Icons.star, Colors.amber),
                  const SizedBox(height: 8),
                  for (int i = 0; i < _favoriteFiles.length; i++)
                    _buildAnimatedItem(
                      index: i,
                      child: _buildFileItem(_favoriteFiles[i], theme),
                    ),
                  const SizedBox(height: 24),
                ],

                _buildSectionHeader('最近文件', Icons.access_time, null),
                const SizedBox(height: 8),
                if (_recentFiles.isEmpty)
                  _buildEmptyState(theme)
                else
                  for (int i = 0; i < _recentFiles.length; i++)
                    _buildAnimatedItem(
                      index: i + _favoriteFiles.length,
                      child: _buildFileItem(_recentFiles[i], theme),
                    ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '共 ${_recentFiles.length} 个 PDF 文件',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color? iconColor) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon,
            size: 18,
            color: iconColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFileItem(PdfFileInfo file, ThemeData theme) {
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openFile(file),
        child: ListTile(
          dense: true,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, size: 20),
          ),
          title: Text(
            file.name,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${file.sizeFormatted} · ${file.dateFormatted}',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          trailing: Icon(Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3), size: 20),
        ),
      ),
    );
  }

  Widget _buildAnimatedItem({
    required int index,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildShimmerLoading(ThemeData theme) {
    return Column(
      children: [
        _buildSectionHeader('最近文件', Icons.access_time, null),
        const SizedBox(height: 8),
        for (int i = 0; i < 5; i++)
          Card(
            color: theme.cardColor,
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: _ShimmerWidget(
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                title: Container(
                  height: 12,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                subtitle: Container(
                  height: 10,
                  width: 100,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                trailing: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text('未找到 PDF 文件',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 16)),
            const SizedBox(height: 8),
            Text('点击上方按钮打开文件',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 13)),
            const SizedBox(height: 8),
            Text('或切换到"文件"标签扫描设备',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('加载失败',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(_errorMessage,
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _forceRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerWidget extends StatefulWidget {
  final Widget child;
  const _ShimmerWidget({required this.child});

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(opacity: _animation.value, child: child);
      },
      child: widget.child,
    );
  }
}
