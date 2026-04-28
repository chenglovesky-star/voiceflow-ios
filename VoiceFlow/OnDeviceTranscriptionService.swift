import Foundation
import Speech

// PHASE 3 v1 — SFSpeechRecognizer with on-device recognition.
// Honors ROADMAP §3 hard constraints: local, free, no upload.
//
// PHASE 3 v2 (planned, after real-device verification of v1):
//   Migrate to SpeechAnalyzer + SpeechTranscriber on iOS 26+ for superior
//   long-form quality and built-in word-level timestamps.
//   See WWDC 2025 session 277 and developer.apple.com/documentation/Speech.
final class OnDeviceTranscriptionService: TranscriptionService {

    var isAvailable: Bool {
        guard let recognizer = SFSpeechRecognizer(locale: .current) else { return false }
        return recognizer.isAvailable
    }

    func transcribe(audioURL: URL, recordingId: UUID, locale: Locale) async throws -> Transcript {
        let status = await Self.requestAuthorization()
        guard status == .authorized else {
            throw TranscriptionError.authorizationDenied
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }
        recognizer.defaultTaskHint = .dictation

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        let guardian = ResumptionGuard()

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    guardian.tryRun {
                        continuation.resume(throwing: TranscriptionError.engineFailed(error))
                    }
                    return
                }
                guard let result, result.isFinal else { return }

                let transcription = result.bestTranscription
                let segments = transcription.segments.map { seg -> TranscriptSegment in
                    TranscriptSegment(
                        text: seg.substring,
                        start: seg.timestamp,
                        end: seg.timestamp + seg.duration,
                        confidence: Double(seg.confidence)
                    )
                }
                let transcript = Transcript(
                    recordingId: recordingId,
                    segments: segments,
                    locale: locale.identifier
                )
                guardian.tryRun {
                    continuation.resume(returning: transcript)
                }
            }
        }
    }

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
