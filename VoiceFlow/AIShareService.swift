import Foundation
import UIKit

/// 详情页"Send to AI"子菜单展示的海外 AI 品牌入口。
///
/// **只保留 URL scheme 公开真实可用的 4 家**——这些 deep link 能一键
/// 直送 app（用户最佳体验）。国产 AI（豆包/Kimi/通义/DeepSeek/文心/元宝/星火/智谱…）
/// 一律不公开自家 scheme，硬猜命中率极低且会随版本失效，故合并到一个
/// `ShareLink("分享给其他 AI…")` 入口由系统 Share Sheet 接管：
///   - 列出所有装了 Share Extension 的 AI app
///   - 用户选择后文本直送目标 app 输入框（不再走 Safari 网页）
///   - 自动支持新出现的 AI app（无需我们更新代码）
enum AITarget: String, CaseIterable, Sendable {
    case perplexity
    case chatgpt
    case gemini
    case claude

    var displayName: String {
        switch self {
        case .perplexity: return "Perplexity"
        case .chatgpt:    return "ChatGPT"
        case .gemini:     return "Gemini"
        case .claude:     return "Claude"
        }
    }

    var systemImage: String { "sparkles" }

    /// 官方公开/已验证的 URL scheme。
    var detectionURL: URL {
        switch self {
        case .perplexity: return URL(string: "perplexity://")!
        case .chatgpt:    return URL(string: "chatgpt://")!
        case .gemini:     return URL(string: "googlegemini://")!
        case .claude:     return URL(string: "claude://")!
        }
    }

    /// Deep link 失败时的兜底 https URL —— iOS 会经 Apple Universal Links
    /// 路由进 app（如果 app 在 AASA 里声明了该域名）；否则进 Safari。
    var webURL: URL {
        switch self {
        case .perplexity: return URL(string: "https://www.perplexity.ai/")!
        case .chatgpt:    return URL(string: "https://chat.openai.com/")!
        case .gemini:     return URL(string: "https://gemini.google.com/app")!
        case .claude:     return URL(string: "https://claude.ai/")!
        }
    }
}

@MainActor
struct AIShareService {
    /// 把转录文本复制到剪贴板（兜底），然后直接尝试 deep link 进 app。
    /// 不依赖 `canOpenURL` gate（它对未在 LSApplicationQueriesSchemes 声明的
    /// scheme 会假阴性）；deep link 失败再尝试 https URL，由 iOS 自动经
    /// Universal Link 路由进 app 或回退 Safari。
    @discardableResult
    func send(_ text: String, to target: AITarget) async -> Bool {
        UIPasteboard.general.string = text

        // 1. 直接尝试 deep link
        if await UIApplication.shared.open(target.detectionURL) {
            return true
        }
        // 2. 回退 https（Universal Link / Safari 由系统决定）
        return await UIApplication.shared.open(target.webURL)
    }
}
