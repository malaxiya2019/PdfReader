# Changelog

## Phase 10 — v1.0.0 发布版本 (2026-07-25)

### 新增
- **品牌 Logo**：统一的 `AppLogo` 组件，首页/启动页/关于页复用
- **Android 自适应图标**：矢量 drawable 图标（深色底 + PDF 文档 + 播放按钮）
- **SVG 品牌标识**：`assets/logo.svg`
- **启动页**：`SplashLogo` 全屏动画启动页
- **Release Notes**：`RELEASE_NOTES.md`

### 测试
- `test/models/pdf_file_info_test.dart` — 模型单元测试（6 cases）
- `test/services/pdf_scanner_service_test.dart` — 排序/搜索/标签测试（9 cases）
- `test/services/reading_record_test.dart` — 阅读记录序列化测试（4 cases）

### CI/CD
- GitHub Actions 分 3 阶段：`test-and-analyze` → `build-apk` → `release`
- 新增 `flutter test` 测试步骤
- 标签推送自动触发 Release 构建（APK + AAB）
- Release 自动发布到 GitHub Releases

### 构建产物
- `all-pdf-reader-debug.apk` — Debug 版本（每次 push）
- `all-pdf-reader-release.apk` — Release 版本（仅 tag）
- `all-pdf-reader-release.aab` — App Bundle（仅 tag）

## Phase 9 — 性能优化
- 异步文件扫描（`list()` 替代 `listSync()`）
- 3秒扫描缓存
- 内存缓存 + 防抖批量写入（ReadingRecord/Bookmark）
- LRU 缩略图磁盘缓存（50MB）
- Isolate 大文件 I/O

## Phase 8 — AI PDF 助手
- 云端 API 总结/问答/翻译
- 本地提取式摘要/关键词问答
- AI 配置页面（OpenAI/DeepSeek 切换）
