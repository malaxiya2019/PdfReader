import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/pdf_file_info.dart';
import '../../services/pdf_scanner_service.dart';
import '../../router/app_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<PdfFileInfo> _recentFiles = [];
  List<PdfFileInfo> _favoriteFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allFiles = await PdfScannerService.scanAllCommonDirectories();
      if (mounted) {
        setState(() {
          // 最近文件：按时间取前10个
          _recentFiles = allFiles.take(10).toList();
          // 收藏文件
          _favoriteFiles = allFiles.where((f) => f.isFavorite).take(10).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndOpenFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
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
          SnackBar(content: Text('打开文件失败: $e')),
        );
      }
    }
  }

  void _openFile(PdfFileInfo file) {
    if (!File(file.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在或已被移动')),
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
        title: const Text('All PDF Reader'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo & Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 36,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All PDF Reader',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '高颜值暗黑风 PDF 阅读器',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _pickAndOpenFile,
                        icon: const Icon(Icons.folder_open, size: 20),
                        label: const Text('打开 PDF 文件'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Favorites Section
                if (_favoriteFiles.isNotEmpty) ...[
                  _buildSectionHeader('⭐ 收藏文件', Icons.star, Colors.amber),
                  const SizedBox(height: 8),
                  ..._favoriteFiles.map(
                    (f) => _buildRecentItem(f, theme),
                  ),
                  const SizedBox(height: 24),
                ],

                // Recent Files Section
                _buildSectionHeader('📄 最近文件', Icons.access_time, null),
                const SizedBox(height: 8),
                if (_recentFiles.isEmpty)
                  _buildEmptyState(theme)
                else
                  ..._recentFiles.map(
                    (f) => _buildRecentItem(f, theme),
                  ),

                const SizedBox(height: 16),

                // Stats
                Center(
                  child: Text(
                    '已扫描 ${_recentFiles.length + (_favoriteFiles.isNotEmpty ? _favoriteFiles.length : 0)} 个 PDF 文件',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.4),
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
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentItem(PdfFileInfo file, ThemeData theme) {
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.picture_as_pdf_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          file.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${file.sizeFormatted} · ${file.dateFormatted}',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.withOpacity(0.4),
          size: 20,
        ),
        onTap: () => _openFile(file),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '未找到 PDF 文件',
              style: TextStyle(color: Colors.grey.withOpacity(0.6)),
            ),
            const SizedBox(height: 4),
            Text(
              '点击上方按钮打开文件，或切换到"文件"标签扫描',
              style: TextStyle(
                color: Colors.grey.withOpacity(0.4),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
