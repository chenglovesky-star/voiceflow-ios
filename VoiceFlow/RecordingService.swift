import Foundation
import AVFoundation
import Combine

enum RecordingError: LocalizedError {
    case permissionDenied
    case sessionConfigurationFailed(Error)
    case recorderInitFailed(Error)
    case alreadyRecording
    case notRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied. Enable it in Settings → VoiceFlow."
        case .sessionConfigurationFailed(let e):
            return "Audio session failed: \(e.localizedDescription)"
        case .recorderInitFailed(let e):
            return "Recorder failed to start: \(e.localizedDescription)"
        case .alreadyRecording:
            return "Already recording."
        case .notRecording:
            return "Not currently recording."
        }
    }
}

@MainActor
final class RecordingService: NSObject, ObservableObject {
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var currentLevel: Float = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var recentLevels: [Float] = []

    private var recorder: AVAudioRecorder?
    private var meteringTimer: Timer?
    private var startedAt: Date?
    private let levelsCapacity = 60

    nonisolated static let recordingsDirectoryName = "recordings"

    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func start() async throws {
        guard !isRecording else { throw RecordingError.alreadyRecording }
        guard await requestPermission() else { throw RecordingError.permissionDenied }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: [])
        } catch {
            throw RecordingError.sessionConfigurationFailed(error)
        }

        let url = Self.makeRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let r: AVAudioRecorder
        do {
            r = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            throw RecordingError.recorderInitFailed(error)
        }
        r.isMeteringEnabled = true
        r.delegate = self
        guard r.record() else {
            throw RecordingError.recorderInitFailed(NSError(domain: "VoiceFlow", code: -1))
        }

        recorder = r
        isRecording = true
        startedAt = Date()
        recentLevels = []
        elapsed = 0
        currentLevel = 0
        startMetering()
    }

    @discardableResult
    func stop() throws -> Recording {
        guard let recorder, let startedAt else { throw RecordingError.notRecording }
        let duration = Date().timeIntervalSince(startedAt)
        recorder.stop()
        let recording = Recording(
            url: recorder.url,
            duration: duration,
            createdAt: startedAt
        )
        cleanup()
        return recording
    }

    private func startMetering() {
        meteringTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        meteringTimer = timer
    }

    private func tick() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        let avg = recorder.averagePower(forChannel: 0)
        let normalized = max(0, min(1, (avg + 50) / 50))
        currentLevel = normalized
        recentLevels.append(normalized)
        if recentLevels.count > levelsCapacity {
            recentLevels.removeFirst(recentLevels.count - levelsCapacity)
        }
        if let started = startedAt {
            elapsed = Date().timeIntervalSince(started)
        }
    }

    private func cleanup() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        recorder = nil
        isRecording = false
        startedAt = nil
        elapsed = 0
        currentLevel = 0
    }

    nonisolated static func makeRecordingURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(recordingsDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(UUID().uuidString).m4a")
    }
}

extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // explicit stop() handles state; this fires on background interruption too
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }
}
