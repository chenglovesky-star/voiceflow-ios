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
    }

    static let autoLocaleId = "auto"

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

    var transcriptionLocale: Locale {
        if transcriptionLocaleId == Self.autoLocaleId { return .current }
        return Locale(identifier: transcriptionLocaleId)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultSampleRate = (defaults.object(forKey: Keys.sampleRate) as? Int) ?? 44_100
        self.defaultBitRate = (defaults.object(forKey: Keys.bitRate) as? Int) ?? 64_000
        self.iCloudEnabled = defaults.bool(forKey: Keys.iCloudEnabled)
        self.onboardingComplete = defaults.bool(forKey: Keys.onboardingComplete)
        self.transcriptionLocaleId = defaults.string(forKey: Keys.transcriptionLocaleId) ?? Self.autoLocaleId
    }
}
