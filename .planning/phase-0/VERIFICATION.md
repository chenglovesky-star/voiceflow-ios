# Phase 0 — Environment Verification

> Date: 2026-04-28
> Goal: 确保开发环境满足 ROADMAP §3 不可妥协约束

## 工具链

| 项 | 期望 | 实际 | 状态 |
|---|---|---|---|
| Xcode | ≥ 26.0 | 26.2 (17C52) | ✅ |
| macOS | ≥ 26.0 | 26.1 (25B78) | ✅ |
| iOS SDK | ≥ 26.0 | 26.2 | ✅ |
| Swift | ≥ 6.0 | bundled with Xcode 26.2 | ✅ |
| xcodegen | any | 已安装 (`/opt/homebrew/bin/xcodegen`) | ✅ |
| Homebrew | any | 5.1.6 | ✅ |
| git | any | system | ✅ |

## Apple 资产

| 项 | 状态 | 详情 |
|---|---|---|
| Apple Developer Team | ✅ | `7337LF5P35` (Lei cheng) |
| Apple Distribution 证书 | ✅ | 7E8FEC7DC15ECE5BDC87367BB2F8ED80C0F5C351 |
| Apple Development 证书 | ✅ | 4174AAF473BA8D883B7CEEF4DDDBBBCD0DE276BF |
| ASC API Key (.p8) | ✅ | `~/.blitz/AuthKey_546FUCYC9Z.p8` |

## 真机

| 设备 | 状态 | 备注 |
|---|---|---|
| iPhone 12 (iPhone13,2) | unavailable (未连线) | Phase 3 / 5 / 10 时插线即可 |
| iPhone 12 mini (iPhone13,1) | unavailable (未连线) | 同上，建议作为主测试机 |
| Apple Watch S5,12 | unavailable | 非阻塞 |

## git 身份

- user.name: `aaa`
- user.email: `leicheng9@iflytek.com`

## 阻塞项

无。所有 Phase 1 启动条件满足。

## DoD 满足

- [x] Xcode 26+ 可用
- [x] macOS 26+ 可用
- [x] 签名证书可用
- [x] ASC Key 可用
- [x] xcodegen 可用
- [x] 实机配对（连线时刻可用）

→ 进入 Phase 1。
