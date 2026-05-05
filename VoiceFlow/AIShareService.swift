import Foundation
import UIKit

/// 详情页"Send to AI"子菜单展示的 AI 品牌列表。
/// 仅保留 displayName 用于 UI；不再依赖 URL scheme 直送 deep link
/// （字节系不公开自家 scheme，猜测的 `bytedance.doubao://` 在真机上会
/// LSApplicationNotFoundErr，回退 webURL 又走 Safari），改由系统 Share Sheet
/// 接管：用户点品牌入口 → 弹 Share Sheet → 目标 app 的 Share Extension 把
/// 文本直送对话框，无需粘贴。
enum AITarget: String, CaseIterable, Sendable {
    case perplexity
    case chatgpt
    case gemini
    case claude
    case doubao
    case kimi
    case tongyi

    var displayName: String {
        switch self {
        case .perplexity: return "Perplexity"
        case .chatgpt:    return "ChatGPT"
        case .gemini:     return "Gemini"
        case .claude:     return "Claude"
        case .doubao:     return "豆包"
        case .kimi:       return "Kimi"
        case .tongyi:     return "通义"
        }
    }

    var systemImage: String { "sparkles" }
}

@MainActor
struct AIShareService {

    /// 把转录文本复制到剪贴板（兜底：用户在 Share Sheet 取消时仍能去任意 app 粘贴），
    /// 并返回准备好的 share payload。调用方负责用 ShareSheet 呈现该 payload —
    /// 系统会列出所有支持文本分享的 app（豆包/ChatGPT/Claude/Kimi/微信/备忘录...），
    /// 用户选定后文本直送目标 app 输入框。
    func prepare(_ text: String) -> [Any] {
        UIPasteboard.general.string = text
        return [text]
    }
}
