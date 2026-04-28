import Testing
import Foundation
@testable import VoiceFlow

@Suite("Transcript model")
struct TranscriptTests {

    @Test("fullText concatenates segments with spaces")
    func fullText() {
        let segs = [
            TranscriptSegment(text: "Hello", start: 0, end: 0.5),
            TranscriptSegment(text: "world", start: 0.6, end: 1.0)
        ]
        let t = Transcript(recordingId: UUID(), segments: segs, locale: "en-US")
        #expect(t.fullText == "Hello world")
    }

    @Test("duration uses last segment end")
    func duration() {
        let segs = [
            TranscriptSegment(text: "a", start: 0, end: 1.5),
            TranscriptSegment(text: "b", start: 2, end: 3.7)
        ]
        let t = Transcript(recordingId: UUID(), segments: segs, locale: "en-US")
        #expect(t.duration == 3.7)
    }

    @Test("empty segments yield empty text and zero duration")
    func empty() {
        let t = Transcript(recordingId: UUID(), segments: [], locale: "en-US")
        #expect(t.fullText.isEmpty)
        #expect(t.duration == 0)
    }

    @Test("identity by id")
    func identity() {
        let id = UUID()
        let recId = UUID()
        let t1 = Transcript(id: id, recordingId: recId, segments: [], locale: "en-US")
        let t2 = Transcript(id: id, recordingId: recId, segments: [], locale: "en-US")
        #expect(t1 == t2)
        #expect(t1.hashValue == t2.hashValue)
    }

    @Test("segment with confidence preserved")
    func segmentConfidence() {
        let s = TranscriptSegment(text: "hi", start: 0, end: 1, confidence: 0.92)
        #expect(s.confidence == 0.92)
    }
}

@Suite("ResumptionGuard")
struct ResumptionGuardTests {

    @Test("first call runs, subsequent calls skipped")
    func firstWins() {
        let guardian = ResumptionGuard()
        var count = 0
        guardian.tryRun { count += 1 }
        guardian.tryRun { count += 1 }
        guardian.tryRun { count += 1 }
        #expect(count == 1)
    }
}
