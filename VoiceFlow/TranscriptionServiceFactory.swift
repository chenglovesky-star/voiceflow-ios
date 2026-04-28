import Foundation

struct TranscriptionServiceFactory {
    static func make() -> any TranscriptionService {
        let primary = OnDeviceTranscriptionService()
        if primary.isAvailable {
            return primary
        }
        return WhisperKitTranscriptionService()
    }
}
