# Phase 6 — Send to AI (COMPLETED)

> Date: 2026-04-28

## Deliverables

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| `AIShareService` | `VoiceFlow/AIShareService.swift` | ✅ |
| 检测已装 AI App | `isInstalled(_:)` via `UIApplication.canOpenURL` | ✅ |
| 已装 → URL Scheme | `UIApplication.open(target.detectionURL)` | ✅ |
| 未装 → 复制 + 引导 web | 自动 fallback `webURL` | ✅ |
| 详情页底部紫色 CTA | `sendToAICTA` Menu，紫色 14pt 圆角，仅在有 transcript 时出现 | ✅ |
| `LSApplicationQueriesSchemes` | project.yml 注册 `perplexity`/`chatgpt`/`googlegemini`/`claude` | ✅ |
| 单测覆盖 URL Scheme 编码 | `AIShareServiceTests`（3 tests） | ✅ |

支持目标：Perplexity / ChatGPT / Gemini / Claude（4 家）。

## 关键决策

- **剪贴板作为可靠运输层**：大多数 AI App 不接受 URL Scheme payload。我们把文字稿写入 `UIPasteboard`，然后只是"打开 App"，让用户在 App 内一键粘贴。这避免了对每家未文档化 scheme 的脆弱依赖。
- **未装时打开 web**：不强求 App Store 跳转（用户体验割裂），直接打开网页版完成"送给 AI"语义。
- **CTA 只在有 transcript 时显示**：避免空 transcript 误触。
- **alert 反馈而非 toast**：iOS 系统 alert 即用，避免引第三方 toast 库。

## DoD

- ✅ `BUILD SUCCEEDED` 0 warning
- ✅ **27/27 TEST SUCCEEDED**（+3 AITarget 测）

## 真机验证回合 #2 待办

1. 装 Perplexity / ChatGPT / Gemini / Claude 任一
2. 录一段，等转写完成
3. 详情页点 "Send to AI ▾" → 选目标
4. 应弹 "Transcript copied. Opening …"，然后 App 自动打开
5. 在目标 App 长按粘贴 → 应有完整文字稿

## 下一步

→ Phase 7: iCloud 同步 + 设置页
