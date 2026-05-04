import Foundation

struct Recording: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let duration: TimeInterval
    let createdAt: Date
    var displayName: String

    /// Session ID linking multiple segments together for long recordings
    let sessionId: UUID

    /// Segment index within a session (0 = first segment)
    let segmentIndex: Int

    /// Total number of segments in this session (1 for single-segment recordings)
    let totalSegments: Int

    init(
        id: UUID = UUID(),
        url: URL,
        duration: TimeInterval,
        createdAt: Date = Date(),
        displayName: String? = nil,
        sessionId: UUID? = nil,
        segmentIndex: Int = 0,
        totalSegments: Int = 1
    ) {
        self.id = id
        self.url = url
        self.duration = duration
        self.createdAt = createdAt
        self.displayName = displayName ?? Self.defaultName(for: createdAt)
        self.sessionId = sessionId ?? id
        self.segmentIndex = segmentIndex
        self.totalSegments = totalSegments
    }

    /// True if this recording is part of a multi-segment session
    var isPartOfSession: Bool {
        totalSegments > 1
    }

    /// Formatted segment label (e.g., "Part 2 of 3")
    var segmentLabel: String? {
        guard totalSegments > 1 else { return nil }
        return "Part \(segmentIndex + 1) of \(totalSegments)"
    }

    static func defaultName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return "Recording \(f.string(from: date))"
    }

    static func == (lhs: Recording, rhs: Recording) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A complete recording session consisting of multiple segments
struct RecordingSession: Identifiable, Hashable, Sendable {
    let id: UUID
    let sessionId: UUID
    var segments: [Recording]

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    var startDate: Date {
        segments.first?.createdAt ?? Date()
    }

    var endDate: Date {
        segments.last.map { $0.createdAt.addingTimeInterval($0.duration) } ?? Date()
    }

    var displayName: String {
        segments.first?.displayName ?? "Recording"
    }

    init(sessionId: UUID, segments: [Recording]) {
        self.id = sessionId
        self.sessionId = sessionId
        self.segments = segments.sorted { $0.segmentIndex < $1.segmentIndex }
    }
}
