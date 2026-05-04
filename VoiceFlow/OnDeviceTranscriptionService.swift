import Foundation
import Speech
import os

// PHASE 3 v1 — SFSpeechRecognizer with on-device recognition.
// Honors ROADMAP §3 hard constraints: local, free, no upload.
//
// PHASE 3 v2 (planned, after real-device verification of v1):
//   Migrate to SpeechAnalyzer + SpeechTranscriber on iOS 26+ for superior
//   long-form quality and built-in word-level timestamps.
//   See WWDC 2025 session 277 and developer.apple.com/documentation/Speech.
//
// v1.1 优化：
//   1. Locale 归一化 — 从 supportedLocales() 中找最佳匹配，含中文专用回退链
//   2. Recognizer 可用性等待 — 模型首次加载时最多轮询 3 秒
//   3. 90 秒识别超时 — Task.detached 竞争取消，防止永久挂起
final class OnDeviceTranscriptionService: TranscriptionService {

    // 仅记录 metadata（locale、segment count、timing 等），永不记录转录文本本身。
    // subsystem 命名空间隔离，发布版保留以便用户用 Console.app 抓诊断信息。
    private static let log = Logger(subsystem: "com.voiceflow.app", category: "transcription")

    var isAvailable: Bool { isAvailable(for: .current) }

    func isAvailable(for locale: Locale) -> Bool {
        guard let resolvedLocale = Self.resolvedLocale(for: locale) else { return false }
        guard let recognizer = SFSpeechRecognizer(locale: resolvedLocale) else { return false }
        return recognizer.isAvailable
    }

    func transcribe(audioURL: URL, recordingId: UUID, locale: Locale) async throws -> Transcript {
        let started = Date()
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64) ?? -1
        Self.log.info("transcribe begin: requested locale=\(locale.identifier, privacy: .public), file size=\(fileSize) bytes")

        let status = await Self.requestAuthorization()
        guard status == .authorized else {
            Self.log.error("transcribe abort: authorization status=\(status.rawValue, privacy: .public)")
            throw TranscriptionError.authorizationDenied
        }

        // locale 归一化：从 supportedLocales 找最佳匹配
        guard let resolvedLocale = Self.resolvedLocale(for: locale) else {
            Self.log.error("transcribe abort: no supported locale for \(locale.identifier, privacy: .public)")
            throw TranscriptionError.unavailable
        }

        guard let recognizer = SFSpeechRecognizer(locale: resolvedLocale) else {
            Self.log.error("transcribe abort: SFSpeechRecognizer init failed for \(resolvedLocale.identifier, privacy: .public)")
            throw TranscriptionError.unavailable
        }

        Self.log.info("recognizer ready: resolved locale=\(resolvedLocale.identifier, privacy: .public), supportsOnDevice=\(recognizer.supportsOnDeviceRecognition), isAvailable=\(recognizer.isAvailable)")

        // 等待可用（模型首次加载时 isAvailable 可能暂时为 false）
        // waitForAvailability 现为 throws，CancellationError 直接向上传播
        guard try await Self.waitForAvailability(recognizer) else {
            Self.log.error("transcribe abort: recognizer not available after wait, locale=\(resolvedLocale.identifier, privacy: .public)")
            throw TranscriptionError.unavailable
        }

        recognizer.defaultTaskHint = .dictation

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        // 带超时保护的识别（90 秒）
        let transcript = try await doRecognizeWithTimeout(
            recognizer: recognizer,
            request: request,
            recordingId: recordingId,
            locale: resolvedLocale,
            timeoutSeconds: 90
        )

        let elapsed = Date().timeIntervalSince(started)
        Self.log.info("transcribe done: segments=\(transcript.segments.count), elapsed=\(String(format: "%.2f", elapsed))s")
        return transcript
    }

    // MARK: - Locale 归一化

    /// 从 SFSpeechRecognizer.supportedLocales() 中找最佳匹配。
    /// 优先级：完全匹配 → BCP-47 字符串匹配 → 中文专用回退链 → language 匹配
    private static func resolvedLocale(for locale: Locale) -> Locale? {
        let supported = SFSpeechRecognizer.supportedLocales()

        // 完全匹配（set contains）
        if supported.contains(locale) { return locale }

        // BCP-47 identifier 字符串匹配（处理下划线/连字符差异）
        let id = locale.identifier
        let normalizedId = id.replacingOccurrences(of: "_", with: "-")
        if let match = supported.first(where: {
            $0.identifier.replacingOccurrences(of: "_", with: "-") == normalizedId
        }) { return match }

        // 中文专用回退链
        if id.hasPrefix("zh") {
            let zhCandidates = [
                "zh-Hans-CN", "zh_Hans_CN",
                "zh-Hans",    "zh_Hans",
                "zh-Hant-TW", "zh_Hant_TW",
                "zh-Hant-CN", "zh_Hant_CN",
                "zh-Hant",    "zh_Hant",
                "zh-CN",      "zh_CN",
                "zh"
            ]
            for candidate in zhCandidates {
                let l = Locale(identifier: candidate)
                if supported.contains(l) { return l }
                let normalized = candidate.replacingOccurrences(of: "_", with: "-")
                if let match = supported.first(where: {
                    $0.identifier.replacingOccurrences(of: "_", with: "-") == normalized
                }) { return match }
            }
        }

        // language 匹配（忽略 region/script），兼容 iOS 16+
        let lang = (locale as NSLocale).object(forKey: .languageCode) as? String ?? ""
        if !lang.isEmpty,
           let match = supported.first(where: {
               (($0 as NSLocale).object(forKey: .languageCode) as? String) == lang
           }) {
            return match
        }

        return nil
    }

    // MARK: - 可用性等待

    /// 等待 recognizer 可用，最多轮询 timeout 秒（默认 3 秒）。
    /// 解决首次加载语言模型时 isAvailable 暂时为 false 的问题。
    /// throws：CancellationError 当外层 Swift Task 被取消时向上传播，不再静默吞掉取消信号。
    private static func waitForAvailability(
        _ recognizer: SFSpeechRecognizer,
        timeout: TimeInterval = 3.0
    ) async throws -> Bool {
        if recognizer.isAvailable { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒；Task 取消时抛出 CancellationError
            if recognizer.isAvailable { return true }
        }
        return recognizer.isAvailable
    }

    // MARK: - 核心识别 + 超时（合并，避免跨 task 传递非 Sendable 对象）

    /// 识别主流程 + 90 秒超时保护。
    ///
    /// recognizer / request 均为非 Sendable，不能传入 @Sendable 闭包。
    /// 解决方案：
    ///   1. TaskHolder（@unchecked Sendable）持有可变引用，跨闭包共享而不违反 Sendable 规则。
    ///   2. withTaskCancellationHandler 包裹 withCheckedThrowingContinuation：
    ///      外层 Swift Task 被取消时，onCancel 立即中止底层 SFSpeechRecognitionTask
    ///      和超时定时器，避免识别持续运行 90 秒直到超时。
    private func doRecognizeWithTimeout(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest,
        recordingId: UUID,
        locale: Locale,
        timeoutSeconds: Double
    ) async throws -> Transcript {
        // 局部 class 持有可变状态，规避 @Sendable 闭包无法捕获 var 的限制
        final class TaskHolder: @unchecked Sendable {
            var recognitionTask: SFSpeechRecognitionTask?
            var timeoutItem: DispatchWorkItem?
        }
        let holder = TaskHolder()
        let guardian = ResumptionGuard()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // 超时定时器
                let timeoutItem = DispatchWorkItem {
                    guardian.tryRun {
                        continuation.resume(
                            throwing: TranscriptionError.engineFailed(
                                NSError(
                                    domain: "VoiceFlow",
                                    code: -2,
                                    userInfo: [NSLocalizedDescriptionKey: "识别超时，请检查网络或缩短录音时长"]
                                )
                            )
                        )
                    }
                }
                holder.timeoutItem = timeoutItem
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + timeoutSeconds,
                    execute: timeoutItem
                )

                // 识别任务（保存返回值，供 onCancel 取消）
                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        timeoutItem.cancel()
                        guardian.tryRun {
                            continuation.resume(throwing: TranscriptionError.engineFailed(error))
                        }
                        return
                    }
                    guard let result, result.isFinal else { return }

                    timeoutItem.cancel()

                    let transcription = result.bestTranscription
                    let segments = transcription.segments.map { seg -> TranscriptSegment in
                        TranscriptSegment(
                            text: seg.substring,
                            start: seg.timestamp,
                            end: seg.timestamp + seg.duration,
                            confidence: Double(seg.confidence)
                        )
                    }
                    // 空 segments 视为可重试的失败，而不是「成功但空」。
                    // 让上层 UI 能给出明确文案 + 重试按钮，避免用户分不清
                    // 「真没说话」「环境太吵」「locale 不匹配」「文件损坏」。
                    if segments.isEmpty {
                        guardian.tryRun {
                            continuation.resume(throwing: TranscriptionError.noSpeechDetected)
                        }
                        return
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
                holder.recognitionTask = task
            }
        } onCancel: {
            // 外层 Swift Task 取消时立即中止底层识别，不等待 90 秒超时。
            // SFSpeechRecognitionTask.cancel() 同步等待 mediaserverd XPC 应答，
            // 在主线程上调用会卡住 UI（删除录音时尤其明显），所以丢到后台 queue。
            // 通过 holder（@unchecked Sendable）跨闭包传递非 Sendable 的 SFSpeechRecognitionTask。
            holder.timeoutItem?.cancel()
            DispatchQueue.global(qos: .userInitiated).async {
                holder.recognitionTask?.cancel()
            }
        }
    }

    // MARK: - 授权

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
