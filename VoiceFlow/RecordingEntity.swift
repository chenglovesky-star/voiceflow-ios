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
        if let sid = sessionId {
            return docs
                .appendingPathComponent(RecordingService.sessionsDirectoryName, isDirectory: true)
                .appendingPathComponent(sid.uuidString, isDirectory: true)
                .appendingPathComponent(fileName)
        }
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
        entity.sessionId = recording.sessionId
        entity.segmentIndex = Int32(recording.segmentIndex)
        entity.totalSegments = Int32(recording.totalSegments)
        return entity
    }
}

extension RecordingEntity: Identifiable {}
