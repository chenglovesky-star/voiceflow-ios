import Foundation

struct TranscriptSegment: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let start: TimeInterval
    let end: TimeInterval
    let confidence: Double?

    init(
        id: UUID = UUID(),
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
    }
}

struct Transcript: Identifiable, Hashable, Sendable {
    let id: UUID
    let recordingId: UUID
    let segments: [TranscriptSegment]
    let locale: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        recordingId: UUID,
        segments: [TranscriptSegment],
        locale: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recordingId = recordingId
        self.segments = segments
        self.locale = locale
        self.createdAt = createdAt
    }

    var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }

    var duration: TimeInterval {
        segments.last?.end ?? 0
    }

    static func == (lhs: Transcript, rhs: Transcript) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
