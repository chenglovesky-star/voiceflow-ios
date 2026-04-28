import SwiftUI
import SwiftData

@main
struct VoiceFlowApp: App {
    let container: ModelContainer = {
        let schema = Schema([RecordingEntity.self, TranscriptEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
