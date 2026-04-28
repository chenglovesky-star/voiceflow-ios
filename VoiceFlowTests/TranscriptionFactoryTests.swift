import Testing
import Foundation
@testable import VoiceFlow

@Suite("TranscriptionServiceFactory")
struct TranscriptionFactoryTests {

    @Test("factory returns a non-nil TranscriptionService")
    func makeReturnsService() {
        let svc = TranscriptionServiceFactory.make()
        // Either OnDeviceTranscriptionService (sim with locale) or WhisperKit stub
        // should be returned without crashing.
        _ = svc.isAvailable
    }
}

@Suite("WhisperKitTranscriptionService stub")
struct WhisperStubTests {

    @Test("stub reports unavailable")
    func unavailable() {
        let svc = WhisperKitTranscriptionService()
        #expect(svc.isAvailable == false)
    }

    @Test("stub throws TranscriptionError.unavailable")
    func throwsUnavailable() async {
        let svc = WhisperKitTranscriptionService()
        do {
            _ = try await svc.transcribe(
                audioURL: URL(fileURLWithPath: "/tmp/x.m4a"),
                recordingId: UUID(),
                locale: .current
            )
            Issue.record("Stub should throw")
        } catch let error as TranscriptionError {
            switch error {
            case .unavailable: break
            default: Issue.record("Wrong error case: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
