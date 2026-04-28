import Foundation

protocol TranscriptionService: Sendable {
    var isAvailable: Bool { get }
    func transcribe(audioURL: URL, recordingId: UUID, locale: Locale) async throws -> Transcript
}

enum TranscriptionError: LocalizedError {
    case unavailable
    case authorizationDenied
    case modelInstallFailed(Error)
    case audioReadFailed(Error)
    case engineFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Transcription is not available on this device or for this language."
        case .authorizationDenied:
            return "Speech recognition permission denied. Enable it in Settings → VoiceFlow."
        case .modelInstallFailed(let e):
            return "Couldn't install the on-device transcription model: \(e.localizedDescription)"
        case .audioReadFailed(let e):
            return "Couldn't read the audio file: \(e.localizedDescription)"
        case .engineFailed(let e):
            return "Transcription engine failed: \(e.localizedDescription)"
        }
    }
}

final class ResumptionGuard: @unchecked Sendable {
    private var done = false
    private let lock = NSLock()

    func tryRun(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        block()
    }
}
