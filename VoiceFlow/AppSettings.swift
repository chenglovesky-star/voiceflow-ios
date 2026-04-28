import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    enum Keys {
        static let sampleRate = "settings.sampleRate"
        static let bitRate = "settings.bitRate"
        static let iCloudEnabled = "settings.iCloudEnabled"
        static let onboardingComplete = "settings.onboardingComplete"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var defaultSampleRate: Int {
        didSet { defaults.set(defaultSampleRate, forKey: Keys.sampleRate) }
    }
    var defaultBitRate: Int {
        didSet { defaults.set(defaultBitRate, forKey: Keys.bitRate) }
    }
    var iCloudEnabled: Bool {
        didSet { defaults.set(iCloudEnabled, forKey: Keys.iCloudEnabled) }
    }
    var onboardingComplete: Bool {
        didSet { defaults.set(onboardingComplete, forKey: Keys.onboardingComplete) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaultSampleRate = (defaults.object(forKey: Keys.sampleRate) as? Int) ?? 44_100
        self.defaultBitRate = (defaults.object(forKey: Keys.bitRate) as? Int) ?? 64_000
        self.iCloudEnabled = defaults.bool(forKey: Keys.iCloudEnabled)
        self.onboardingComplete = defaults.bool(forKey: Keys.onboardingComplete)
    }
}
