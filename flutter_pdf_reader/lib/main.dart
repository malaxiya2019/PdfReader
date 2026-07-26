import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'features/home/home_page.dart';
import 'features/files/files_page.dart';
import 'features/tools/tools_page.dart';
import 'services/ai/ai_factory.dart';
import 'services/thumbnail_cache_service.dart';
import 'services/permission_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 初始化 AI 服务
  AIFactory.init();

  // 初始化缩略图缓存（Phase 9 性能优化）
  ThumbnailCacheService.init();

  runApp(const AllPdfReaderApp());
}

class AllPdfReaderApp extends StatefulWidget {
  const AllPdfReaderApp({super.key});

  @override
  State<AllPdfReaderApp> createState() => _AllPdfReaderAppState();
}

class _AllPdfReaderAppState extends State<AllPdfReaderApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _permissionChecked = false;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _checkPermission();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getInt('theme_mode') ?? 0;
    if (mounted) {
      setState(() {
        _themeMode = ThemeMode.values[mode.clamp(0, 2)];
      });
    }
  }

  Future<void> _checkPermission() async {
    final granted = await PermissionService.requestStoragePermission();
    if (mounted) {
      setState(() {
        _permissionChecked = true;
        _permissionGranted = granted;
      });

      if (!granted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('需要存储权限'),
        content: const Text(
          'All PDF Reader 需要读取设备上的 PDF 文件。'
          '请在系统设置中授予「管理所有文件」权限。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openSettings();
            },
            child: const Text('前往设置'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _permissionGranted = true);
            },
            child: const Text('稍后'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    await PermissionService.openSettings();
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All PDF Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _permissionChecked
          ? MainShell(
              onThemeChanged: _setThemeMode,
              currentThemeMode: _themeMode,
            )
          : _buildSplashScreen(),
      onGenerateRoute: AppRouter.generateRoute,
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              'All PDF Reader',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentThemeMode;

  const MainShell({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    FilesPage(),
    ToolsPage(),
  ];

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '选择主题',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final mode in ThemeMode.values)
                ListTile(
                  leading: Icon(
                    AppTheme.themeModeIcon(mode),
                    color: mode == widget.currentThemeMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    AppTheme.themeModeName(mode),
                    style: TextStyle(
                      color: mode == widget.currentThemeMode
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      fontWeight: mode == widget.currentThemeMode
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: mode == widget.currentThemeMode
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    widget.onThemeChanged(mode);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey('page_$_currentIndex'),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '文件',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_fix_high_outlined),
            selectedIcon: Icon(Icons.auto_fix_high),
            label: '工具',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _showThemeSelector,
        tooltip: '主题切换',
        child: Icon(AppTheme.themeModeIcon(widget.currentThemeMode)),
      ),
    );
  }
}
