# All PDF Reader v1.3.0

## 简介

All PDF Reader 是一款专为 Android 手机设计的高颜值暗黑风 PDF 阅读器，
集阅读、文件管理、PDF 工具箱、扫描/OCR 和 AI 助手于一体。

## v1.3.0 更新亮点

### 📖 PDF 自适应阅读（核心重构）
- **自动适配屏幕宽度**：打开 PDF 后自动 Fit-to-Width，无需手动缩放
- **双击缩放切换**：双击页面在「适配宽度」和「适配页面」之间切换
- **文本重排（Reflow）**：点击顶部 `Aa` 按钮切换为流式文本视图
  - 可调节字号（14-32pt）
  - 自动提取 PDF 文本图层
  - 预缓存相邻页文本，翻页无等待
- **零手势冲突**：使用原始 Listener 事件捕获，与翻页/滚动完美共存

### 🛠 修复
- 修复 Syncfusion v28 API 兼容性
- 修复所有弃用 API 警告
- 修复 CI/CD 构建流程

## 功能

### 📖 PDF 阅读
- 流畅的 PDF 渲染（基于 Syncfusion PDF Viewer）
- Fit-to-Width / Fit-to-Page / 自由缩放
- 文本重排（Reflow）流式阅读
- 全屏模式 / 横屏支持
- 搜索 PDF 内容 + 页面跳转
- 阅读进度自动保存

### 📁 文件管理
- 自动扫描设备中的 PDF 文件
- 支持搜索、排序（名称/大小/日期）
- 收藏功能
- 书签管理

### 🛠 PDF 工具箱
- **PDF 合并**：合并多个 PDF 为一个
- **PDF 拆分**：按页范围或逐页拆分
- **PDF 转图片**：导出为 PNG/JPG
- **图片转 PDF**：多张图片合成 PDF
- **删除/旋转/提取页面**
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
- Material Design 3（深色/浅色/跟随系统）
- 流畅动画过渡
- 骨架屏加载

## 技术指标

| 项目 | 详情 |
|------|------|
| 最低 Android 版本 | Android 7.0 (API 21) |
| 目标 Android 版本 | Android 14 (API 35) |
| 架构 | ARM64 / ARM32 |
| 应用大小 | ~25 MB |
| 开发框架 | Flutter 3.27 + Syncfusion PDF Viewer v28 |
| 主题 | Material Design 3 |

## 下载

从 GitHub Releases 页面下载最新 APK 或 AAB。
