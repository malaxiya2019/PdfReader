# All PDF Reader v1.0.0

## 简介

All PDF Reader 是一款专为 Android 手机设计的高颜值暗黑风 PDF 阅读器，
集阅读、文件管理、PDF 工具箱、扫描/OCR 和 AI 助手于一体。

## 功能

### 📖 PDF 阅读
- 流畅的 PDF 渲染（基于 Syncfusion PDF Viewer）
- 上下滚动 / 翻页 / 双指缩放
- 全屏模式 / 横屏支持
- 搜索 PDF 内容
- 页面跳转

### 📁 文件管理
- 自动扫描设备中的 PDF 文件
- 支持搜索、排序（名称/大小/日期）
- 收藏功能
- 阅读记录（自动保存进度）
- 书签管理

### 🛠 PDF 工具箱
- **PDF 合并**：合并多个 PDF 为一个
- **PDF 拆分**：按页范围或逐页拆分
- **PDF 转图片**：导出为 PNG/JPG
- **图片转 PDF**：多张图片合成 PDF
- **删除页面**：删除指定页面
- **旋转页面**：90°/180°/270° 旋转
- **提取页面**：提取指定页面为新 PDF
- **添加水印**：文字水印
- **PDF 压缩**：减小文件体积

### 📷 扫描/OCR
- 调用摄像头拍照
- 自动裁剪 + 图像增强
- 中文/英文 OCR（基于 Google ML Kit）
- 输出可搜索 PDF

### 🤖 AI 助手
- **云端模式**：OpenAI/DeepSeek 兼容 API
  - PDF 智能总结
  - PDF 问答（对话式）
  - 中英翻译
- **本地模式**：提取式摘要（无需网络）

### 🎨 界面设计
- Material Design 3
- 深色/浅色/跟随系统 主题切换
- 流畅动画过渡
- 骨架屏加载

## 性能优化 (v1.0.0)

- 异步文件扫描（不阻塞 UI）
- 3 秒扫描缓存（避免重复遍历）
- 内存缓存 + 防抖批量写入（SharedPreferences 优化）
- LRU 缩略图磁盘缓存（最大 50MB）
- Isolate 隔离大文件 I/O 操作

## 技术指标

| 项目 | 详情 |
|------|------|
| 最低 Android 版本 | Android 7.0 (API 21) |
| 目标 Android 版本 | Android 14 (API 34) |
| 架构 | ARM64 / ARM32 |
| 应用大小 | ~25 MB |
| 开发框架 | Flutter 3.22 |
| 主题 | Material Design 3 |

## 已知问题

1. PDF 转图片功能对含大量图片的文档可能较慢
2. 本地 AI 模式仅支持提取式摘要，不支持生成式 AI
3. 大文件（>100MB）合并操作建议在 Wi-Fi 环境下进行

## 致谢

- Syncfusion Flutter PDF Viewer
- Google ML Kit
- OpenAI / DeepSeek API

---

下载 APK：GitHub Releases → all-pdf-reader-v1.0.0.apk
