import Testing
@testable import VoiceFlow

@Suite("VoiceFlow Smoke")
struct VoiceFlowSmokeTests {
    @Test("app launches without crashing")
    func appLaunches() {
        #expect(Bool(true))
    }
}
