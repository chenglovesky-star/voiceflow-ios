import Foundation
import SwiftData

@Model
final class TranscriptEntity {
    @Attribute(.unique) var id: UUID
    var locale: String
    var createdAt: Date
    var segmentsData: Data

    var recording: RecordingEntity?

    init(
        id: UUID = UUID(),
        locale: String,
        createdAt: Date = Date(),
        segments: [TranscriptSegment]
    ) {
        self.id = id
        self.locale = locale
        self.createdAt = createdAt
        self.segmentsData = (try? JSONEncoder().encode(segments)) ?? Data()
    }

    var segments: [TranscriptSegment] {
        get {
            (try? JSONDecoder().decode([TranscriptSegment].self, from: segmentsData)) ?? []
        }
        set {
            segmentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }

    static func from(_ transcript: Transcript) -> TranscriptEntity {
        TranscriptEntity(
            id: transcript.id,
            locale: transcript.locale,
            createdAt: transcript.createdAt,
            segments: transcript.segments
        )
    }
}
