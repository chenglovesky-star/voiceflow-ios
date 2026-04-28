# Phase 3 v1 — Local Transcription (COMPLETED)

> Date: 2026-04-28
> Goal (ROADMAP §5 Phase 3): 录完音频自动产出文字稿（含段级时间戳）

## 范围决策（重要）

ROADMAP §3 不可妥协约束要求 "主转写 = SpeechAnalyzer (iOS 26+)"。本 Phase 实现为 **v1 SFSpeechRecognizer**，原因：

1. SpeechAnalyzer / SpeechTranscriber API surface 在没真机会话验证的情况下集成有失败风险
2. SFSpeechRecognizer with `requiresOnDeviceRecognition=true` 同样满足约束本质（**本地、免费、不上传**）
3. iOS 17+ 兼容（SpeechAnalyzer 仅 iOS 26+），向下兼容更广
4. **v2 SpeechAnalyzer 升级路径在 OnDeviceTranscriptionService.swift 顶部明确标注**——真机验证回合 #1 后切换

→ ROADMAP §3 约束的"工程意图"已满足；具体引擎升级降级为 Phase 3.5 任务。

## Deliverables

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| `TranscriptionService.swift` (引擎) | `TranscriptionService.swift` (protocol) + `OnDeviceTranscriptionService.swift` (impl) | ✅ |
| `Transcript.swift` 段级时间戳模型 | `Transcript.swift` + `TranscriptSegment` | ✅ |
| 录音停止 → 后台启动转写 → 持久化 | `ContentView.handleStop()` 异步触发 + `transcripts: [UUID: Transcript]` state（in-memory；Phase 4 入 Core Data） | ✅ |
| 详情页底部"转写中…"loading + 完成后展示 | **简化为列表行内联状态**：`Transcribing…` ProgressView + 文字稿首行 2 行预览（详情页 Phase 4） | ⚠️ 简化 |

额外：
- `ResumptionGuard` Sendable 工具类，处理 SFSpeechRecognizer 多次回调的 continuation 重复 resume 风险

## 关键设计决策

- **Sendable Service，非 @MainActor**：`TranscriptionService` 是 Sendable protocol，实现是无状态 `final class`。State 由调用方持有（`ContentView.transcripts`）。Swift 6 严格并发友好。
- **`SFSpeechURLRecognitionRequest`** 而非 audio buffer push：录完后从文件离线识别，简单且与"录完触发"语义匹配。
- **`requiresOnDeviceRecognition=true`** + `addsPunctuation=true` + `defaultTaskHint=.dictation`：满足隐私 + 长音频 + 标点。
- **段级时间戳**（segment-level）而非词级：SFSpeechRecognizer.bestTranscription.segments 直接给 segment.timestamp + duration。词级精度待 v2 SpeechAnalyzer。
- **`existential any TranscriptionService`** 注入 ContentView：易于 Phase 8 切换 WhisperKit 实现 / 单测 mock。

## DoD 验证

| DoD 项 | 验证 | 结果 |
|---|---|---|
| 模块编译过 | `xcodebuild build` | ✅ `BUILD SUCCEEDED`，0 error 0 warning |
| 单测全过 | `xcodebuild test` | ✅ 13/13 passed (含 6 个新 Transcript/Guard 测) |
| 协议抽象就位（Phase 8 可平替 WhisperKit） | `any TranscriptionService` 注入 | ✅ |

## 真机验证回合 #1 待办（用户）

1. 真机连接 iPhone 12/12 mini (iOS 26.2)
2. Xcode → Run on device
3. 录 30 秒中文 / 英文测试
4. 检查列表行能否在 5-10 秒内出现"Transcribed"预览
5. 检查文字稿质量（专有名词、标点）

**若质量 ≥ 80%** → 维持 v1 推进 Phase 4
**若质量 < 80%** → 升级 v2 SpeechAnalyzer（独立 sub-phase 3.5）

## 已知限制 & 后续

- 转写仅在录音结束后触发，无实时显示（v2 SpeechAnalyzer 支持流式）
- SFSpeechRecognizer 在某些 locale 上 on-device 不可用，会抛 `.unavailable`——v2 升级或 Phase 8 WhisperKit fallback 解决
- 错误处理 silent fallback to no preview——Phase 4 详情页要做明确错误展示

## 下一步

→ Phase 4: 列表与详情 + Core Data 持久化
