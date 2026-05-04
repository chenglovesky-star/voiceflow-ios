import Foundation

struct TranscriptionServiceFactory {
    static func make(locale: Locale = .current) -> any TranscriptionService {
        let primary = OnDeviceTranscriptionService()
        if primary.isAvailable(for: locale) {
            return primary
        }
        return WhisperKitTranscriptionService()
    }
}
