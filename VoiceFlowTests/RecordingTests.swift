import Testing
import Foundation
@testable import VoiceFlow

@Suite("Recording value type")
struct RecordingTests {

    @Test("default display name uses createdAt date")
    func defaultDisplayName() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let r = Recording(
            url: URL(fileURLWithPath: "/tmp/x.m4a"),
            duration: 60,
            createdAt: date
        )
        #expect(r.displayName.hasPrefix("Recording "))
        #expect(r.duration == 60)
        #expect(r.createdAt == date)
    }

    @Test("custom display name is preserved")
    func customDisplayName() {
        let r = Recording(
            url: URL(fileURLWithPath: "/tmp/x.m4a"),
            duration: 60,
            displayName: "Meeting with Alice"
        )
        #expect(r.displayName == "Meeting with Alice")
    }

    @Test("identity by id")
    func identityById() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/x.m4a")
        let r1 = Recording(id: id, url: url, duration: 1)
        let r2 = Recording(id: id, url: url, duration: 1)
        #expect(r1 == r2)
        #expect(r1.hashValue == r2.hashValue)
    }

    @Test("different ids are not equal")
    func differentIdsNotEqual() {
        let url = URL(fileURLWithPath: "/tmp/x.m4a")
        let r1 = Recording(url: url, duration: 1)
        let r2 = Recording(url: url, duration: 1)
        #expect(r1 != r2)
    }
}

@Suite("RecordingService URL helper")
@MainActor
struct RecordingServiceURLTests {

    @Test("makeRecordingURL produces .m4a in recordings dir")
    func makeRecordingURLPath() {
        let url = RecordingService.makeRecordingURL(sessionId: nil, segment: 0)
        #expect(url.pathExtension == "m4a")
        #expect(url.path.contains("/\(RecordingService.recordingsDirectoryName)/"))
    }

    @Test("two URLs are unique")
    func makeRecordingURLUnique() {
        let a = RecordingService.makeRecordingURL(sessionId: nil, segment: 0)
        let b = RecordingService.makeRecordingURL(sessionId: nil, segment: 0)
        #expect(a != b)
    }
}
