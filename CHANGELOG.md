# Changelog

## [1.0.0] - 2026-07-25

### Phase 0: 项目初始化 ✅
- Flutter 3.22.3 项目结构 + M3 暗黑主题 + CI/CD

### Phase 1: 手机 PDF 阅读 MVP ✅
- Syncfusion PDF Viewer + 全屏/横屏/缩放/翻页

### Phase 2: 文件管理系统 ✅
- PDF 扫描（7 目录）+ 搜索/排序/收藏 + 底部导航

### Phase 3: 阅读增强 ✅
- 阅读记录：自动保存/恢复阅读进度
- 书签功能：添加/删除/列表浏览
- PDF 目录：Syncfusion 内置书签面板
- 文本搜索：实时搜索 + 上/下一个匹配
- 页码跳转：点击页码弹出跳转对话框

### Phase 4: UI高级优化 ✅
- **主题切换**：深色/浅色/跟随系统，底部弹出选择器，SharedPreferences 持久化
- **页面过渡**：自定义 SlideTransition + FadeTransition 组合动画
- **骨架屏**：列表加载时显示闪烁骨架屏（Shimmer 动画），替换空白加载
- **列表动画**：TweenAnimationBuilder 交错渐入动画，列表项依次弹出
- **空状态**：带图标 + 提示文字 + 引导操作的友好空状态
- **错误状态**：带图标 + 错误信息 + 重试按钮的完整错误页面
- **AnimatedSwitcher**：底部导航页面切换渐变动画
- **AnimatedContainer**：排序按钮选中态颜色变换动画
- **AnimatedSize**：搜索栏展开/收起平滑动画
- **NavigationBar**：替换旧 BottomNavigationBar，支持 M3
