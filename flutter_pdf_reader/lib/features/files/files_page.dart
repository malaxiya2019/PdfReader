import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/pdf_file_info.dart';
import '../../services/pdf_scanner_service.dart';
import '../../router/app_router.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  List<PdfFileInfo> _allFiles = [];
  List<PdfFileInfo> _filteredFiles = [];
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  SortBy _sortBy = SortBy.date;
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scanFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanFiles() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final files = await PdfScannerService.scanAllCommonDirectories();
      if (mounted) {
        setState(() {
          _allFiles = files;
          _applyFilters();
          _isLoading = false;
          if (files.isEmpty) {
            _error = '未找到 PDF 文件\n请确认文件存在且权限已开启';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '扫描失败: $e';
        });
      }
    }
  }

  void _applyFilters() {
    _filteredFiles = PdfScannerService.searchFiles(_allFiles, _searchQuery);
    PdfScannerService.sortFiles(
      _filteredFiles,
      sortBy: _sortBy,
      ascending: _sortAscending,
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onSortChanged(SortBy? sortBy) {
    if (sortBy == null) return;
    setState(() {
      if (_sortBy == sortBy) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sortBy;
        _sortAscending = false;
      }
      _applyFilters();
    });
  }

  Future<void> _toggleFavorite(PdfFileInfo file) async {
    await PdfScannerService.toggleFavorite(file.path);
    setState(() {
      file.isFavorite = !file.isFavorite;
    });
  }

  void _openFile(PdfFileInfo file) {
    if (!File(file.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在或已被移动')),
      );
      _allFiles.removeWhere((f) => f.path == file.path);
      _applyFilters();
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
    final count = _filteredFiles.length;
    final total = _allFiles.length;

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜索 PDF 文件...',
              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey.withOpacity(0.6),
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.withOpacity(0.6), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E1E36),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Sort Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              // Sort buttons
              _buildSortChip(SortBy.date, Icons.access_time),
              const SizedBox(width: 8),
              _buildSortChip(SortBy.name, Icons.sort_by_alpha),
              const SizedBox(width: 8),
              _buildSortChip(SortBy.size, Icons.storage),
              const Spacer(),
              // Count
              Text(
                _searchQuery.isNotEmpty
                    ? '找到 $count / $total 个文件'
                    : '共 $total 个文件',
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFF2A2A2A)),

        // File List
        Expanded(
          child: _buildBody(theme),
        ),
      ],
    );
  }

  Widget _buildSortChip(SortBy sortBy, IconData icon) {
    final isSelected = _sortBy == sortBy;
    return GestureDetector(
      onTap: () => _onSortChanged(sortBy),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : const Color(0xFF1E1E36),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              sortBy.label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 2),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在扫描 PDF 文件...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error.isNotEmpty && _filteredFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off, size: 64, color: Colors.grey.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.withOpacity(0.6)),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: _scanFiles,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新扫描'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配的文件' : '暂无 PDF 文件',
              style: TextStyle(color: Colors.grey.withOpacity(0.6)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _scanFiles,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredFiles.length,
        itemBuilder: (context, index) {
          final file = _filteredFiles[index];
          return _buildFileItem(file, theme);
        },
      ),
    );
  }

  Widget _buildFileItem(PdfFileInfo file, ThemeData theme) {
    final exists = File(file.path).existsSync();
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: exists ? () => _openFile(file) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // PDF Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: exists
                      ? theme.colorScheme.primary.withOpacity(0.12)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: exists
                      ? theme.colorScheme.primary
                      : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // File Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          file.sizeFormatted,
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          file.dateFormatted,
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            file.folderName,
                            style: TextStyle(
                              color: Colors.grey.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Favorite Button
              IconButton(
                icon: Icon(
                  file.isFavorite ? Icons.star : Icons.star_border,
                  color: file.isFavorite
                      ? Colors.amber
                      : Colors.grey.withOpacity(0.4),
                  size: 22,
                ),
                onPressed: () => _toggleFavorite(file),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
