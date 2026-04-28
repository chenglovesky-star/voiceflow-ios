import Foundation

// PHASE 8 stub — wiring point for argmaxinc/WhisperKit when iOS ≤ 25
// or when SFSpeechRecognizer is unavailable for the requested locale.
//
// Activation steps (when needed, e.g. after Phase 3 real-device verification
// reveals a locale gap):
//   1. Add Swift Package: https://github.com/argmaxinc/WhisperKit
//   2. Replace this stub with the WhisperKit pipeline (model load → transcribe → segments)
//   3. Surface a one-time "downloading model (~150MB)" UX on first transcription
//   4. Tests: use a tiny pre-baked .m4a fixture
//
// Until activated, the factory falls back here only when SFSpeechRecognizer
// is unavailable, in which case .unavailable is the correct user-facing error.
final class WhisperKitTranscriptionService: TranscriptionService {
    var isAvailable: Bool { false }

    func transcribe(audioURL: URL, recordingId: UUID, locale: Locale) async throws -> Transcript {
        throw TranscriptionError.unavailable
    }
}
