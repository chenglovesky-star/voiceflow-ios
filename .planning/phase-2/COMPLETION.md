# Phase 2 — Recording Core (COMPLETED)

> Date: 2026-04-28
> Goal (ROADMAP §5 Phase 2): 可按下大按钮开始/停止录音，文件落到沙盒

## Deliverables

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| `RecordingService.swift` (M4A AAC 64kbps 单声道) | `VoiceFlow/RecordingService.swift` | ✅ |
| `WaveformView.swift` (实时电平) | `VoiceFlow/WaveformView.swift` | ✅ |
| `Recording.swift` (值类型) | `VoiceFlow/Recording.swift` | ✅ |
| 首页录音按钮 | `ContentView.swift` `startButton` | ✅ |
| 录音中页（计时 + 波形 + 停止） | `RecordingView.swift` | ✅ |
| 沙盒持久化 `Documents/recordings/{uuid}.m4a` | `RecordingService.makeRecordingURL()` | ✅ |
| 单测覆盖 | `RecordingTests.swift`（7 tests） | ✅ |

## 关键设计决策

- **`@MainActor @Observable` RecordingService**：Swift 6 严格并发下避免 `Sendable` 噪音；UI 直接订阅状态；delegate 回调 `nonisolated` 后 hop 回 main。
- **id-based equality**：默认合成 `Hashable` 会因 `createdAt = Date()` 毫秒漂移导致 "same id 但 != "，改写为 `==` / `hash(into:)` 仅基于 `id`。这符合 `Identifiable` 数据库实体语义。
- **录音设置**：`kAudioFormatMPEG4AAC` + 44.1 kHz + mono + 64 kbps + medium quality → 0.5 MB/min（达成 ROADMAP §3 不可妥协约束）。
- **iOS 17+ 权限 API**：`AVAudioApplication.requestRecordPermission()`，回退到 `AVAudioSession` 旧 API。
- **`allowBluetoothHFP`** 替代 deprecated `allowBluetooth`（iOS 26 编译器 warning 修复）。
- **波形 30 bars + 60 levels 环形缓冲**：50ms tick，3 秒滚动窗口，CPU/电量友好。

## DoD 验证

| DoD 项 | 验证 | 结果 |
|---|---|---|
| `xcodebuild build` 无错 | iPhone 16e iOS 26.2 sim | ✅ `BUILD SUCCEEDED`，0 warning |
| `xcodebuild test` 全过 | 同上 | ✅ 7/7 passed |
| Swift Strict Concurrency `complete` | 已在 project.yml | ✅ 编译无并发错 |

## 端到端手测路径（用户验证用）

1. Xcode 打开 `~/Desktop/voiceflow-ios/VoiceFlow.xcodeproj`
2. 选 iPhone 16e (iOS 26.2) 模拟器
3. ⌘R 运行
4. 首次启动应该弹麦克风权限，准予
5. 点首页紫色大麦克风按钮 → 进入录音中页（应看到滚动波形 + 计时）
6. 点红色方块停止 → 回到首页，列表应出现一条录音

> **模拟器麦克风**：macOS 26 设置 → 隐私与安全 → 麦克风 → 勾选 "Simulator"

## 已知局限

- 模拟器电平可能为 -160dB（无音频）。真机或 macOS 系统麦克风能正常显示电平。
- 录音中后台中断（来电/Siri）会触发 `audioRecorderDidFinishRecording` delegate，但当前未做 UI 反馈。Phase 7 设置/iCloud 完成后再补"后台被中断"提示。
- 没有"暂停/继续"功能（ROADMAP 未要求，下沉 backlog）。

## 下一步

→ Phase 3: 本地转写（SpeechAnalyzer + SpeechTranscriber）⚠️ 需真机
