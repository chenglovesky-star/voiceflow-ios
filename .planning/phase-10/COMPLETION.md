# Phase 10 — App Store Connect Submission Prep (COMPLETED)

> Date: 2026-04-28

## Deliverables

| ROADMAP 期望 | 实际产物 | 状态 |
|---|---|---|
| ASC App 记录创建 | **延后到用户操作**（需 web GUI 或 `/asc-app-create-ui` skill） | ⚠️ 文档化 |
| 隐私营养标签 (Data Not Collected) | `asc/METADATA.md` § "Privacy Nutrition Label" + Q&A | ✅ |
| 截图 4 张 6.7" | **延后**：需要在真机/模拟器手动截屏 | ⚠️ 清单化 |
| App Preview 视频 | **延后**：需要屏幕录制 | ⚠️ 清单化 |
| App Store 文案 | `asc/METADATA.md`（标题/副标题/描述/关键词/促销文/审核 notes） | ✅ |
| Archive + 上传 build | `scripts/archive.sh` + `scripts/ExportOptions.plist` | ✅ |
| 提交清单 | `asc/SUBMISSION-CHECKLIST.md` | ✅ |

## 不能由 LLM 完成的部分（用户必须做）

1. **真机验证 3 回合**：插 iPhone 12 mini，跑 Phase 3 / 5 / 7 验收 (~15 min)
2. **截图 4 张** + **App Preview 30 秒视频**（~30 min）
3. **隐私政策 / 支持页 URL 上线**（GitHub Pages 5 min）
4. **运行 `./scripts/archive.sh`** + 上传 TestFlight build（~10 min）
5. **ASC 后台填 metadata + 选 build + 提交审核**（~20 min）

总计用户介入约 **80 分钟**，分散在 1-2 天。

## DoD

- ✅ 所有"我能写的"已写齐
- ✅ archive.sh 可一键 Archive + Export IPA
- ✅ METADATA.md 是 ASC 文案的真相源
- ✅ SUBMISSION-CHECKLIST.md 是用户流程的 sequence

## 下一步（不在本会话）

→ 用户按 `asc/SUBMISSION-CHECKLIST.md` 走完 A-F 节
→ 监控 ASC 审核结果（24-72h）
→ 上架后启动 ASA $300 投放预算（参考 `.seed/MVP-BRIEF.md` §8）
