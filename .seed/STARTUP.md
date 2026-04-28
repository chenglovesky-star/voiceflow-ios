# VoiceFlow iOS — Startup Seed

> 在此目录打开 Claude Code 后，作为新会话的 onboarding 文档。

## 你是谁
你正在帮用户构建一款 iOS native App：**录音 → 本地 AI 转写 → 一键送任意 AI**。
该项目已经做完调研、写好 MVP brief，现在进入"自主构建"阶段。

## 立即读这三份文件（必读）
1. `.seed/MVP-BRIEF.md` — 11 节产品定义、屏幕流、3 周路线图
2. `.seed/RESEARCH.md` — 技术栈选择 + 可实现性矩阵
3. `.seed/SOURCE-CARD.md` — 用户原始痛点证据

## 环境已核验（2026-04-28）
- Xcode 26.2 / macOS 26.1（SpeechAnalyzer 可用）
- ASC API Key: `~/.blitz/AuthKey_546FUCYC9Z.p8`
- 签名: Apple Distribution `7337LF5P35`（Lei cheng）
- 实机: iPhone 12 / 12 mini 已配对，使用时插线解锁

## 一句话启动
```
/gsd-new-project
```
吸收 .seed/ 三个文件作为上下文，按 brief 的 P0/P1/P2 阶段拆 phase，然后：
```
/gsd-autonomous
```

## 最终目标
Phase 10 完成时：
- TestFlight 已上架，含 iCloud 同步、本地转写、分享/导出/送 AI
- Privacy Nutrition Label 已填（Data Not Collected）
- 截图/metadata 准备好等待用户提交审核

## 不可妥协项
- 默认录音格式 M4A AAC 64kbps（不是 WAV）
- 主转写走 SpeechAnalyzer（iOS 26+），WhisperKit 仅作 iOS 25- 兼容
- 一次性买断 $4.99（不做订阅）
- 美区先发
- 纯本地，不上传任何用户数据
