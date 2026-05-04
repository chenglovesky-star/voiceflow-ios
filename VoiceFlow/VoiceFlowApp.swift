import SwiftUI
import CoreData

@main
struct VoiceFlowApp: App {
    let persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "VoiceFlow")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load CoreData store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
    }
}
