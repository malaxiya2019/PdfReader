# All PDF Reader 开发计划书 v1.0

## 项目定位
开发一款 Android 手机端高颜值 PDF 阅读器。

定位：
- PDF阅读器
- 文件管理
- PDF工具箱
- 扫描/OCR
- AI助手

优先保证：
- 稳定
- 流畅
- 手机体验
- 低内存占用
- 可持续扩展

## 开发规则（Codex 必须遵守）

### AGENTS.md 内容
你是 All PDF Reader 项目的主开发者。

### 开发要求
1. 所有功能必须面向 Android 手机。
2. 不破坏已有功能。
3. 每次只完成当前阶段任务。
4. 禁止大规模重构。
5. 修改前先检查项目结构。
6. 完成后执行 flutter analyze。
7. 修复所有 warning。
8. 保持 Material Design 3。
9. 保持 Dark Theme。
10. 代码必须模块化。
11. 每完成一个阶段更新 CHANGELOG。
12. 每个阶段必须保证 GitHub Actions 可以构建 APK。

## Phase 0：项目初始化
目标：建立基础工程。

任务：
- 创建 Flutter 项目
- 配置 Android
- 配置 Material3
- 配置主题系统
- 配置路由
- 配置 GitHub Actions

目录：
```
lib/
├── core/
├── theme/
├── router/
├── models/
├── services/
├── features/
│   ├── home/
│   ├── reader/
│   ├── files/
│   └── tools/
└── main.dart
```

验收：
- ✅ flutter analyze通过
- ✅ GitHub Actions生成APK

## Phase 1：手机 PDF 阅读 MVP
目标：完成第一个可用版本。

功能：
- 首页（Logo、最近文件、打开文件按钮、工具入口）
- PDF打开（文件选择、PDF加载、阅读页面）
- 阅读功能（上下滚动、翻页、双指缩放、全屏、横屏）

验收：手机安装APK，可以打开PDF并阅读。

## Phase 2：文件管理系统
目标：成为手机文件管理型PDF应用。

功能：
- 扫描：Download、Documents、微信文件、QQ文件
- PDF列表、搜索、排序、文件大小、修改时间
- 最近打开、收藏

验收：打开APP自动看到手机PDF。

## Phase 3：阅读增强
功能：
- 阅读记录（文件、页码、时间、阅读进度）
- 书签（添加书签、删除书签）
- PDF目录（章节跳转）
- 文本搜索（PDF内部搜索）

## Phase 4：UI高级优化
目标：达到商业APP体验。

优化：
- Material动画、页面切换、空状态、加载动画、错误提示
- 主题：Dark、Light、System

## Phase 5：PDF工具箱
功能：
- PDF合并（多个PDF输入，新PDF输出）
- PDF拆分（页范围、单页拆分）
- PDF转图片（PNG、JPG）
- 图片转PDF（多图片、排序）

## Phase 6：PDF编辑功能
功能：
- 删除页面、旋转页面、提取页面
- 添加水印、PDF压缩

## Phase 7：扫描/OCR
功能：
- 扫描（调用摄像头、自动裁剪、图像增强）
- OCR（中文、英文）
- 输出可搜索PDF

## Phase 8：AI PDF助手
功能：
- AI按钮：🤖 AI助手
- PDF总结（摘要、重点）
- PDF问答
- 翻译（中文、英文）

## Phase 9：性能优化
优化：
- 大PDF加载、内存、缓存、缩略图、后台任务
- 测试：10MB PDF、100MB PDF、500MB PDF

## Phase 10：发布版本
完成：
- 测试（单元测试、Widget测试）
- CI（flutter pub get → flutter analyze → flutter test → flutter build apk → flutter build appbundle）
- 发布：v1.0.0（APK、AAB、Release Notes）

## Codex执行顺序
严格按阶段顺序执行，禁止跳阶段、一次开发全部功能、修改无关模块。

每阶段完成格式：
```
## 完成报告

阶段：Phase X

完成：
- xxx
- xxx

测试：
flutter analyze ✅

APK：
GitHub Actions ✅

下一阶段：
Phase X+1
```
