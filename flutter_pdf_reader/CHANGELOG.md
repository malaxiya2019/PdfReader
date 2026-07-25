# Changelog

## Phase 9 — 性能优化 (2026-07-25)

### 优化内容

#### 1. PDF 文件扫描加速
- **异步遍历**：`dir.list()` 替代 `dir.listSync()`，大目录不再卡 UI
- **3秒内存缓存**：重复调用不重新扫描磁盘，下拉刷新才清缓存
- **扫描时间缓存**：`PdfScannerService._cache` + `_lastScanTime`

#### 2. 内存缓存减少 I/O 磨损
- **ReadingRecordService**：首次加载 → 内存驻留，后续操作不读 SharedPreferences
- **BookmarkService**：同上，全量加载后内存缓存
- **防抖批量写入**：500ms 内连续修改合并为一次磁盘写入

#### 3. 缩略图缓存系统
- **新增 ThumbnailCacheService**：LRU 磁盘缓存
- **最大 50MB**，超限自动淘汰最久未访问
- 按文件路径哈希存储，元数据持久化

#### 4. 重操作 Isolate 化
- **大文件 I/O 分离**：>50MB 的文件读取/写入在 `Isolate.run()` 中执行
- **PdfToolService**：所有 save/read 改用 `_readBytesInIsolate` / `_writeBytesInIsolate`
- 预检查文件大小，超大文件提前提示

#### 5. UI 层微优化
- 首页 `forceRefresh` 清除缓存后重扫
- 各页面 `late final` 声明 AnimationController
- 骨架屏 `const` 优化

### 性能预期
| 场景 | 优化前 | 优化后 |
|------|--------|--------|
| 首次扫描 100 个 PDF | 200-500ms 卡顿 | 异步不卡 UI |
| 切换 Tab 重建页面 | 重新扫描磁盘 | 缓存命中 <1ms |
| 保存阅读记录 | 全量 JSON 序列化 + 写磁盘 | 内存写入 + 防抖 |
| 操作 50MB+ PDF | 主线程阻塞 | Isolate 后台处理 |

## Phase 8 — AI PDF 助手
- 云端 API 总结/问答/翻译
- 本地提取式摘要/关键词问答
- AI 配置页面（OpenAI/DeepSeek 切换）
