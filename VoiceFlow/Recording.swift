import Foundation

struct Recording: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let duration: TimeInterval
    let createdAt: Date
    var displayName: String

    init(
        id: UUID = UUID(),
        url: URL,
        duration: TimeInterval,
        createdAt: Date = Date(),
        displayName: String? = nil
    ) {
        self.id = id
        self.url = url
        self.duration = duration
        self.createdAt = createdAt
        self.displayName = displayName ?? Self.defaultName(for: createdAt)
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
