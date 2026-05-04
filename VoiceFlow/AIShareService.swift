import Foundation
import UIKit

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

    /// URL scheme registered in LSApplicationQueriesSchemes; used to detect install.
    var detectionURL: URL {
        switch self {
        case .perplexity: return URL(string: "perplexity://")!
        case .chatgpt:    return URL(string: "chatgpt://")!
        case .gemini:     return URL(string: "googlegemini://")!
        case .claude:     return URL(string: "claude://")!
        case .doubao:     return URL(string: "bytedance.doubao://")!
        case .kimi:       return URL(string: "kimichat://")!
        case .tongyi:     return URL(string: "tongyi://")!
        }
    }

    /// Web/Universal fallback when App is not installed.
    var webURL: URL {
        switch self {
        case .perplexity: return URL(string: "https://www.perplexity.ai/")!
        case .chatgpt:    return URL(string: "https://chat.openai.com/")!
        case .gemini:     return URL(string: "https://gemini.google.com/app")!
        case .claude:     return URL(string: "https://claude.ai/")!
        case .doubao:     return URL(string: "https://www.doubao.com/")!
        case .kimi:       return URL(string: "https://kimi.moonshot.cn/")!
        case .tongyi:     return URL(string: "https://tongyi.aliyun.com/")!
        }
    }
}

struct AIShareResult: Sendable {
    let target: AITarget
    let installed: Bool
    let opened: Bool
}

@MainActor
struct AIShareService {

    func isInstalled(_ target: AITarget) -> Bool {
        UIApplication.shared.canOpenURL(target.detectionURL)
    }

    /// Copies the transcript to the system clipboard and opens the target App.
    ///
    /// 不再用 `canOpenURL` 当 gate —— 它对未注册到 LSApplicationQueriesSchemes
    /// 的 scheme、或名字稍有出入的 scheme 都会假阴性返回 false，导致即使设备
    /// 装了目标 app 也被错误地导向网页。改成直接 `open(detectionURL)` 试一下
    /// deep link，失败再回退到 `webURL`。
    ///
    /// 三档行为：
    /// 1. 装了 app + scheme 对 → 直接进 app
    /// 2. 装了 app + scheme 错（如 `bytedance.doubao://` 不是豆包真实 scheme）
    ///    → deep link `open` 返回 false → 回退 `webURL`；目标 app 通过
    ///    Apple Universal Links 接管 https 域名，仍然进 app
    /// 3. 没装 app → 两次都失败 → 系统走 Safari
    @discardableResult
    func send(_ text: String, to target: AITarget) async -> AIShareResult {
        UIPasteboard.general.string = text

        // 1. 直接尝试 deep link（不依赖 canOpenURL）
        if await UIApplication.shared.open(target.detectionURL) {
            return AIShareResult(target: target, installed: true, opened: true)
        }

        // 2. Deep link 失败 → 走 https；iOS 自动判断走 Universal Link 还是 Safari
        let opened = await UIApplication.shared.open(target.webURL)
        return AIShareResult(target: target, installed: false, opened: opened)
    }
}
