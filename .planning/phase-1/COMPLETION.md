# Phase 1 — Xcode SwiftUI Scaffold (COMPLETED)

> Date: 2026-04-28
> Goal (ROADMAP §5 Phase 1): 工程骨架，启动屏 + 占位首页可在模拟器跑通

## Deliverables 实际路径

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| `VoiceFlow.xcodeproj` (SwiftUI App, min iOS 17) | `VoiceFlow.xcodeproj/`（由 `project.yml` xcodegen 生成，gitignored） | ✅ |
| `VoiceFlow/VoiceFlowApp.swift` | `VoiceFlow/VoiceFlowApp.swift` | ✅ |
| `VoiceFlow/ContentView.swift` | `VoiceFlow/ContentView.swift` | ✅ |
| Info.plist 含麦克风/识别/audio bg | 由 xcodegen 注入到 `VoiceFlow/Info.plist` | ✅ |
| `.gitignore` | `.gitignore`（覆盖 Xcode/SwiftPM/secrets） | ✅ |
| `README.md` | `README.md`（含构建命令、架构说明） | ✅ |
| 首次 commit | 见 `git log` | ✅ |

## 额外产物

- `project.yml` (xcodegen 配置，canonical) — 这是 git 真相源，`.xcodeproj` 可重新生成
- `VoiceFlow/Assets.xcassets/` + `AppIcon.appiconset/Contents.json`（占位）
- `VoiceFlow/Preview Content/Preview Assets.xcassets/`（SwiftUI Preview 必需）
- `VoiceFlowTests/VoiceFlowTests.swift`（Swift Testing 框架，1 个冒烟测试）

## Definition of Done 验证

| DoD 项 | 验证命令 | 结果 |
|---|---|---|
| `xcodebuild build` 通过 | `xcodebuild ... -sdk iphonesimulator build` | ✅ `BUILD SUCCEEDED` |
| `xcodebuild test` 通过 | `xcodebuild ... -sdk iphonesimulator test` | ✅ `TEST SUCCEEDED` (1/1 pass) |
| Swift Strict Concurrency 通过 | 已在 project.yml 设 `complete` | ✅ 编译无 warning |
| min iOS = 17, target API = 26 | `IPHONEOS_DEPLOYMENT_TARGET=17.0` | ✅ |

## 选择记录

- **使用 xcodegen 而非手写 .xcodeproj**：保证 git 干净（diff 友好），单文件 `project.yml` 配置全部，`.xcodeproj` 列入 `.gitignore`。
- **Swift Testing 而非 XCTest**：iOS 26 / Xcode 26 默认推荐，语法更现代（`@Test`, `@Suite`, `#expect`），后续 Phase 2-9 测试沿用。
- **min iOS = 17**：覆盖 ~95% 在用机（A12+），Phase 3 主线走 iOS 26 SpeechAnalyzer，Phase 8 走 WhisperKit fallback。

## 已知遗留

- AppIcon 仅有占位 1024x1024 入口（无实际图像）—— Phase 10 提交前补
- 启动屏空 (UILaunchScreen: {})—— Phase 10 提交前补
- 没有 entitlements 文件 —— Phase 7 (iCloud) 时添加

## 下一步

→ Phase 2: 录音核心（AVAudioRecorder M4A 64kbps + 波形 UI）
