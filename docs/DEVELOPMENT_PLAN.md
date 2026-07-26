# All PDF Reader 开发计划书 v1.1

## 项目定位
开发一款 Android 手机端高颜值 PDF 阅读器。

**定位：** PDF阅读器 + 文件管理 + PDF工具箱 + 扫描/OCR + AI助手

**优先保证：**
- 稳定
- 流畅
- 手机体验
- 低内存占用
- 可持续扩展

---

## 技术栈（严格锁定，禁止自动升级）

| 组件 | 版本 | 说明 |
|------|------|------|
| Flutter SDK | 3.24.5 | LTS稳定版，不追3.27 |
| Dart | 3.5.4 | 随Flutter锁定 |
| Syncfusion PDF Viewer | 26.1.35 | 最后一个稳定API版本 |
| 目标平台 | Android API 21+ | Android 5.0及以上 |

**依赖管理铁律：**
- `pubspec.yaml` 中所有依赖使用**精确版本号**（如 `syncfusion_flutter_pdfviewer: 26.1.35`）
- **禁止使用 `^` 前缀**
- 如需新增依赖，必须先评估：Android兼容性、包体积、是否有更轻量替代
- 禁止执行 `flutter pub upgrade`，只允许 `flutter pub get`

---

## 已知技术约束（Codex 必须遵守）

1. **Syncfusion `toImage()` / `exportAsImage()` 是付费API**，免费版不可用。
   - Phase 5 的「PDF转图片」功能必须使用纯 Dart 方案：`pdf` package + `image` package，不依赖 Syncfusion。
2. **GitHub Actions 构建需要预埋签名配置**（Phase 0 完成）。
3. **所有功能面向 Android 手机**，不考虑平板/桌面/Web适配。

---

## 项目目录结构

```
lib/
├── main.dart
├── core/
│   ├── constants/
│   ├── utils/
│   ├── extensions/
│   └── widgets/
├── theme/
│   └── app_theme.dart
├── router/
│   └── app_router.dart
├── models/
├── services/
├── providers/
└── features/
    ├── home/
    ├── reader/
    ├── files/
    ├── tools/
    ├── scan/
    └── ai/
```

---

## 开发规则（Codex 必须遵守）

1. **所有功能必须面向 Android 手机。**
2. **不破坏已有功能。** 修改前检查现有代码，修改后验证相关功能。
3. **每次只完成当前阶段任务。** 禁止跳阶段、禁止一次开发全部功能。
4. **禁止大规模重构。** 单文件修改不超过 100 行，单 commit 只做一件事。
5. **修改前先检查项目结构。** 按目录规范存放代码。
6. **完成后执行 `flutter analyze`。**
7. **修复所有 warning。**
8. **保持 Material Design 3。**
9. **保持 Dark Theme 为默认主题，同时支持 Light/System。**
10. **代码必须模块化。** 禁止把业务逻辑写在 UI 文件里（Widget 只负责展示，逻辑抽离到 Service/Provider）。
11. **每完成一个阶段更新 `CHANGELOG.md`。**
12. **每个阶段必须保证 GitHub Actions 可以构建 APK。**

---

## 阶段规划

### Phase 0：项目初始化
**目标：** 建立基础工程，确保能构建出APK。

**任务：**
- 创建 Flutter 项目
- 配置 Android（minSdk 21，targetSdk 34）
- 配置 Material3 + 主题系统（Dark默认）
- 配置路由（go_router）
- 配置 GitHub Actions（构建 Debug APK）
- 创建目录结构
- 创建 `AGENTS.md`

**验收：**
- ✅ `flutter analyze` 0 error，0 warning
- ✅ GitHub Actions 生成 APK 成功
- ✅ 手机安装后能打开，显示首页

---

### Phase 1：手机 PDF 阅读 MVP
**目标：** 完成第一个可用版本，能打开并阅读PDF。

**功能：**
- 首页：Logo、最近文件列表、打开文件按钮、工具入口占位
- PDF 打开：文件选择（file_picker）、PDF 加载（Syncfusion）
- 阅读功能：
  - 上下滚动
  - 翻页
  - 双指缩放
  - 全屏切换
  - 横屏适配

**验收：**
- ✅ 手机安装APK，可以打开PDF并流畅阅读
- ✅ `flutter analyze` 通过
- ✅ GitHub Actions 构建成功

---

### Phase 2：文件管理系统
**目标：** 成为手机文件管理型PDF应用。

**功能：**
- 自动扫描手机PDF文件：
  - Download
  - Documents
  - 微信文件（Android/data/com.tencent.mm/... 需适配）
  - QQ文件
- PDF 列表展示
- 搜索、排序（名称/大小/时间）
- 最近打开记录
- 收藏功能

**验收：**
- ✅ 打开APP自动看到手机中的PDF文件
- ✅ 可以搜索和排序
- ✅ `flutter analyze` 通过

---

### Phase 3：阅读增强
**功能：**
- 阅读记录（保存：文件路径、页码、时间、阅读进度百分比）
- 书签（添加、删除、列表）
- PDF 目录/大纲（章节跳转）
- 文本搜索（PDF内部搜索，Syncfusion自带）

**验收：**
- ✅ 重新打开PDF恢复到上次阅读位置
- ✅ 书签功能正常
- ✅ 目录可点击跳转
- ✅ 搜索可高亮结果

---

### Phase 4：UI高级优化
**目标：** 达到商业APP体验。

**优化：**
- Material 动画（页面切换、Hero动画）
- 空状态设计
- 加载动画（Skeleton）
- 错误提示（SnackBar/Toast）
- 主题切换：Dark / Light / System

**验收：**
- ✅ 动画流畅不卡顿
- ✅ 空状态美观
- ✅ 主题切换正常

---

### Phase 5：PDF工具箱
**功能：**
- PDF 合并（多个PDF → 新PDF）
- PDF 拆分（按页范围、单页拆分）
- PDF 转图片（⚠️ 使用 `pdf` + `image` 纯Dart方案，**禁止**使用Syncfusion付费API）
  - 支持 PNG、JPG 输出
- 图片转PDF（多图片 → PDF，支持排序）

**验收：**
- ✅ 合并/拆分/转图片/图片转PDF 功能可用
- ✅ 生成文件可在手机文件管理器中查看
- ✅ `flutter analyze` 通过

---

### Phase 6：PDF编辑功能
**功能：**
- 删除页面
- 旋转页面
- 提取页面（单独保存为新PDF）
- 添加水印（文字/图片水印）
- PDF 压缩（降低DPI/质量）

---

### Phase 7：扫描/OCR
**手机特色功能。**

**功能：**
- 扫描：调用摄像头、自动裁剪、图像增强
- OCR：支持中文/英文识别
- 输出：可搜索PDF（PDF with text layer）

---

### Phase 8：AI PDF助手
**功能：**
- AI 按钮入口（🤖 AI助手）
- PDF 总结（生成摘要、重点）
- PDF 问答（针对文档内容问答）
- 翻译（中英互译）

**注意：** AI功能需要预留接口，具体LLM接入在Phase 8再实现。

---

### Phase 9：性能优化
**重点针对手机优化：**

- 大PDF加载优化（>100MB）
- 内存管理（及时释放资源）
- 缓存机制（缩略图缓存、阅读进度缓存）
- 后台任务（大文件处理时不卡UI）
- 测试基准：
  - 10MB PDF：秒开
  - 100MB PDF：3秒内打开
  - 500MB PDF：不闪退，可阅读

---

### Phase 10：发布版本
**完成：**
- 单元测试、Widget测试
- CI 流程完善：
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk`
  - `flutter build appbundle`
- 发布 v1.0.0
- 生成 APK + AAB
- Release Notes

---

## Codex 执行顺序（严格）

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 9 → Phase 10
```

**禁止：**
- 跳阶段
- 一次开发多个阶段
- 修改无关模块
- 升级依赖版本

---

## 每阶段完成格式

Codex 输出必须包含：

```markdown
## 完成报告

**阶段：** Phase X

**完成内容：**
- xxx
- xxx

**测试：**
- flutter analyze: ✅ / ❌
- 手动测试: ✅ / ❌

**APK构建：**
- GitHub Actions: ✅ / ❌

**变更文件：**
- `lib/xxx/xxx.dart`
- `pubspec.yaml`（如有）

**下一阶段：** Phase X+1
```

---

## 紧急制动规则

如果 Codex 在执行过程中遇到以下情况，必须停止并报告，不得擅自处理：

1. `flutter analyze` 出现超过 5 个 error
2. 需要修改超过 3 个现有文件才能实现当前任务
3. 发现需要升级依赖版本才能继续
4. 发现现有代码结构无法容纳新功能（需要重构）
5. Syncfusion API 行为与预期不符

报告格式：

```markdown
## ⚠️ 阻塞报告

**阶段：** Phase X

**问题：** xxx

**影响：** xxx

**建议方案：**
1. xxx
2. xxx

**需要用户决策：** 请选择方案或提供指导
```

---

## 特殊约束（红线规则）

### Syncfusion PDF 限制
- Syncfusion Flutter PDF Viewer 免费版**没有** `toImage()` / `exportAsImage()` API
- Phase 5 的「PDF转图片」必须使用纯 Dart 方案（`pdf` package + `image` package）
- **禁止**尝试调用 Syncfusion 的付费 API，否则会在编译期或运行期报错

### GitHub Actions
- 每次推送到 `main` 或 `develop` 分支必须能构建成功
- Phase 0 已配置好 CI，后续阶段**不要破坏** `.github/workflows/build.yml`

### 文件扫描限制
- Android 11+（API 30+）有分区存储限制
- 扫描微信/QQ文件时，优先使用 SAF（Storage Access Framework）或 `path_provider` + `permission_handler`
- **不要假设有 root 权限**

---

## 禁止行为（红线）

以下行为一旦发现，立即回滚：

1. ❌ **升级 Flutter SDK 版本**
2. ❌ **升级 Syncfusion 版本**
3. ❌ **使用 `^` 前缀管理依赖**
4. ❌ **单 commit 修改超过 5 个文件**
5. ❌ **在 Widget 里写业务逻辑**（超过 20 行的逻辑必须抽离）
6. ❌ **跳阶段开发**（如 Phase 1 没完成就做 Phase 3）
7. ❌ **修改 `AGENTS.md` 或 `DEVELOPMENT_PLAN.md` 的内容**
8. ❌ **删除已有功能代码**（除非计划书明确说明替换）

---

## 阻塞处理

遇到以下情况，**停止开发，输出阻塞报告**：

1. `flutter analyze` 出现超过 5 个 error 且无法快速修复
2. 需要修改 5 个以上现有文件才能实现当前小功能
3. 依赖包冲突或 API 行为与文档不符
4. 需要重构目录结构才能继续

### 阻塞报告格式

```markdown
## ⚠️ 阻塞报告

**阶段：** Phase X

**问题描述：**
xxx

**影响范围：**
xxx

**尝试过的方案：**
1. xxx — 结果：失败/部分有效
2. xxx — 结果：失败/部分有效

**需要用户决策：**
请选择：
A. 方案一
B. 方案二
C. 其他方案（请说明）
```
