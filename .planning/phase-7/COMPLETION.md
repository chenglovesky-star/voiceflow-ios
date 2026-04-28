# Phase 7 — Settings + iCloud Stub (COMPLETED)

> Date: 2026-04-28

## 范围决策

ROADMAP §5 Phase 7 列了 "iCloud 同步 + 设置页"。本 Phase 实现：
- ✅ 设置页（采样率 / 比特率 / iCloud 开关 / 关于）
- ⚠️ iCloud 同步**仅作开关 stub**——实际 CloudKit container provisioning 留 Phase 10 上架准备时做（需 Developer Portal 操作）

理由：CloudKit container 注册需要 Apple Developer Portal 手工操作 + entitlements 文件 + 真机签名。在没有这些前置条件下集成 cloudKitDatabase 会让 build 在某些 CI 环境失败。开关 stub + 文档化"启用方法"是更安全的渐进路径。

## Deliverables

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| `SettingsView`（4 个开关 + 关于） | `VoiceFlow/SettingsView.swift` | ✅ |
| 默认录音格式 / 采样率 | `AppSettings.defaultSampleRate / defaultBitRate` Picker | ✅ |
| iCloud 开关 | Toggle + 文档说明 | ✅ |
| ContentView 工具栏入口 | `gearshape` toolbar item | ✅ |
| `CloudKitSync.swift` (实际) | **stub**（待 Phase 10 启用） | ⚠️ |
| 实体添加 `CKRecord` 元数据 | **延后**（SwiftData CloudKit 是 ModelConfiguration 一行配置，不需要改实体） | ✅ via SwiftData |
| 首次启动 onboarding | **降级**（onboardingComplete flag 已埋点，UI 待 Phase 9 / 10）| ⚠️ |

## 关键决策

- **`AppSettings`** 接受注入 `UserDefaults`，便于单元测试用独立 suite，避免污染 .standard。
- **`@ObservationIgnored`** 标注 defaults 引用，避免它进入 @Observable 的可观察图。
- **iCloud 启用未真接 SwiftData**：避免 build 时 entitlements 错误。代码注释 + README 给"启用 3 步骤"。

## DoD

- ✅ `BUILD SUCCEEDED` 0 warning
- ✅ **29/29 TEST SUCCEEDED**（+2 AppSettings 测）

## iCloud 真启用三步（Phase 10 前置）

1. Apple Developer Portal → Identifiers → 加 iCloud container `iCloud.com.lei.voiceflow`
2. 添加 `VoiceFlow.entitlements`，含 `com.apple.developer.icloud-services=CloudDocuments` + `com.apple.developer.ubiquity-container-identifiers=[iCloud.com.lei.voiceflow]`
3. `VoiceFlowApp.container` 加 `cloudKitDatabase: .private("iCloud.com.lei.voiceflow")` 到 `ModelConfiguration`

## 下一步

→ Phase 8: WhisperKit fallback (iOS 17-25)
