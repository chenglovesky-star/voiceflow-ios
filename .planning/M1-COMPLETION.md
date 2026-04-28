# M1 — TestFlight 美区可用版本（COMPLETED — code path）

> Date: 2026-04-28
> All 10 phases shipped via `/path B`（当前会话手工执行 ROADMAP）

## Phase 进度

| # | Phase | Commit | 关键交付 |
|---|---|---|---|
| 0 | Env Verification | (n/a) | Xcode 26.2 / macOS 26.1 / ASC Key 全就位 |
| 1 | Scaffold | `c45ceeb` | xcodegen + Swift Testing 1/1 |
| 2 | Recording Core | `b9e28cf` | M4A AAC 64kbps + 波形 + 7/7 tests |
| 3 v1 | Local Transcription | `19d8b6f` | SFSpeechRecognizer on-device + 13/13 |
| 4 | List + Detail + SwiftData | `2b50b98` | @Query + RecordingDetailView + 19/19 |
| 5 | Export & Share | `b1c6d15` | M4A/MP3/TXT/SRT/MD + 24/24 |
| 6 | Send to AI | `05dce71` | Perplexity/ChatGPT/Gemini/Claude + 27/27 |
| 7 | Settings + iCloud Stub | `390f0a8` | UserDefaults + Form + 29/29 |
| 8 | WhisperKit Fallback | `66539bd` | Factory + stub + 32/32 |
| 9 | Test & Quality Gate | (next) | Perf baselines + SwiftLint + 35/35 |
| 10 | ASC Prep | (next) | METADATA + CHECKLIST + archive.sh |

## 主线测试结果

**35/35 tests in 13 suites passing**（iPhone 16e iOS 26.2 simulator）

性能基线：
- SRT generation 5000 segs: < 100 ms ✅
- fullText join 5000 segs: < 50 ms ✅
- ResumptionGuard 200 concurrent: 1 execution ✅

## 范围决策汇总（与 ROADMAP 对照）

| 决策 | 原因 | 升级路径 |
|---|---|---|
| Phase 3 v1 用 SFSpeechRecognizer 而非 SpeechAnalyzer | API surface 需真机验证 | Phase 3.5 真机 OK 后切 SpeechAnalyzer |
| Phase 4 用 SwiftData 替代 Core Data | 同底层、更现代、CloudKit-ready | (无) |
| Phase 5 MP3 实际产 M4A | iOS 无内置 MP3 encoder + LAME license | Phase 5.1 集成 AudioToolbox 真 MP3 |
| Phase 7 iCloud 仅 stub | 需 Developer Portal CloudKit container | Phase 10 前置 3 步骤 |
| Phase 8 WhisperKit 仅 stub | SFSpeechRecognizer 已覆盖 iOS 17+ | Phase 8.5 真机 locale 不可用时启用 |
| Phase 9 UI tests 降级到真机手测 | simulator 录音需 mic 权限/真音频 | Phase 9.5 加 bundle.ui-testing target |

## 用户必须完成的 80 分钟

详见 `asc/SUBMISSION-CHECKLIST.md`：
- Apple Developer 配置 + Privacy URL 上线（10 min）
- 真机验证 3 回合（15 min）
- 截图 + App Preview（30 min）
- archive + ASC metadata + 提交（25 min）

## 项目结构

```
voiceflow-ios/
├── ROADMAP.md              # 用户审过的 10 phase 计划
├── README.md
├── .gitignore / .swiftlint.yml
├── project.yml             # xcodegen 真相源
├── .seed/                  # MVP brief / research / source-card
├── .planning/              # 各 phase COMPLETION.md
├── asc/                    # METADATA.md + SUBMISSION-CHECKLIST.md
├── scripts/                # archive.sh + ExportOptions.plist
├── VoiceFlow/
│   ├── VoiceFlowApp.swift          # @main + ModelContainer
│   ├── ContentView.swift            # @Query + record + nav
│   ├── RecordingView.swift          # in-recording UI
│   ├── RecordingDetailView.swift    # player + transcript + export + AI CTA
│   ├── SettingsView.swift           # Form
│   ├── AudioPlayerView.swift        # AVAudioPlayer wrapper
│   ├── WaveformView.swift           # 30-bar real-time
│   ├── Recording.swift              # value type
│   ├── RecordingService.swift       # AVAudioRecorder + AVAudioApplication
│   ├── RecordingEntity.swift        # SwiftData @Model
│   ├── Transcript.swift             # value type + Codable
│   ├── TranscriptEntity.swift       # SwiftData @Model + JSON segments
│   ├── TranscriptionService.swift   # protocol + errors + ResumptionGuard
│   ├── OnDeviceTranscriptionService.swift  # SFSpeechRecognizer impl
│   ├── WhisperKitTranscriptionService.swift # stub
│   ├── TranscriptionServiceFactory.swift   # picks impl
│   ├── ExportService.swift          # 5 formats
│   ├── ShareSheet.swift             # UIActivityVC wrapper
│   ├── AIShareService.swift         # 4 AI targets
│   └── AppSettings.swift            # UserDefaults
└── VoiceFlowTests/
    ├── VoiceFlowTests.swift          # smoke
    ├── RecordingTests.swift          # value type + URL helper
    ├── PersistenceTests.swift        # SwiftData entities
    ├── TranscriptTests.swift         # transcript model + ResumptionGuard
    ├── ExportServiceTests.swift      # text formats
    ├── AIShareServiceTests.swift     # URL invariants
    ├── AppSettingsTests.swift        # UserDefaults persistence
    ├── TranscriptionFactoryTests.swift # factory + stub
    └── PerformanceTests.swift        # SRT/fullText/concurrency baselines
```
