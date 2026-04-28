import Testing
import Foundation
import SwiftData
@testable import VoiceFlow

@Suite("RecordingEntity")
@MainActor
struct RecordingEntityTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([RecordingEntity.self, TranscriptEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test("insert and fetch RecordingEntity")
    func insertAndFetch() throws {
        let ctx = try makeContext()
        let e = RecordingEntity(
            fileName: "abc.m4a",
            duration: 12,
            displayName: "Test"
        )
        ctx.insert(e)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<RecordingEntity>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.fileName == "abc.m4a")
        #expect(fetched.first?.duration == 12)
    }

    @Test("fileURL points into recordings dir under Documents")
    func fileURLPathing() throws {
        let e = RecordingEntity(
            fileName: "x.m4a",
            duration: 1,
            displayName: "X"
        )
        let url = e.fileURL
        #expect(url.lastPathComponent == "x.m4a")
        #expect(url.path.contains("/\(RecordingService.recordingsDirectoryName)/"))
    }

    @Test("from(_:) maps Recording to entity")
    func fromRecording() {
        let recording = Recording(
            url: URL(fileURLWithPath: "/tmp/rec/abc.m4a"),
            duration: 7,
            displayName: "Hello"
        )
        let e = RecordingEntity.from(recording)
        #expect(e.id == recording.id)
        #expect(e.fileName == "abc.m4a")
        #expect(e.duration == 7)
        #expect(e.displayName == "Hello")
    }
}

@Suite("TranscriptEntity")
@MainActor
struct TranscriptEntityTests {

    @Test("segments roundtrip through Data")
    func segmentsRoundtrip() {
        let segs = [
            TranscriptSegment(text: "hi", start: 0, end: 0.5),
            TranscriptSegment(text: "there", start: 0.6, end: 1.2, confidence: 0.91)
        ]
        let entity = TranscriptEntity(locale: "en-US", segments: segs)
        let decoded = entity.segments
        #expect(decoded.count == 2)
        #expect(decoded[0].text == "hi")
        #expect(decoded[1].confidence == 0.91)
    }

    @Test("fullText joins segments")
    func fullText() {
        let segs = [
            TranscriptSegment(text: "Hello", start: 0, end: 0.5),
            TranscriptSegment(text: "world", start: 0.6, end: 1.0)
        ]
        let entity = TranscriptEntity(locale: "en-US", segments: segs)
        #expect(entity.fullText == "Hello world")
    }

    @Test("from(_:) maps Transcript to entity")
    func fromTranscript() {
        let recId = UUID()
        let transcript = Transcript(
            recordingId: recId,
            segments: [TranscriptSegment(text: "a", start: 0, end: 1)],
            locale: "en-US"
        )
        let e = TranscriptEntity.from(transcript)
        #expect(e.id == transcript.id)
        #expect(e.locale == "en-US")
        #expect(e.segments.count == 1)
    }
}
