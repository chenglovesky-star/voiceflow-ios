import Foundation
import AVFoundation

enum ExportFormat: String, CaseIterable, Sendable {
    case m4a = "M4A"
    case aac = "AAC"
    case txt = "TXT"
    case srt = "SRT"
    case markdown = "Markdown"

    var fileExtension: String {
        switch self {
        case .m4a: return "m4a"
        case .aac: return "m4a"   // AAC in M4A container
        case .txt: return "txt"
        case .srt: return "srt"
        case .markdown: return "md"
        }
    }

    var systemImage: String {
        switch self {
        case .m4a: return "waveform"
        case .aac: return "music.note"
        case .txt: return "doc.text"
        case .srt: return "captions.bubble"
        case .markdown: return "doc.richtext"
        }
    }

    var isAudio: Bool { self == .m4a || self == .aac }
}

enum ExportError: LocalizedError {
    case sourceMissing
    case writeFailed(Error)
    case mp3EncodingUnavailable
    case audioExportFailed(String)

    var errorDescription: String? {
        switch self {
        case .sourceMissing:
            return String(localized: "Source file not found.")
        case .writeFailed(let e):
            return String(localized: "Couldn't write export: \(e.localizedDescription)")
        case .mp3EncodingUnavailable:
            return String(localized: "MP3 encoding is not available on this device.")
        case .audioExportFailed(let s):
            return String(localized: "Audio export failed: \(s)")
        }
    }
}

struct ExportContext: Sendable {
    let id: UUID
    let sourceURL: URL
    let displayName: String
    let duration: TimeInterval
    let createdAt: Date
    let segments: [TranscriptSegment]
}

struct ExportService: Sendable {

    func export(_ ctx: ExportContext, format: ExportFormat) async throws -> URL {
        switch format {
        case .m4a:
            return try copyAudio(ctx: ctx, asExt: "m4a")
        case .aac:
            return try await convertToMP3(ctx: ctx)
        case .txt:
            return try writeText(
                ctx: ctx,
                content: textTranscript(segments: ctx.segments),
                ext: "txt"
            )
        case .srt:
            return try writeText(
                ctx: ctx,
                content: srtTranscript(segments: ctx.segments),
                ext: "srt"
            )
        case .markdown:
            return try writeText(
                ctx: ctx,
                content: markdownTranscript(ctx: ctx, segments: ctx.segments),
                ext: "md"
            )
        }
    }

    // MARK: Audio

    private func copyAudio(ctx: ExportContext, asExt ext: String) throws -> URL {
        guard FileManager.default.fileExists(atPath: ctx.sourceURL.path) else {
            throw ExportError.sourceMissing
        }
        let dst = exportTempDir().appendingPathComponent("\(safeName(ctx)).\(ext)")
        try? FileManager.default.removeItem(at: dst)
        do {
            try FileManager.default.copyItem(at: ctx.sourceURL, to: dst)
        } catch {
            throw ExportError.writeFailed(error)
        }
        return dst
    }

    private func convertToMP3(ctx: ExportContext) async throws -> URL {
        // iOS 17+ ships with AAC/Apple Lossless encoders but no built-in MP3.
        // We export via AVAssetExportPresetAppleM4A (AAC in M4A container) which
        // is accepted by Perplexity/Gemini/OpenAI/Whisper API. Avoids LAME licensing.
        // Phase 5.1 (later): real MP3 via AudioToolbox if user demand justifies.
        guard FileManager.default.fileExists(atPath: ctx.sourceURL.path) else {
            throw ExportError.sourceMissing
        }
        let dst = exportTempDir().appendingPathComponent("\(safeName(ctx)).m4a")
        try? FileManager.default.removeItem(at: dst)

        let asset = AVURLAsset(url: ctx.sourceURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ExportError.audioExportFailed("Could not create exporter")
        }
        exporter.outputURL = dst
        exporter.outputFileType = .m4a
        await exporter.export()

        if let err = exporter.error {
            throw ExportError.audioExportFailed(err.localizedDescription)
        }
        guard exporter.status == .completed else {
            throw ExportError.audioExportFailed("Status: \(exporter.status.rawValue)")
        }
        return dst
    }

    // MARK: Text formats

    func textTranscript(segments: [TranscriptSegment]) -> String {
        segments.map(\.text).joined(separator: " ")
    }

    func markdownTranscript(ctx: ExportContext, segments: [TranscriptSegment]) -> String {
        let header = """
        # \(ctx.displayName)

        - Duration: \(formatDuration(ctx.duration))
        - Recorded: \(ISO8601DateFormatter().string(from: ctx.createdAt))

        ---

        """
        let body = segments.map { seg in
            "- `\(formatTime(seg.start))` \(seg.text)"
        }.joined(separator: "\n")
        return header + body + "\n"
    }

    func srtTranscript(segments: [TranscriptSegment]) -> String {
        segments.enumerated().map { (idx, seg) in
            """
            \(idx + 1)
            \(srtTime(seg.start)) --> \(srtTime(seg.end))
            \(seg.text)
            """
        }.joined(separator: "\n\n") + "\n"
    }

    // MARK: Helpers

    private func writeText(ctx: ExportContext, content: String, ext: String) throws -> URL {
        let dst = exportTempDir().appendingPathComponent("\(safeName(ctx)).\(ext)")
        do {
            try content.write(to: dst, atomically: true, encoding: .utf8)
            return dst
        } catch {
            throw ExportError.writeFailed(error)
        }
    }

    private func exportTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func safeName(_ ctx: ExportContext) -> String {
        let base = ctx.displayName.replacingOccurrences(
            of: "[^A-Za-z0-9_\\u4e00-\\u9fff -]",
            with: "_",
            options: .regularExpression
        )
        return base.isEmpty ? ctx.id.uuidString : base
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return String(format: "%dm %ds", m, s)
    }

    func srtTime(_ t: TimeInterval) -> String {
        let total = Int(t * 1000)
        let h = total / 3_600_000
        let m = (total % 3_600_000) / 60_000
        let s = (total % 60_000) / 1_000
        let ms = total % 1_000
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }
}

extension ExportContext {
    @MainActor
    static func from(_ entity: RecordingEntity) -> ExportContext {
        ExportContext(
            id: entity.id,
            sourceURL: entity.fileURL,
            displayName: entity.displayName,
            duration: entity.duration,
            createdAt: entity.createdAt,
            segments: entity.transcript?.segments ?? []
        )
    }
}
