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

    /// Copies the transcript to the system clipboard and opens the target App
    /// (or its web fallback). Most AI Apps don't accept payloads via URL Scheme,
    /// so the clipboard is the reliable transport — the user pastes once landed.
    @discardableResult
    func send(_ text: String, to target: AITarget) async -> AIShareResult {
        UIPasteboard.general.string = text
        let installed = isInstalled(target)
        let urlToOpen = installed ? target.detectionURL : target.webURL
        let opened = await UIApplication.shared.open(urlToOpen)
        return AIShareResult(target: target, installed: installed, opened: opened)
    }
}
