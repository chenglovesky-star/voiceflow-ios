import Testing
import Foundation
@testable import VoiceFlow

@Suite("ExportService text formats")
@MainActor
struct ExportServiceTextTests {
    let svc = ExportService()

    @Test("textTranscript joins segments with single space")
    func textTranscript() {
        let segs = [
            TranscriptSegment(text: "hi", start: 0, end: 0.5),
            TranscriptSegment(text: "world", start: 0.6, end: 1.0)
        ]
        #expect(svc.textTranscript(segments: segs) == "hi world")
    }

    @Test("srtTime formats hours/minutes/seconds/milliseconds")
    func srtTime() {
        #expect(svc.srtTime(0) == "00:00:00,000")
        #expect(svc.srtTime(1.5) == "00:00:01,500")
        #expect(svc.srtTime(3661.123) == "01:01:01,123")
    }

    @Test("srtTranscript produces numbered blocks separated by blank lines")
    func srtTranscript() {
        let segs = [
            TranscriptSegment(text: "Hello", start: 0, end: 0.5),
            TranscriptSegment(text: "world", start: 0.6, end: 1.2)
        ]
        let srt = svc.srtTranscript(segments: segs)
        #expect(srt.contains("1\n00:00:00,000 --> 00:00:00,500\nHello"))
        #expect(srt.contains("2\n00:00:00,600 --> 00:00:01,200\nworld"))
    }

    @Test("markdown includes heading and timestamped segments")
    func markdownTranscript() {
        let segs = [TranscriptSegment(text: "hi", start: 0, end: 0.5)]
        let ctx = ExportContext(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/x.m4a"),
            displayName: "Talk",
            duration: 60,
            createdAt: Date(),
            segments: segs
        )
        let md = svc.markdownTranscript(ctx: ctx, segments: segs)
        #expect(md.contains("# Talk"))
        #expect(md.contains("Duration:"))
        #expect(md.contains("- `00:00` hi"))
    }

    @Test("ExportFormat exposes filename extension and isAudio flag")
    func formatTraits() {
        #expect(ExportFormat.m4a.fileExtension == "m4a")
        #expect(ExportFormat.mp3.fileExtension == "mp3")
        #expect(ExportFormat.txt.fileExtension == "txt")
        #expect(ExportFormat.srt.fileExtension == "srt")
        #expect(ExportFormat.markdown.fileExtension == "md")
        #expect(ExportFormat.m4a.isAudio == true)
        #expect(ExportFormat.txt.isAudio == false)
    }
}
