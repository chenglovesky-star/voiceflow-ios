import Testing
import Foundation
import CoreData
@testable import VoiceFlow

@Suite("RecordingEntity")
@MainActor
struct RecordingEntityTests {

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "VoiceFlow")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Failed to load store: \(error)") }
        }
        return container.viewContext
    }

    @Test("insert and fetch RecordingEntity")
    func insertAndFetch() throws {
        let ctx = makeContext()
        let e = RecordingEntity(
            context: ctx,
            fileName: "abc.m4a",
            duration: 12,
            displayName: "Test"
        )
        try ctx.save()

        let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
        let fetched = try ctx.fetch(request)
        #expect(fetched.count == 1)
        #expect(fetched.first?.fileName == "abc.m4a")
        #expect(fetched.first?.duration == 12)
    }

    @Test("fileURL points into recordings dir under Documents")
    func fileURLPathing() {
        let ctx = makeContext()
        let e = RecordingEntity(
            context: ctx,
            fileName: "x.m4a",
            duration: 1,
            displayName: "X"
        )
        let url = e.fileURL
        #expect(url.lastPathComponent == "x.m4a")
        #expect(url.path.contains("/\(RecordingService.recordingsDirectoryName)/"))
    }

    @Test("from(_:context:) maps Recording to entity")
    func fromRecording() {
        let ctx = makeContext()
        let recording = Recording(
            url: URL(fileURLWithPath: "/tmp/rec/abc.m4a"),
            duration: 7,
            displayName: "Hello"
        )
        let e = RecordingEntity.from(recording, context: ctx)
        #expect(e.id == recording.id)
        #expect(e.fileName == "abc.m4a")
        #expect(e.duration == 7)
        #expect(e.displayName == "Hello")
    }
}

@Suite("TranscriptEntity")
@MainActor
struct TranscriptEntityTests {

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "VoiceFlow")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Failed to load store: \(error)") }
        }
        return container.viewContext
    }

    @Test("segments roundtrip through Data")
    func segmentsRoundtrip() {
        let ctx = makeContext()
        let segs = [
            TranscriptSegment(text: "hi", start: 0, end: 0.5),
            TranscriptSegment(text: "there", start: 0.6, end: 1.2, confidence: 0.91)
        ]
        let entity = TranscriptEntity(context: ctx, locale: "en-US", segments: segs)
        let decoded = entity.segments
        #expect(decoded.count == 2)
        #expect(decoded[0].text == "hi")
        #expect(decoded[1].confidence == 0.91)
    }

    @Test("fullText joins segments")
    func fullText() {
        let ctx = makeContext()
        let segs = [
            TranscriptSegment(text: "Hello", start: 0, end: 0.5),
            TranscriptSegment(text: "world", start: 0.6, end: 1.0)
        ]
        let entity = TranscriptEntity(context: ctx, locale: "en-US", segments: segs)
        #expect(entity.fullText == "Hello world")
    }

    @Test("from(_:context:) maps Transcript to entity")
    func fromTranscript() {
        let ctx = makeContext()
        let recId = UUID()
        let transcript = Transcript(
            recordingId: recId,
            segments: [TranscriptSegment(text: "a", start: 0, end: 1)],
            locale: "en-US"
        )
        let e = TranscriptEntity.from(transcript, context: ctx)
        #expect(e.id == transcript.id)
        #expect(e.locale == "en-US")
        #expect(e.segments.count == 1)
    }
}
