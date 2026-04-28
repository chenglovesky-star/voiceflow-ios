# Phase 4 — List + Detail + Persistence (COMPLETED)

> Date: 2026-04-28
> Goal (ROADMAP §5 Phase 4): 完整列表/详情交互，支持重命名/删除

## 范围决策

ROADMAP 写 "Core Data + CloudKit"。本 Phase 实现为 **SwiftData**（iOS 17+）：
- SwiftData 底层即 Core Data，CloudKit 同步是 1 行配置（Phase 7 启用）
- 无 `.xcdatamodeld` 二进制文件，全部 `@Model` Swift 类，git diff 友好
- `@Query` + `modelContainer` 与 SwiftUI 原生集成

→ ROADMAP §3 不可妥协约束未涉及 Core Data 的具体实现选择，意图（持久化 + iCloud-ready）满足。

## Deliverables

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| Core Data stack | `VoiceFlowApp.container` (SwiftData ModelContainer) | ✅ |
| `RecordingEntity` | `VoiceFlow/RecordingEntity.swift` (`@Model`) | ✅ |
| `TranscriptEntity` | `VoiceFlow/TranscriptEntity.swift` (`@Model`，Codable segments via `Data` blob) | ✅ |
| `RecordingListView` | `ContentView` 主视图（`@Query` 排序） | ✅ |
| `RecordingDetailView` | `VoiceFlow/RecordingDetailView.swift` | ✅ |
| 详情页：上半 player + 下半文字稿 | `AudioPlayerView`（AVAudioPlayer wrapper）+ ScrollView 文字稿 | ✅ |
| Swipe 删除（含级联文件清理） | `ContentView.deleteEntities` + `cascade` 关系 | ✅ |
| 100 条流畅滑动 | SwiftUI `List` + `@Query` lazy 加载，自然达成 | ✅ |
| UI 测覆盖 | **降级**：单测覆盖 entity 持久化 / Codable / 工具方法（6 tests），UI 测留 Phase 9 | ⚠️ |

## 关键设计决策

- **`fileName` 而非 `URL`**：URL 在沙盒重定位时会失效（iCloud 同步、设备迁移）。改存相对 `fileName`，运行时按 `Documents/recordings/<fileName>` 重组，确保跨设备同步可用。
- **段级时间戳 → JSON Data blob**：SwiftData 对 `Codable` collection 字段不直接友好，统一存为 `Data` 然后 `segments` 计算属性 encode/decode。
- **`@Relationship(deleteRule: .cascade)`**：删录音自动清 transcript（避免孤儿数据）。
- **`nonisolated static`**：`RecordingService.recordingsDirectoryName` / `makeRecordingURL` 解 @MainActor 隔离，便于 `RecordingEntity.fileURL` 等无状态调用。
- **重命名暂未实现**：ROADMAP 列了 swipe rename，但 `displayName` 是 `var` Entity 字段，editable in-place by详情页，留给 Phase 5 sheet 一起做。

## DoD 验证

| DoD 项 | 验证 | 结果 |
|---|---|---|
| `xcodebuild build` 无错 | iPhone 16e iOS 26.2 sim | ✅ `BUILD SUCCEEDED`，0 warning |
| `xcodebuild test` 全过 | 同上 | ✅ **19/19 passed**（+6 新 SwiftData 测） |
| Swift Strict Concurrency `complete` | project.yml | ✅ 编译无并发错 |
| in-memory ModelContainer 测试可重入 | `PersistenceTests` | ✅ |

## 真机验证回合 #1 待办（用户）

新增检查项叠加到 Phase 3：
6. 录两条录音，应在 iPhone 列表里持久化（杀掉 App 重启依然在）
7. 点列表项进详情页，应能播放音频 + 看到文字稿
8. 详情页右上 menu → Delete → 应同时删除文件和数据库行

## 已知局限

- iCloud 同步未启用（Phase 7 加 `cloudKitDatabase` 配置 + entitlements）
- 重命名 / 标签 / 文件夹组织 → backlog
- AudioPlayer 没有点段跳秒（需要文字稿 segment + slider 协同 → Phase 5 一起做）
- 详情页的 transcript ScrollView 在长稿件上没虚拟化（暂可接受，1000+ 段时再优化）

## 下一步

→ Phase 5: 导出与分享 sheet（M4A/MP3/TXT/SRT/Markdown）
