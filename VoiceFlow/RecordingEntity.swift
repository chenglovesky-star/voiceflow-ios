import Foundation
import SwiftData

@Model
final class RecordingEntity {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var duration: TimeInterval
    var createdAt: Date
    var displayName: String

    @Relationship(deleteRule: .cascade, inverse: \TranscriptEntity.recording)
    var transcript: TranscriptEntity?

    init(
        id: UUID = UUID(),
        fileName: String,
        duration: TimeInterval,
        createdAt: Date = Date(),
        displayName: String
    ) {
        self.id = id
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.displayName = displayName
    }

    var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
            .appendingPathComponent(RecordingService.recordingsDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func from(_ recording: Recording) -> RecordingEntity {
        RecordingEntity(
            id: recording.id,
            fileName: recording.url.lastPathComponent,
            duration: recording.duration,
            createdAt: recording.createdAt,
            displayName: recording.displayName
        )
    }
}
