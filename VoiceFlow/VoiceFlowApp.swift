import SwiftUI
import CoreData
import Speech

@main
struct VoiceFlowApp: App {
    @ObservedObject private var settings = AppSettings.shared

    let persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "VoiceFlow")
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // 尝试删除损坏的存储文件并重建
                if let url = storeDescription.url {
                    try? FileManager.default.removeItem(at: url)
                    try? FileManager.default.removeItem(at: url.deletingLastPathComponent()
                        .appendingPathComponent(url.lastPathComponent + "-shm"))
                    try? FileManager.default.removeItem(at: url.deletingLastPathComponent()
                        .appendingPathComponent(url.lastPathComponent + "-wal"))
                }
                // 重新尝试加载（空库）
                container.loadPersistentStores { _, retryError in
                    if let retryError {
                        fatalError("CoreData unrecoverable: \(retryError)")
                    }
                }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.onboardingComplete {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environment(\.managedObjectContext, persistentContainer.viewContext)
            // 用户在 Settings 选定的 app 显示语言（auto = nil → 跟随系统）
            .environment(\.locale, settings.effectiveLocale ?? Locale.autoupdatingCurrent)
            .task {
                // 启动时静默预热 SFSpeechRecognizer：触发模型激活/下载，
                // 避免用户首次录完点详情时还卡在「unavailable」。仅初始化、不识别。
                let locale = AppSettings.shared.transcriptionLocale
                Task.detached(priority: .background) {
                    _ = SFSpeechRecognizer(locale: locale)
                    _ = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                        SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
                    }
                }
            }
        }
    }
}
