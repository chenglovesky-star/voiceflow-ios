import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Keys {
        static let sampleRate = "settings.sampleRate"
        static let bitRate = "settings.bitRate"
        static let iCloudEnabled = "settings.iCloudEnabled"
        static let onboardingComplete = "settings.onboardingComplete"
        static let transcriptionLocaleId = "settings.transcriptionLocaleId"
        static let waveformStyleId = "settings.waveformStyleId"
        static let appLocaleId = "settings.appLocaleId"
    }

    static let autoLocaleId = "auto"

    /// app 显示语言可选项（独立于 transcription locale）。
    /// "auto" 表示跟随系统语言；其他值是 BCP-47 标识符，对应 String Catalog 里的 locale 条目。
    static let appLocaleOptions: [(id: String, displayName: String)] = [
        (autoLocaleId, "Auto (system language)"),
        ("en",         "English"),
        ("zh-Hans",    "简体中文"),
        ("zh-Hant",    "繁體中文"),
        ("ja",         "日本語"),
        ("ko",         "한국어"),
        ("fr",         "Français"),
        ("de",         "Deutsch"),
        ("es",         "Español"),
    ]

    private let defaults: UserDefaults

    @Published var defaultSampleRate: Int {
        didSet { defaults.set(defaultSampleRate, forKey: Keys.sampleRate) }
    }
    @Published var defaultBitRate: Int {
        didSet { defaults.set(defaultBitRate, forKey: Keys.bitRate) }
    }
    @Published var iCloudEnabled: Bool {
        didSet { defaults.set(iCloudEnabled, forKey: Keys.iCloudEnabled) }
    }
    @Published var onboardingComplete: Bool {
        didSet { defaults.set(onboardingComplete, forKey: Keys.onboardingComplete) }
    }
    @Published var transcriptionLocaleId: String {
        didSet { defaults.set(transcriptionLocaleId, forKey: Keys.transcriptionLocaleId) }
    }
    @Published var waveformStyleId: String {
        didSet { defaults.set(waveformStyleId, forKey: Keys.waveformStyleId) }
    }
    @Published var appLocaleId: String {
        didSet { defaults.set(appLocaleId, forKey: Keys.appLocaleId) }
    }

    var transcriptionLocale: Locale {
        if transcriptionLocaleId == Self.autoLocaleId { return .current }
        return Locale(identifier: transcriptionLocaleId)
    }

    /// 录音视觉化样式。未设置时默认 .ecg（心电图）。
    var waveformStyle: WaveformStyle {
        WaveformStyle(rawValue: waveformStyleId) ?? .ecg
    }

    /// 注入到 SwiftUI `\.locale` environment 的最终生效 Locale。
    /// "auto" 返回 nil 让 SwiftUI 用系统默认；其他返回对应 BCP-47 Locale。
    var effectiveLocale: Locale? {
        if appLocaleId == Self.autoLocaleId { return nil }
        return Locale(identifier: appLocaleId)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultSampleRate = (defaults.object(forKey: Keys.sampleRate) as? Int) ?? 44_100
        self.defaultBitRate = (defaults.object(forKey: Keys.bitRate) as? Int) ?? 64_000
        self.iCloudEnabled = defaults.bool(forKey: Keys.iCloudEnabled)
        self.onboardingComplete = defaults.bool(forKey: Keys.onboardingComplete)
        self.transcriptionLocaleId = defaults.string(forKey: Keys.transcriptionLocaleId) ?? Self.autoLocaleId
        self.waveformStyleId = defaults.string(forKey: Keys.waveformStyleId) ?? WaveformStyle.ecg.rawValue
        self.appLocaleId = defaults.string(forKey: Keys.appLocaleId) ?? Self.autoLocaleId
    }
}
