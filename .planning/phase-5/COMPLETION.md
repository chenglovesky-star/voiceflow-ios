# Phase 5 — Export & Share (COMPLETED)

> Date: 2026-04-28

## Deliverables

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| `ExportService` (M4A/MP3/TXT/SRT/Markdown) | `VoiceFlow/ExportService.swift` | ✅ |
| `ShareSheet` UIActivityVC wrapper | `VoiceFlow/ShareSheet.swift` | ✅ |
| 详情页导出菜单 | `RecordingDetailView` Menu/Section | ✅ |
| SRT 时间戳格式 | `srtTime` 单测覆盖 ms 精度 | ✅ |
| Markdown 含元信息 + 时间戳锚点 | `markdownTranscript` 单测 | ✅ |

## 关键决策

- **MP3 不真正编码**：iOS 17+ 内置无 MP3 encoder，引 LAME 涉 license。改用 `AVAssetExportPresetAppleM4A` 在 .mp3 导出选项中实际产出 `.m4a`（AAC），所有目标 AI 平台都接受，避免 license。文档（Phase 5.1）保留 AudioToolbox 真 MP3 升级位。
- **`ExportContext` Sendable 值类型**：`RecordingEntity` 是 SwiftData `@Model`，非 Sendable，不能跨 actor。`ExportContext.from(entity)` 在 @MainActor 提取纯值后传给 service。
- **导出文件落到 `tmp/exports/`**：临时文件，share-sheet 用完不持久化，避免占用沙盒。

## DoD

- ✅ `BUILD SUCCEEDED` 0 warning
- ✅ **24/24 TEST SUCCEEDED**（+5 个 ExportService 测）

## 下一步

→ Phase 6: "Send to AI" URL Schemes
