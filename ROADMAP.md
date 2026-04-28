# VoiceFlow iOS — ROADMAP

> Milestone: **M1 — TestFlight 美区可用版本**
> Version: 0.1.0
> Created: 2026-04-28
> Source: `.seed/MVP-BRIEF.md` + `.seed/RESEARCH.md` + `.seed/SOURCE-CARD.md`
> Project type: iOS native (SwiftUI, iOS 26+ primary, iOS 17-25 via WhisperKit)

---

## 1. Vision

把"录音 → 文字稿 → 送给 AI"压缩到一个屏幕、一个 App、一次按钮。
**不订阅、不上传、不限文件大小**。

## 2. Why this exists（用户证据）

源卡片 [[dc-2026-04-27-711]]（final_score 4.0）：用户花 \$6 买录音 App、\$13 买转码 App，仍然因为 WAV 文件 25 MB 超限被 Perplexity/Gemini 拒绝。
本项目消除这个工作流断点。

## 3. 不可妥协约束（Hard constraints）

| 约束 | 理由 |
|---|---|
| 默认录音格式 = M4A AAC 64 kbps 单声道 | 解 25 MB 上限根因（0.5 MB/min） |
| 主转写 = SpeechAnalyzer + SpeechTranscriber（iOS 26+，本地） | 零运营成本、隐私、长音频 |
| 备用转写 = WhisperKit（iOS 17-25 自动回退） | 覆盖旧设备 |
| 不引入 LAME / Whisper API 作为主线 | License + 成本 + 隐私 |
| 定价 = 一次性买断 \$4.99（首发促销 \$2.99） | 反订阅信号集群（862 / 1438 / 300） |
| 首发市场 = 美区（仅） | 711 用户来自 US Store，付费意愿强 |
| 数据政策 = Data Not Collected | 纯本地，不上传任何用户音频/文字 |
| Min iOS = 17（向下兼容到 iPhone XS 等 A12 设备） | 覆盖 ~95% 在用 iPhone |

## 4. Success Criteria（M1 完成定义）

**T 时刻（提交审核）**
- [ ] App 在 iPhone 12 mini（iOS 26+）真机录 30 min 会议，文字稿无崩溃
- [ ] 文字稿可一键导出 M4A / MP3 / TXT / SRT
- [ ] 隐私营养标签 = Data Not Collected
- [ ] 4 张截图（录音中、详情页、分享 sheet、设置页）+ App preview 视频已就位
- [ ] TestFlight 内测构建可被外部测试者下载

**T+7（上架后）**
- [ ] App Store 美区上架成功
- [ ] 下载 ≥ 50（卡片砍掉条件）
- [ ] 评分 ≥ 4.0

**T+30**
- [ ] IAP 转化率 ≥ 1%（卡片砍掉条件）
- [ ] 月下载 ≥ 200
- [ ] ≥ 3 条具体反馈："用它转录会议/采访/课程"

---

## 5. Phase 列表（10 phase，预计 30-40 工时）

> 估时按"机器执行 + 必要人工触点"合计。Phase 顺序为依赖顺序，可在标记处并行。

### Phase 0 — Environment Validation
- **Goal**：确保 Xcode 26 / macOS 26 / ASC Key / 签名证书 / 实机均可用
- **Deliverables**：`.planning/phase-0/VERIFICATION.md`，记录所有检查项与版本
- **DoD**：所有 ✅ 或明确标记"不阻塞"
- **Depends on**：无
- **估时**：10 min（已在主会话核验，仅需复执）
- **风险**：无

### Phase 1 — Xcode SwiftUI Scaffold
- **Goal**：创建工程骨架，启动屏 + 占位首页可在模拟器跑通
- **Deliverables**：
  - `VoiceFlow.xcodeproj`（SwiftUI App Lifecycle，min iOS 17，target iOS 26）
  - `VoiceFlow/VoiceFlowApp.swift`、`ContentView.swift`
  - `Info.plist`：`NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` / `UIBackgroundModes=audio`
  - `.gitignore`、`README.md`、首次 commit
- **DoD**：`xcodebuild -scheme VoiceFlow -sdk iphonesimulator build` 成功
- **Depends on**：Phase 0
- **估时**：30 min
- **风险**：无

### Phase 2 — Recording Core（录音核心）
- **Goal**：可按下大按钮开始/停止录音，文件落到沙盒
- **Deliverables**：
  - `RecordingService.swift`：`AVAudioRecorder` 包装（M4A AAC 64kbps 单声道，可切高码率）
  - `WaveformView.swift`：实时电平波形（基于 `AVAudioRecorder.meteringEnabled`）
  - `Recording.swift`：值类型，含 id/url/duration/createdAt
  - 首页录音按钮 + 录音中页（计时 + 波形 + 停止）
  - 沙盒 `Documents/recordings/{uuid}.m4a` 持久化
- **DoD**：
  - 模拟器录 60 秒文件 ≈ 480 KB（验证编码生效）
  - 首页可看到刚录的文件，时长正确
  - 单测 `RecordingServiceTests` 覆盖录音/停止/产物存在
- **Depends on**：Phase 1
- **估时**：4-6 h
- **风险**：模拟器麦克风路径，需在 macOS 26 验证；不阻塞

### Phase 3 — Local Transcription（本地转写）⭐核心⭐
- **Goal**：录完音频自动产出文字稿（含词级时间戳）
- **Deliverables**：
  - `TranscriptionService.swift`：`SpeechAnalyzer` + `SpeechTranscriber`（iOS 26+ 主线）
  - `Transcript.swift`：词级时间戳模型 `[TranscriptSegment(text, start, end, confidence)]`
  - 异步流：录音停止 → 后台启动转写 → Core Data 持久化
  - 详情页底部"转写中…"loading + 完成后展示
- **DoD**：
  - **真机** iPhone 12 mini 录 5 min 中文会议，转写完成且文字稿可读
  - 词级时间戳精度 ≤ 0.3s（用 `XCTAssertEqual(accuracy:)`）
  - 30 min 长音频不崩溃（自动按 10 min 分段）
  - 单测 `TranscriptionServiceTests` 用预录 `.m4a` fixture 离线跑
- **Depends on**：Phase 2
- **估时**：4-6 h
- **🔴 真机验证回合 #1**：用户插 iPhone 解锁，跑 30 秒 demo 看转写质量
- **风险**：SpeechAnalyzer 中文模型质量 / 长音频内存

### Phase 4 — List + Detail + Core Data
- **Goal**：完整的列表/详情交互，支持重命名/删除
- **Deliverables**：
  - `Persistence.swift`：Core Data stack
  - `RecordingEntity` + `TranscriptEntity`（CD 模型）
  - `RecordingListView.swift`、`RecordingDetailView.swift`
  - 详情页：上半 `AVPlayerView` 音频播放器，下半 `ScrollView` 文字稿（点词跳秒，需 Phase 3 时间戳）
  - Swipe 重命名 / 删除
- **DoD**：
  - 100 条录音列表流畅滑动（≥ 60fps）
  - 删除文件物理移除沙盒、CD 行级联清理
  - UI 测 `RecordingFlowUITests` 覆盖：录 → 列表显示 → 详情看稿 → 删除
- **Depends on**：Phase 3
- **估时**：4-6 h

### Phase 5 — Export & Share
- **Goal**：分享/导出文字稿与音频到任意 App
- **Deliverables**：
  - `ExportService.swift`：M4A→MP3 转码（`AVAssetExportSession` 通过 PCM 中间态）
  - `ShareSheet.swift`：UIActivityViewController 包装
  - 导出菜单：M4A / MP3 / TXT / SRT / Markdown / 复制全文
  - SRT 生成器（基于词级时间戳合并为 ≤ 5s 行）
- **DoD**：
  - 5 min 录音导出 MP3 < 5 秒完成
  - SRT 在 VLC 播放正确
  - Markdown 输出含元信息（标题/时长/时间戳锚点）
- **Depends on**：Phase 4
- **估时**：3 h
- **🔴 真机验证回合 #2**：用户分享一次到 Perplexity，验证 share-sheet 流程

### Phase 6 — "Send to AI"
- **Goal**：一键把文字稿送进 Perplexity / ChatGPT / Gemini App
- **Deliverables**：
  - `AIShareService.swift`：检测已装的 AI App（URL Scheme 探测）
  - 已装：通过 URL Scheme 直传文字稿（如 `perplexity://search?q=...`）
  - 未装：复制全文 + 弹"已复制，去 [Perplexity](https://perplexity.ai)"
  - 详情页底部紫色 CTA 按钮"Send to AI ▾"
- **DoD**：
  - 三家 App 都装时菜单展示三个选项
  - 每家都能成功打开并预填文字稿
  - 单测覆盖 URL Scheme 编码（中文 / 长文本 ≥ 5000 字）
- **Depends on**：Phase 5
- **估时**：2 h
- **风险**：AI App 各自 URL Scheme 不稳定，需 fallback 到剪贴板

### Phase 7 — iCloud Sync + Settings
- **Goal**：跨设备同步 + 设置页（默认格式/采样率/iCloud 开关/关于）
- **Deliverables**：
  - `CloudKitSync.swift`：CD + CloudKit Mirror（Apple 官方模板）
  - 实体添加 `CKRecord` 元数据
  - `SettingsView.swift`：5 个开关 + 关于页（含源卡片致谢/反馈邮箱）
  - 首次启动 onboarding（3 屏：欢迎 / 权限申请 / 完成）
- **DoD**：
  - iPhone A 录的稿件 30 秒内出现在 iPhone B
  - 关闭 iCloud 开关后立即停止同步
- **Depends on**：Phase 4
- **估时**：4 h
- **可与 Phase 5/6 并行**

### Phase 8 — WhisperKit Fallback（iOS 17-25）
- **Goal**：iOS 25 及以下设备走 WhisperKit
- **Deliverables**：
  - `Package.swift` 添加 `argmaxinc/WhisperKit`
  - `WhisperTranscriptionService.swift`：实现 `TranscriptionService` 协议
  - `TranscriptionServiceFactory.swift`：按 `if #available(iOS 26.0, *)` 选实现
  - 首次启动检测系统版本，iOS<26 弹一次"将下载 ~150 MB 转写模型"提示
- **DoD**：
  - iOS 17 模拟器跑 5 min 录音转写完成（中文模型）
  - 模型下载支持断点续传 + 失败重试
- **Depends on**：Phase 3
- **估时**：4 h

### Phase 9 — Test & Quality Gate
- **Goal**：单测 + UI 测 + 性能 + lint 全绿
- **Deliverables**：
  - 单测覆盖率 ≥ 70%（核心 Service 类 ≥ 90%）
  - UI 测覆盖 5 条核心路径（录音/转写/列表/详情/导出）
  - SwiftLint + SwiftFormat CI 友好
  - `xcodebuild test` 通过
  - 性能基线：30 min 音频转写 ≤ 5 min（iPhone 12 mini）
- **DoD**：
  - 全部测试 pass
  - Instruments 检查：内存峰值 < 200 MB
  - 无 SwiftLint warning
- **Depends on**：Phase 8 完成
- **估时**：3 h

### Phase 10 — App Store Connect Submission
- **Goal**：提交 TestFlight + 准备首次审核
- **Deliverables**：
  - `/asc-app-create-ui` 创建 ASC App 记录（Bundle ID `com.lei.voiceflow`）
  - `/asc-privacy-nutrition-labels` 填 Data Not Collected
  - 截图（4 张 6.7"）+ App Preview 视频（30 秒，屏幕录制剪辑）
  - 文案：标题 / 副标题 / 描述（英文，主打 "Local AI Transcription"）
  - 关键词：`voice recorder, transcription, audio to text, meeting notes, AI`
  - Archive + 上传 build → TestFlight
- **DoD**：
  - TestFlight 内测可下载安装
  - 隐私标签提交完成
  - 准备好提交审核（最后一步等用户点）
- **Depends on**：Phase 9
- **估时**：1 h（自动）+ 30 min（用户截图/文案审）
- **🔴 真机验证回合 #3**：用户做最后审阅 + 点 "Submit for Review"

---

## 6. 跨 Phase 风险与逃生

| 风险 | 触发条件 | 逃生 |
|---|---|---|
| SpeechAnalyzer 中文质量差 | Phase 3 真机测准确率 < 80% | 改默认走 WhisperKit medium 模型 |
| 30 min 音频内存爆 | Phase 3 / 9 性能测 | 自动按 10 min 分段（已在 Phase 3 设计） |
| AI App URL Scheme 失效 | Phase 6 真机测 | 降级为复制 + 引导 |
| iCloud 配额不够 | Phase 7 用户测 | 明确文案提示 + 提供"仅本地"模式 |
| Apple 审核拒（Guideline 4.0） | Phase 10 提交后 | 模板回复 + 加截图说明转写本地化 |
| 评审拒"功能太基础" | Phase 10 提交后 | 主打"长录音 + 本地转写 + AI 分享"组合，强化文案 |

## 7. 决策记录（已锁定，不再讨论）

| 决策 | 结果 | 引用 |
|---|---|---|
| 录音格式 | M4A AAC 64kbps 默认 | RESEARCH.md §五 |
| 转写引擎 | iOS 26+ SpeechAnalyzer / 旧版 WhisperKit | RESEARCH.md §二/三 |
| 定价 | \$4.99 一次性，首发 \$2.99 | MVP-BRIEF.md §8 |
| 首发市场 | 美区 | MVP-BRIEF.md §1 |
| 数据政策 | Data Not Collected | RESEARCH.md §六 |
| 后端 | 无（CloudKit） | MVP-BRIEF.md §5.2 |

## 8. 用户介入点汇总（≤ 1 小时总时长）

| 时机 | 做什么 | 时长 |
|---|---|---|
| Phase 0 启动前 | 确认 Apple Developer 账号在期 | 1 min |
| Phase 3 完成后 | 真机录 30 秒看转写 | 2 min |
| Phase 5 完成后 | 真机分享一次到 Perplexity | 2 min |
| Phase 7 完成后 | 双设备 iCloud 同步验证 | 5 min |
| Phase 10 提交前 | 截图/文案审 + 点提交 | 30 min |
| 审核被拒（如有） | 模板回复 + 重提 | 5 min |
| **总计** | — | **~45 min 分散在 5-7 天** |

## 9. 进度追踪

每个 phase 完成后，gsd-executor 自动：
1. atomic commit（"phase-N: <goal>"）
2. 在 `.planning/phase-N/COMPLETION.md` 记录 deliverables 实际路径
3. 提示用户进入下一 phase（或在 autonomous 模式下自动接续）

最终在 `.planning/M1-COMPLETION.md` 汇总。

---

## 10. 给 GSD 的接管指令

```
/gsd-new-project --import .seed/STARTUP.md --roadmap ROADMAP.md
# 或
读 ROADMAP.md，按其 Phase 0-10 拆分到 .planning/，然后 /gsd-autonomous
```

`gsd-roadmapper` agent 应直接吸收本文件，**不要**重新生成 phase——本文件已是经用户审过的最终版本。

---

_由 Obsidian 调研会话生成于 2026-04-28，待用户审阅。_
