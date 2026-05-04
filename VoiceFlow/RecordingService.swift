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
    @Published var interruptedError: String?

    /// Duration in seconds after which a new segment is automatically created (default: 10 minutes)
    var segmentDuration: TimeInterval = 600

    private var recorder: AVAudioRecorder?
    private var meteringTimer: Timer?
    private var segmentTimer: Timer?
    private var startedAt: Date?
    private let levelsCapacity = 60

    /// Current recording session
    private var currentSessionId: UUID?
    private var currentSegmentIndex: Int = 0
    private var segments: [Recording] = []

    nonisolated static let recordingsDirectoryName = "recordings"
    nonisolated static let sessionsDirectoryName = "sessions"

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

        // Initialize a new recording session
        currentSessionId = UUID()
        currentSegmentIndex = 0
        segments = []

        let recording = try startNewSegment()

        // Store the first segment
        segments.append(recording)

        isRecording = true
        startMetering()
        startSegmentTimer()
    }

    /// Starts a new recording segment and returns the Recording object
    private func startNewSegment() throws -> Recording {
        let url = Self.makeRecordingURL(sessionId: currentSessionId, segment: currentSegmentIndex)
        let appSettings = AppSettings.shared
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: appSettings.defaultSampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: appSettings.defaultBitRate,
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
        startedAt = Date()
        recentLevels = []
        elapsed = 0
        currentLevel = 0

        return Recording(
            url: url,
            duration: 0,
            createdAt: startedAt!,
            sessionId: currentSessionId,
            segmentIndex: currentSegmentIndex,
            totalSegments: 1 // Will be updated when session ends
        )
    }

    /// Called when a segment duration limit is reached; saves current and starts a new one
    private func advanceToNextSegment() {
        guard let recorder = recorder, let startedAt = startedAt, let sessionId = currentSessionId else { return }

        // Stop current segment
        recorder.stop()
        let duration = Date().timeIntervalSince(startedAt)

        // Update the last segment with actual duration
        let sessionSegmentsCount = segments.count
        let segmentRecording = Recording(
            url: recorder.url,
            duration: duration,
            createdAt: startedAt,
            sessionId: sessionId,
            segmentIndex: currentSegmentIndex,
            totalSegments: sessionSegmentsCount // Will be updated
        )

        // Update segment with correct total count
        if currentSegmentIndex < segments.count {
            segments[currentSegmentIndex] = segmentRecording
        }

        // Start new segment
        currentSegmentIndex += 1
        do {
            let newSegment = try startNewSegment()
            segments.append(newSegment)
        } catch {
            interruptedError = error.localizedDescription
            cleanup()
        }
    }

    private func startSegmentTimer() {
        segmentTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceToNextSegment()
            }
        }
        segmentTimer = timer
    }

    @discardableResult
    func stop() throws -> RecordingSession {
        guard let recorder, let startedAt, let sessionId = currentSessionId else {
            throw RecordingError.notRecording
        }

        // Stop the segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil

        let duration = Date().timeIntervalSince(startedAt)
        recorder.stop()

        // Finalize the last segment
        let finalSegment = Recording(
            url: recorder.url,
            duration: duration,
            createdAt: startedAt,
            sessionId: sessionId,
            segmentIndex: currentSegmentIndex,
            totalSegments: segments.count
        )

        // Update the last segment with actual duration and total count
        if !segments.isEmpty {
            segments[segments.count - 1] = finalSegment
        } else {
            segments.append(finalSegment)
        }

        // Update all segments with correct total count
        let totalSegments = segments.count
        segments = segments.map { segment in
            Recording(
                id: segment.id,
                url: segment.url,
                duration: segment.duration,
                createdAt: segment.createdAt,
                displayName: segment.displayName,
                sessionId: segment.sessionId,
                segmentIndex: segment.segmentIndex,
                totalSegments: totalSegments
            )
        }

        let session = RecordingSession(sessionId: sessionId, segments: segments)

        cleanup()

        return session
    }

    private func startMetering() {
        meteringTimer?.invalidate()
        // 200ms ticks (was 50ms): visually smooth enough for a 30-bar
        // waveform while keeping the run loop responsive for UI tests.
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
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
        segmentTimer?.invalidate()
        segmentTimer = nil
        recorder = nil
        isRecording = false
        startedAt = nil
        elapsed = 0
        currentLevel = 0
        currentSessionId = nil
        currentSegmentIndex = 0
        segments = []
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated static func makeRecordingURL(sessionId: UUID?, segment: Int) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Use session directory for segmented recordings
        if let sessionId = sessionId {
            let sessionDir = docs.appendingPathComponent(sessionsDirectoryName, isDirectory: true)
                .appendingPathComponent(sessionId.uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
            return sessionDir.appendingPathComponent("segment_\(segment).m4a")
        }

        // Fallback for non-segmented recordings
        let dir = docs.appendingPathComponent(recordingsDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(UUID().uuidString).m4a")
    }
}

extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else { return }
        Task { @MainActor [weak self] in
            self?.interruptedError = "录音因系统中断而停止"
            self?.cleanup()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }
}
