import Foundation
import CoreData

@objc(RecordingEntity)
final class RecordingEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var fileName: String
    @NSManaged var duration: Double
    @NSManaged var createdAt: Date
    @NSManaged var displayName: String
    @NSManaged var sessionId: UUID?
    @NSManaged var segmentIndex: Int32
    @NSManaged var totalSegments: Int32
    @NSManaged var transcript: TranscriptEntity?

    var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
            .appendingPathComponent(RecordingService.recordingsDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        fileName: String,
        duration: Double,
        createdAt: Date = Date(),
        displayName: String,
        sessionId: UUID? = nil,
        segmentIndex: Int32 = 0,
        totalSegments: Int32 = 1
    ) {
        self.init(context: context)
        self.id = id
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.displayName = displayName
        self.sessionId = sessionId
        self.segmentIndex = segmentIndex
        self.totalSegments = totalSegments
    }

    @discardableResult
    static func from(_ recording: Recording, context: NSManagedObjectContext) -> RecordingEntity {
        let entity = RecordingEntity(context: context)
        entity.id = recording.id
        entity.fileName = recording.url.lastPathComponent
        entity.duration = recording.duration
        entity.createdAt = recording.createdAt
        entity.displayName = recording.displayName
        entity.sessionId = nil
        entity.segmentIndex = 0
        entity.totalSegments = 1
        return entity
    }
}

extension RecordingEntity: Identifiable {}
