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
    /// 识别引擎正常运行但未识别到任何语音片段。常见原因：录音里没有人声、
    /// 距麦克风过远、环境噪声淹没、语言与所选 locale 不匹配。
    case noSpeechDetected

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "On-device speech model is unavailable for this language. iOS may still be downloading it; please retry in a moment.")
        case .authorizationDenied:
            return String(localized: "Speech recognition permission denied. Enable it in Settings → VoiceFlow.")
        case .modelInstallFailed(let e):
            return String(localized: "Couldn't install the on-device transcription model: \(e.localizedDescription)")
        case .audioReadFailed(let e):
            return String(localized: "Couldn't read the audio file: \(e.localizedDescription)")
        case .engineFailed(let e):
            return String(localized: "Transcription engine failed: \(e.localizedDescription)")
        case .noSpeechDetected:
            return String(localized: "No speech detected. Try speaking closer to the mic in a quieter place, or check the transcription language in Settings.")
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
