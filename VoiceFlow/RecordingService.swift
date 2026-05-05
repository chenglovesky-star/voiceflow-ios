import Foundation
import AVFoundation
import Combine
import os

enum RecordingError: LocalizedError {
    case permissionDenied
    case sessionConfigurationFailed(Error)
    case recorderInitFailed(Error)
    case alreadyRecording
    case notRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "Microphone access denied. Enable it in Settings → VoiceFlow.")
        case .sessionConfigurationFailed(let e):
            return String(localized: "Audio session failed: \(e.localizedDescription)")
        case .recorderInitFailed(let e):
            return String(localized: "Recorder failed to start: \(e.localizedDescription)")
        case .alreadyRecording:
            return String(localized: "Already recording.")
        case .notRecording:
            return String(localized: "Not currently recording.")
        }
    }
}

/// 录前环境探测的结果。让用户在正式开录前先确认环境质量。
struct EnvironmentProbe: Equatable {
    /// 探测窗口内 averagePower 的均值（dB，AVAudioRecorder scale: -160=silence, 0=clipping）
    let avgDB: Float
    /// 探测窗口内 peakPower 的最大值
    let peakDB: Float
    /// 探测时长（秒）
    let durationSeconds: TimeInterval
    /// 探测完成时刻；UI 用于"超过 N 秒未操作则自动重测"的防鲜判断
    let timestamp: Date
    /// 探测分类。基于 iPhone 17 Pro 实测的安静环境（-41 ~ -45 dB）来标定阈值。
    let quality: Quality

    enum Quality: Equatable {
        case quiet        // avg < -38 dB，环境很安静
        case acceptable   // -38 ≤ avg ≤ -28 dB，可以录音
        case noisy        // avg > -28 dB，环境过吵
        case clipping     // peak > -3 dB，信号过载（往往是离麦克风太近）
    }

    /// "可以直接进入录音"的友好结果（quiet / acceptable）
    var isFavorable: Bool {
        switch quality {
        case .quiet, .acceptable: return true
        case .noisy, .clipping:   return false
        }
    }

    var headline: String {
        switch quality {
        case .quiet:      return String(localized: "Environment is quiet")
        case .acceptable: return String(localized: "Environment is OK")
        case .noisy:      return String(localized: "Environment is noisy")
        case .clipping:   return String(localized: "Audio level too high")
        }
    }

    var detail: String {
        switch quality {
        case .quiet:      return String(localized: "Ready to record")
        case .acceptable: return String(localized: "Ready to record")
        case .noisy:      return String(localized: "Move to a quieter place; otherwise transcription may be inaccurate")
        case .clipping:   return String(localized: "Move further from the mic and retry")
        }
    }

    var systemImage: String {
        switch quality {
        case .quiet:      return "checkmark.circle.fill"
        case .acceptable: return "checkmark.circle"
        case .noisy:      return "speaker.wave.3.fill"
        case .clipping:   return "waveform.badge.exclamationmark"
        }
    }
}

/// 录音过程中的环境质量提醒。仅作 UI 提示，不阻断录音。
enum NoiseWarning: Equatable {
    /// 环境本底过吵（baseline > -30 dB）；语音可能被噪声淹没。
    case noisyEnvironment
    /// 信号电平接近 baseline（SNR < 6 dB）持续若干秒；用户可能离麦克风太远或音量太低。
    case tooQuiet
    /// 峰值持续接近 0 dB；存在削波失真。
    case clipping

    var message: String {
        switch self {
        case .noisyEnvironment:
            return String(localized: "Background noise is high — transcription may be inaccurate.")
        case .tooQuiet:
            return String(localized: "Speak louder or move closer to the mic.")
        case .clipping:
            return String(localized: "Audio is clipping — move further from the mic.")
        }
    }

    var systemImage: String {
        switch self {
        case .noisyEnvironment: return "speaker.wave.3.fill"
        case .tooQuiet:         return "mic.slash"
        case .clipping:         return "waveform.badge.exclamationmark"
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
    /// 当前录音过程中的环境提醒；nil 表示无问题。仅提示，不打断录音。
    @Published private(set) var noiseWarning: NoiseWarning?

    /// Duration in seconds after which a new segment is automatically created (default: 10 minutes)
    var segmentDuration: TimeInterval = 600

    private var recorder: AVAudioRecorder?
    private var meteringTimer: Timer?
    private var segmentTimer: Timer?
    private var startedAt: Date?
    private let levelsCapacity = 60

    // 等待 audioRecorderDidFinishRecording 触发后再 return —— AAC 编码器
    // 的尾部 flush 是异步的，过早读取 m4a 会拿到不完整文件，
    // 导致 SFSpeechURLRecognitionRequest 解码后无可识别音频，最终转录为空。
    private var stopContinuation: CheckedContinuation<Bool, Never>?

    // 噪声检测相关。录音开始头 1s 采集 baseline averagePower，之后每个
    // 200ms tick 用「当前 averagePower - baseline」估计 SNR。
    // 阈值参考 AVAudioRecorder dB scale：-160=silence, 0=clipping。
    private var baselineDB: Float?
    private var baselineSamples: [Float] = []
    private var baselineDeadline: Date?
    private var lowSNRTicks: Int = 0
    private var clippingTicks: Int = 0
    private static let baselineWindow: TimeInterval = 1.0
    private static let lowSNRThresholdDB: Float = 6
    private static let lowSNRTicksRequired = 15        // 3 秒（200ms × 15）
    private static let clippingThresholdDB: Float = -3
    private static let clippingTicksRequired = 5       // 1 秒（200ms × 5）
    private static let noisyBaselineThresholdDB: Float = -30

    /// Current recording session
    private var currentSessionId: UUID?
    private var currentSegmentIndex: Int = 0
    private var segments: [Recording] = []

    nonisolated static let recordingsDirectoryName = "recordings"
    nonisolated static let sessionsDirectoryName = "sessions"

    // metadata-only 日志，用于诊断 finalize 失败、文件大小等。永不记录音频内容。
    // nonisolated 让 delegate 回调（也是 nonisolated）可以访问。
    nonisolated static let log = Logger(subsystem: "com.voiceflow.app", category: "recording")

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

    /// 启动录音。
    /// - Parameter externalBaseline: 来自 `probeEnvironment()` 的环境基线 dB；
    ///   提供后跳过录音头 1s 自采，直接用 probe 值做后续 SNR 监控。
    func start(externalBaseline: Float? = nil) async throws {
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

        // Baseline 初始化：优先使用 probe 值；否则启用录音头 1s 自采窗口（兜底路径）
        if let externalBaseline {
            baselineDB = externalBaseline
            baselineSamples = []
            baselineDeadline = nil
            noiseWarning = externalBaseline > Self.noisyBaselineThresholdDB ? .noisyEnvironment : nil
            Self.log.info("baseline injected from probe: \(String(format: "%.1f", externalBaseline)) dB")
        } else {
            baselineDB = nil
            baselineSamples = []
            baselineDeadline = Date().addingTimeInterval(Self.baselineWindow)
            noiseWarning = nil
        }
        lowSNRTicks = 0
        clippingTicks = 0

        let recording = try startNewSegment()

        // Store the first segment
        segments.append(recording)

        isRecording = true
        startMetering()
        startSegmentTimer()
    }

    /// 录前环境探测：用一个临时 recorder 在指定时长内采样麦克风电平，
    /// 探测期间 `currentLevel` 仍会更新以驱动 UI 实时电平条。结束后自动清理临时文件与 audio session。
    /// - Parameter duration: 探测时长（默认 1.5s）
    /// - Returns: 探测结果，包含 avg/peak dB 和质量分类
    func probeEnvironment(duration: TimeInterval = 1.5) async throws -> EnvironmentProbe {
        guard !isRecording else { throw RecordingError.alreadyRecording }
        guard await requestPermission() else { throw RecordingError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: [])
        } catch {
            throw RecordingError.sessionConfigurationFailed(error)
        }

        // 临时探针文件，写到 tmp，结束后立即删除（探针不留档）
        let probeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("probe-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000
        ]

        let r: AVAudioRecorder
        do {
            r = try AVAudioRecorder(url: probeURL, settings: settings)
        } catch {
            throw RecordingError.recorderInitFailed(error)
        }
        r.isMeteringEnabled = true
        guard r.record() else {
            throw RecordingError.recorderInitFailed(NSError(domain: "VoiceFlow", code: -1))
        }

        Self.log.info("probe begin: duration=\(duration)s")

        var avgs: [Float] = []
        var peaks: [Float] = []
        let started = Date()
        // 100ms 采样间隔，1.5s ≈ 15 个样本
        while Date().timeIntervalSince(started) < duration {
            try? await Task.sleep(nanoseconds: 100_000_000)
            r.updateMeters()
            let avg = r.averagePower(forChannel: 0)
            let peak = r.peakPower(forChannel: 0)
            avgs.append(avg)
            peaks.append(peak)
            // 驱动 UI 电平条
            currentLevel = max(0, min(1, (avg + 50) / 50))
        }
        r.stop()
        try? FileManager.default.removeItem(at: probeURL)
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        currentLevel = 0

        let avgDB = avgs.isEmpty ? Float(-160) : avgs.reduce(0, +) / Float(avgs.count)
        let peakDB = peaks.max() ?? Float(-160)
        let quality = Self.classifyEnvironment(avgDB: avgDB, peakDB: peakDB)
        Self.log.info("probe done: avg=\(String(format: "%.1f", avgDB))dB peak=\(String(format: "%.1f", peakDB))dB quality=\(String(describing: quality), privacy: .public)")

        return EnvironmentProbe(
            avgDB: avgDB,
            peakDB: peakDB,
            durationSeconds: duration,
            timestamp: Date(),
            quality: quality
        )
    }

    private static func classifyEnvironment(avgDB: Float, peakDB: Float) -> EnvironmentProbe.Quality {
        if peakDB > clippingThresholdDB { return .clipping }
        if avgDB > -28 { return .noisy }
        if avgDB > -38 { return .acceptable }
        return .quiet
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
        let now = Date()
        startedAt = now
        recentLevels = []
        elapsed = 0
        currentLevel = 0

        // baseline / noiseWarning 状态由 start() 统一接管；分段切换内不动它们。

        return Recording(
            url: url,
            duration: 0,
            createdAt: now,
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
    func stop() async throws -> RecordingSession {
        guard let recorder, let startedAt, let sessionId = currentSessionId else {
            throw RecordingError.notRecording
        }

        // Stop the segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil

        let duration = Date().timeIntervalSince(startedAt)

        // 等 AVAudioRecorderDelegate.audioRecorderDidFinishRecording 回调，
        // 确保 m4a 文件 moov atom + 全部音频帧已落盘，转录器读到的是完整文件。
        // 同时设置 1.5s 守门时限，防止某些情况下 delegate 永不触发卡死 UI。
        let success = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            stopContinuation = cont
            recorder.stop()

            // 守门定时器：若 1.5s 内 delegate 未触发，认定 finalize 失败但继续流程
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                if let pending = self.stopContinuation {
                    self.stopContinuation = nil
                    Self.log.error("stop: finalize timeout (1.5s); proceeding with potentially incomplete file")
                    pending.resume(returning: false)
                }
            }
        }
        Self.log.info("stop: finalize success=\(success), duration=\(String(format: "%.2f", duration))s")

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
        let peak = recorder.peakPower(forChannel: 0)
        let normalized = max(0, min(1, (avg + 50) / 50))
        currentLevel = normalized
        recentLevels.append(normalized)
        if recentLevels.count > levelsCapacity {
            recentLevels.removeFirst(recentLevels.count - levelsCapacity)
        }
        if let started = startedAt {
            elapsed = Date().timeIntervalSince(started)
        }

        updateNoiseDiagnostics(avgDB: avg, peakDB: peak)
    }

    /// 用 averagePower / peakPower 估计录音环境质量并更新 noiseWarning。
    /// 头 1s 采 baseline，之后用 SNR 判 tooQuiet、用 peak 判 clipping、用 baseline 判 noisyEnvironment。
    private func updateNoiseDiagnostics(avgDB: Float, peakDB: Float) {
        // 仍在 baseline 采集窗口
        if let deadline = baselineDeadline, Date() < deadline {
            baselineSamples.append(avgDB)
            return
        }
        // 窗口结束的第一个 tick：定型 baseline
        if baselineDB == nil, !baselineSamples.isEmpty {
            let mean = baselineSamples.reduce(0, +) / Float(baselineSamples.count)
            baselineDB = mean
            Self.log.info("noise baseline established: \(String(format: "%.1f", mean)) dB across \(self.baselineSamples.count) samples")
            if mean > Self.noisyBaselineThresholdDB {
                noiseWarning = .noisyEnvironment
            }
            baselineSamples.removeAll(keepingCapacity: false)
        }

        guard let baseline = baselineDB else { return }

        // Clipping 检测：peak 持续高位
        if peakDB > Self.clippingThresholdDB {
            clippingTicks += 1
            if clippingTicks >= Self.clippingTicksRequired {
                noiseWarning = .clipping
            }
        } else {
            clippingTicks = 0
        }

        // SNR 检测：信号距 baseline 太近
        let snr = avgDB - baseline
        if snr < Self.lowSNRThresholdDB {
            lowSNRTicks += 1
            if lowSNRTicks >= Self.lowSNRTicksRequired,
               noiseWarning != .clipping,
               noiseWarning != .noisyEnvironment {
                noiseWarning = .tooQuiet
            }
        } else {
            lowSNRTicks = 0
            // 信号回到正常区间且当前是 tooQuiet 提示，清除以让下一次提醒重新触发
            if noiseWarning == .tooQuiet { noiseWarning = nil }
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
        baselineDB = nil
        baselineSamples = []
        baselineDeadline = nil
        lowSNRTicks = 0
        clippingTicks = 0
        noiseWarning = nil
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
        let url = recorder.url
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? -1
        Self.log.info("audioRecorderDidFinishRecording: success=\(flag), file size=\(size) bytes, name=\(url.lastPathComponent, privacy: .public)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            // 显式 stop() 在等这个 continuation；resume 后由 stop() 继续 finalize segments。
            if let cont = self.stopContinuation {
                self.stopContinuation = nil
                cont.resume(returning: flag)
                return
            }
            // 否则是系统中断（来电/路由变化等），按原中断流程处理。
            // 注意：advanceToNextSegment 内的 recorder.stop() 也会触发本回调，
            // 但那时立刻又开了新 recorder、isRecording 仍为 true，flag 通常为 true 不进 cleanup。
            if !flag {
                self.interruptedError = "录音因系统中断而停止"
                self.cleanup()
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Self.log.error("audioRecorderEncodeErrorDidOccur: \(error?.localizedDescription ?? "nil", privacy: .public)")
        Task { @MainActor [weak self] in
            self?.interruptedError = error?.localizedDescription ?? "录音编码错误"
            self?.cleanup()
        }
    }
}
