import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../router/app_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, String>> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final filesJson = prefs.getStringList('recent_files') ?? [];
    setState(() {
      _recentFiles = filesJson.map((e) {
        final parts = e.split('|||');
        return {
          'path': parts[0],
          'name': parts.length > 1 ? parts[1] : 'Unknown',
          'time': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
    });
  }

  Future<void> _saveRecentFile(String path, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();

    // Remove duplicate
    _recentFiles.removeWhere((f) => f['path'] == path);
    _recentFiles.insert(0, {'path': path, 'name': name, 'time': now});
    if (_recentFiles.length > 20) {
      _recentFiles = _recentFiles.sublist(0, 20);
    }

    final filesJson = _recentFiles
        .map((f) => '${f['path']}|||${f['name']}|||${f['time']}')
        .toList();
    await prefs.setStringList('recent_files', filesJson);
    setState(() {});
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
        await _saveRecentFile(path, name);
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

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return DateFormat('MM/dd').format(dt);
    } catch (_) {
      return '';
    }
  }

  void _openRecentFile(Map<String, String> file) {
    final path = file['path'] ?? '';
    final name = file['name'] ?? 'Unknown';
    if (File(path).existsSync()) {
      Navigator.pushNamed(
        context,
        AppRouter.reader,
        arguments: {'path': path, 'name': name},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件不存在或已被移动')),
      );
      _recentFiles.removeWhere((f) => f['path'] == path);
      _saveRecentFileList();
      setState(() {});
    }
  }

  Future<void> _saveRecentFileList() async {
    final prefs = await SharedPreferences.getInstance();
    final filesJson = _recentFiles
        .map((f) => '${f['path']}|||${f['name']}|||${f['time']}')
        .toList();
    await prefs.setStringList('recent_files', filesJson);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('All PDF Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
            child: Column(
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All PDF Reader',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '高颜值暗黑风 PDF 阅读器',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Open File Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _pickAndOpenFile,
                    icon: const Icon(Icons.folder_open),
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

          // Recent Files Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '最近文件',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _recentFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 48,
                          color: Colors.grey.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无最近文件',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '点击上方按钮打开 PDF 文件',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _recentFiles.length,
                    itemBuilder: (context, index) {
                      final file = _recentFiles[index];
                      final name = file['name'] ?? '';
                      final time = _formatTime(file['time'] ?? '');
                      final exists = File(file['path'] ?? '').existsSync();
                      return Card(
                        color: theme.cardColor,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: exists
                                  ? theme.colorScheme.primary
                                  : Colors.grey,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            time,
                            style: TextStyle(
                              color: Colors.grey.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          trailing: exists
                              ? Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.withOpacity(0.5),
                                )
                              : Icon(
                                  Icons.error_outline,
                                  color: Colors.red.withOpacity(0.5),
                                  size: 18,
                                ),
                          onTap: exists
                              ? () => _openRecentFile(file)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
