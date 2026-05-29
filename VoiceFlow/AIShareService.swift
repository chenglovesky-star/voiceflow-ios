import Foundation
import UIKit

/// 详情页"发送到 AI"子菜单展示的国产 AI 品牌入口。
///
/// 国产 AI 的 iOS 客户端绝大多数没有注册 Share Extension，因此不会出现在系统
/// Share Sheet 里——只能在 app 内主动给入口，否则用户压根看不见。
///
/// iOS 14+ `UIApplication.open` 不需要在 Info.plist 的
/// `LSApplicationQueriesSchemes` 里声明 scheme 即可拉起目标 app；scheme
/// 失败则回退 https，由系统 Universal Link 决定进 app 还是 Safari。
enum AITarget: String, CaseIterable, Sendable {
    case doubao
    case deepseek
    case qwen
    case kimi

    var displayName: String {
        switch self {
        case .doubao:   return "豆包"
        case .deepseek: return "DeepSeek"
        case .qwen:     return "通义千问"
        case .kimi:     return "Kimi"
        }
    }

    var systemImage: String { "sparkles" }

    /// 官方公开/已验证的 URL scheme。
    var detectionURL: URL {
        switch self {
        case .doubao:   return URL(string: "doubao://")!
        case .deepseek: return URL(string: "deepseek://")!
        case .qwen:     return URL(string: "tongyi://")!
        case .kimi:     return URL(string: "kimi://")!
        }
    }

    /// Deep link 失败时的兜底 https URL —— iOS 会经 Apple Universal Links
    /// 路由进 app（如果 app 在 AASA 里声明了该域名）；否则进 Safari。
    var webURL: URL {
        switch self {
        case .doubao:   return URL(string: "https://www.doubao.com/chat/")!
        case .deepseek: return URL(string: "https://chat.deepseek.com/")!
        case .qwen:     return URL(string: "https://tongyi.aliyun.com/qianwen/")!
        case .kimi:     return URL(string: "https://kimi.moonshot.cn/")!
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
