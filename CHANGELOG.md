# Changelog

## [1.0.0] - 2026-07-25

### Phase 0: 项目初始化 ✅
- Flutter 3.22.3 项目结构搭建
- Material Design 3 暗黑主题系统
- 路由系统
- 首页：Logo + 打开PDF按钮 + 最近文件（静态）
- GitHub Actions CI/CD：自动构建APK并上传

### Phase 1: 手机 PDF 阅读 MVP ✅
- 新增 Syncfusion PDF Viewer 依赖
- PDF 阅读页面：
  - 上下滚动/翻页（SfPdfViewer 原生支持）
  - 双指缩放
  - 全屏模式
  - 横屏支持
  - 页码指示器
  - 上下页导航按钮
- 首页升级：
  - 文件选择器（FilePicker）打开PDF
  - 最近文件列表（SharedPreferences 持久化）
  - 文件存在性检查
  - 时间显示（刚刚/X分钟前/X天前）
