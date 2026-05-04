import Foundation
import CoreData

@objc(TranscriptEntity)
final class TranscriptEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var locale: String
    @NSManaged var createdAt: Date
    @NSManaged var segmentsData: Data
    @NSManaged var recording: RecordingEntity?

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

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        locale: String,
        createdAt: Date = Date(),
        segments: [TranscriptSegment]
    ) {
        self.init(context: context)
        self.id = id
        self.locale = locale
        self.createdAt = createdAt
        self.segmentsData = (try? JSONEncoder().encode(segments)) ?? Data()
    }

    @discardableResult
    static func from(_ transcript: Transcript, context: NSManagedObjectContext) -> TranscriptEntity {
        let entity = TranscriptEntity(context: context)
        entity.id = transcript.id
        entity.locale = transcript.locale
        entity.createdAt = transcript.createdAt
        entity.segmentsData = (try? JSONEncoder().encode(transcript.segments)) ?? Data()
        return entity
    }
}

extension TranscriptEntity: Identifiable {}
