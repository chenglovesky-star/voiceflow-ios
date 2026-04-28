---
level: L1
domain: 商业
type: research
tags: [iOS, 录音, 语音转写, SpeechAnalyzer, WhisperKit, 一人企业, MVP, AI工具]
search_keywords: [录音转写, 语音转文字, transcription, dictation, AI 字幕, 会议记录, 录音笔, voice memo, voice recorder]
question: 录音→AI转写一站式 iOS App 的技术方案是什么？可实现性如何？
sources:
  - "[[dc-2026-04-27-711]]"
  - "[[dc-2026-04-27-705]]"
  - https://developer.apple.com/videos/play/wwdc2025/277/
  - https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app
  - https://github.com/argmaxinc/WhisperKit
created: 2026-04-28
maturity: 🌱
---

# 🎙️ 录音→AI转写一站式 iOS App 技术调研

> 如果你想做一款"录完即得到文字稿"的 iOS App，可以参考本笔记中的技术栈、API、可实现性评估。

## 一、问题重新定义

来源卡片 [[dc-2026-04-27-711]] 用户原话："WAV files will not parse for transcription in AI apps"。
但 2026-04 实际事实：

| 平台 | WAV | MP3 | M4A/AAC | 大小上限 |
|---|---|---|---|---|
| Perplexity Pro | ✅ audio/wav | ✅ audio/mp3 | ⚠️ 未明列 | 50 MB / 文件 |
| Gemini API | ✅ audio/wav | ✅ audio/mp3 | ✅ audio/m4a | 大上下文 |
| OpenAI Whisper API | ✅ | ✅ | ✅ | 25 MB / 文件 |

**真问题**：
1. 通用录音 App 默认录 WAV 44.1k/16-bit ≈ 10 MB/分钟，半小时会议=300 MB，撞 25-50 MB 文件上限。
2. 用户为得到文字稿要跨 4 个 app（录音→文件→转码→AI），且常失败。
3. 几乎所有付费录音 App 都"只录不写"，让用户自己想办法转文字。

→ **切入点修正**：不是"做更好的 WAV 转码"，而是"录完即转写、即得 MP3+文字稿、可一键发任何 AI"，**完全跳过用户跨 app 的工作流**。

## 二、技术方案 A（推荐）：iOS 26 SpeechAnalyzer + 原生 M4A

```
AVAudioRecorder（M4A/AAC，~1 MB/分钟）
        ├── 本地音频存储（已是 AI 全平台兼容格式）
        └── SpeechAnalyzer + SpeechTranscriber（iOS 26+，纯本地、免费、无网络）
                ↓
        文字稿 + 词级时间戳 + 说话人识别
                ↓
        一键导出：M4A / MP3 / TXT / SRT / Markdown，分享到任意 App
```

**核心 API（Swift / iOS 26+）**：
- `AVAudioRecorder` 录 `.m4a`（AAC 编码，已经被 Perplexity/Gemini/OpenAI 全部接受，1 MB/分钟）
- `SpeechAnalyzer` + `SpeechTranscriber`（WWDC 2025 发布）：长音频、纯本地、会议/讲座场景优化、词级时间戳
- iOS 26 以下回退路径：`DictationTranscriber`（Apple 兼容到 iOS 10）或 `WhisperKit`（开源，CoreML，Argmax 维护）

**优势**：
- 转写**零运营成本**（Apple 内置、本地、免费）
- 无网络也能用 → 直接成为差异化卖点
- 隐私强（不上传）→ 律师、医生、记者目标人群
- 不踩 Apple 25 MB 文件政策红线

## 三、技术方案 B：WhisperKit fallback（iOS 17–25 用户）

WhisperKit Swift Package 一行依赖，CoreML+Neural Engine，模型 ~150 MB，可选 small/medium。
转写质量历史上高于旧 SFSpeechRecognizer，但 iOS 26 SpeechAnalyzer 已追平。
仍保留作为旧系统兼容路径。

## 四、技术方案 C（不推荐作主线）：云 API

- Whisper API $0.006/分钟
- Gemini Flash 输入有限速

仅在做"高精度付费档"或多语言时作为补充能力，不作 MVP 主线。

## 五、录音格式策略（解决根因）

| 格式 | 大小 | AI 兼容 | 推荐 |
|---|---|---|---|
| WAV 44.1k/16-bit | 10 MB/分钟 | 撞 25 MB 限制 | ✗ 默认禁用 |
| **M4A/AAC 64kbps** | 0.5 MB/分钟 | ✅ 全平台 | ✅ **默认** |
| MP3 128kbps | 1 MB/分钟 | ✅ 全平台 | ✅ "导出兼容性"选项 |

iOS 原生 `AVAssetExportSession` + `AVAudioConverter` 即可完成 M4A↔MP3 转码，PCM 中间态。无需 LAME（避开 license 问题）。

## 六、上架风险评估

| 风险 | 等级 | 缓解 |
|---|---|---|
| 类似 app 已饱和 | 🟡 中 | "录完即得文字稿"差异化够明确，本地转写是杀手锏 |
| `NSMicrophoneUsageDescription` | 🟢 低 | 标准权限，文案合规即可 |
| `NSSpeechRecognitionUsageDescription` | 🟢 低 | iOS 26 SpeechAnalyzer 仍需此键 |
| 后台录音 `audio` background mode | 🟡 中 | 需 Apple 审核理由清晰（"长会议录制"） |
| 隐私营养标签 | 🟢 低 | 纯本地反成优势——填 "Data Not Collected" |
| 国区 vs 美区 | 🔵 决策 | **建议美区先**——711 评论来自 US Store，付费意愿高 |

## 七、可实现性总结

| 维度 | 评估 |
|---|---|
| 技术成熟度 | ✅ Apple 官方 + 开源备选齐全，无未知风险 |
| 第三方依赖 | 零必需（WhisperKit 仅 iOS<26 备选） |
| 开发周期 | 2-3 周（一人）至 MVP 上架 |
| 运营成本 | $0 / 月（纯本地） |
| 上架风险 | 低 |
| 差异化护城河 | 中等——本地+长格式+M4A 默认。中短期空间清晰，长期需提防 Apple 自家"语音备忘录"升级 |
| **总体可实现性** | **🟢 高**（与卡片 5.0 评分一致） |

## 八、与其它高分卡片的协同

- 同领域辅证：**[[dc-2026-04-27-705]]** 同一目标 app（Voice Recorder），痛点"不能重排音频片段"——可作为 P1 功能扩展。
- 反订阅信号集群（影响定价）：**[[dc-2026-04-27-862]]** 轻历杀熟、**[[dc-2026-04-27-1438]]** 二维码工房售后差、**[[dc-2026-04-27-300]]** Streaks 24 任务上限——共同表明用户对买断/明确价值的偏好。

## 九、决策建议

**采纳 + 作为 W18 单周 MVP**：
- 技术零未知风险
- 运营零成本
- 用户痛点已被 [[dc-2026-04-27-711]] + [[dc-2026-04-27-705]] 双卡片印证
- 与定价"反订阅"信号集群协同
- 后续可扩展为 #6 705 的"片段编辑"完整产品

详细产品定义见 [[dc-2026-04-27-711-MVP-BRIEF]]。

## 信息源

1. [Perplexity File Uploads Help Center](https://www.perplexity.ai/help-center/en/articles/10354807-file-uploads)
2. [Perplexity AI File Uploading: Formats and Limits 2026](https://www.datastudios.org/post/perplexity-ai-file-uploading-size-limits-supported-formats-plan-differences-and-workflow-strateg)
3. [Gemini API Audio Understanding Docs](https://ai.google.dev/gemini-api/docs/audio)
4. [WWDC25 — Bring Advanced Speech-to-Text to Your App with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/)
5. [Bringing advanced speech-to-text capabilities to your app (Apple Developer)](https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app)
6. [iOS 26 SpeechAnalyzer Guide (Anton Gubarenko)](https://antongubarenko.substack.com/p/ios-26-speechanalyzer-guide)
7. [On-Device Speech Transcription with Apple SpeechAnalyzer (Callstack)](https://www.callstack.com/blog/on-device-speech-transcription-with-apple-speechanalyzer)
8. [WhisperKit (argmaxinc on GitHub)](https://github.com/argmaxinc/WhisperKit)
9. [whisper.cpp (ggml-org on GitHub)](https://github.com/ggml-org/whisper.cpp)

---

_最后更新：2026-04-28_
