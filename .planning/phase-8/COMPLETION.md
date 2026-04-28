# Phase 8 — WhisperKit Fallback (COMPLETED, stub)

> Date: 2026-04-28

## 范围决策

ROADMAP §5 Phase 8 规划"完整 WhisperKit 集成 (iOS 17-25 fallback)"。本 Phase 实现为 **stub + 工厂**：
- **当前主路径 SFSpeechRecognizer 已经支持 iOS 10+**（含 17-25），覆盖率 OK，没必要立即引入 ~150MB WhisperKit 模型 + SPM 依赖
- 工厂模式 + Stub 留出"按需启用"的位置——真机验证回合 #1 若发现某 locale SFSpeechRecognizer 不可用，`Phase 8.5` 替换 stub 为真 WhisperKit
- 避免现在引入大依赖拖慢首次构建和 CI

## Deliverables

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| `Package.swift` 加 WhisperKit | **延后** | ⚠️ stub |
| `WhisperTranscriptionService.swift` | `WhisperKitTranscriptionService.swift`（stub，throws unavailable） | ✅ |
| `TranscriptionServiceFactory.swift` 选实现 | ✅ `TranscriptionServiceFactory.make()` | ✅ |
| ContentView 通过 factory 注入 | `private let transcriptionService = TranscriptionServiceFactory.make()` | ✅ |
| 模型下载 UX | 延后到 Phase 8.5 | ⚠️ |

## DoD

- ✅ `BUILD SUCCEEDED` 0 warning
- ✅ **32/32 TEST SUCCEEDED**（+3 factory/stub 测）

## Phase 8.5 启用 WhisperKit 步骤（按需）

1. project.yml 加 `packages.WhisperKit.url: https://github.com/argmaxinc/WhisperKit`
2. 替换 `WhisperKitTranscriptionService` body 为真实 WhisperKit pipeline
3. 加首次启动 "downloading model (~150MB)" 进度 UI
4. 加预录 `.m4a` fixture 单测

触发条件：真机验证回合 #1 若发现转写不可用或质量过低。

## 下一步

→ Phase 9: 测试与质量门
