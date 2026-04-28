import Testing
import Foundation
@testable import VoiceFlow

@Suite("AppSettings")
@MainActor
struct AppSettingsTests {

    private func makeDefaults() -> UserDefaults {
        let suite = "voiceflow.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test("defaults: 44.1k / 64kbps / iCloud off / onboarding incomplete")
    func defaults() {
        let s = AppSettings(defaults: makeDefaults())
        #expect(s.defaultSampleRate == 44_100)
        #expect(s.defaultBitRate == 64_000)
        #expect(s.iCloudEnabled == false)
        #expect(s.onboardingComplete == false)
    }

    @Test("changes persist via UserDefaults")
    func persistence() {
        let defaults = makeDefaults()
        let s1 = AppSettings(defaults: defaults)
        s1.defaultSampleRate = 48_000
        s1.defaultBitRate = 128_000
        s1.iCloudEnabled = true
        s1.onboardingComplete = true

        let s2 = AppSettings(defaults: defaults)
        #expect(s2.defaultSampleRate == 48_000)
        #expect(s2.defaultBitRate == 128_000)
        #expect(s2.iCloudEnabled == true)
        #expect(s2.onboardingComplete == true)
    }
}
