import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var service = RecordingService()
    @ObservedObject private var settings = AppSettings.shared
    @State private var transcribingIds: Set<UUID> = []
    @State private var transcriptionTasks: [UUID: Task<Void, Never>] = [:]
    @State private var startError: String?
    @State private var deleteError: String?
    @State private var transcriptionErrors: [UUID: String] = [:]
    /// 控制录前环境探测页的显示。点 mic → 进入探测 → 探测完成或用户确认后切到正式录音
    @State private var isProbing: Bool = false

    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordingEntity.createdAt, ascending: false)],
        animation: .default
    )
    private var entities: FetchedResults<RecordingEntity>

    private let transcriptionService: any TranscriptionService = TranscriptionServiceFactory.make(
        locale: AppSettings.shared.transcriptionLocale
    )

    var body: some View {
        NavigationStack {
            Group {
                if service.isRecording {
                    RecordingView(service: service, onStop: handleStop)
                } else {
                    home
                }
            }
            .navigationTitle("VoiceFlow")
            .toolbar {
                if !service.isRecording {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView(settings: settings)
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
            // Value-based destination: 不依赖 NavigationLink 节点是否存在于视图树，
            // 避免 @FetchRequest 更新移除 NavigationLink 时触发自动 pop，导致双重 dismiss。
            .navigationDestination(for: UUID.self) { id in
                // 删除路径上 entity 可能已被 deleted + save → @NSManaged 属性访问会 trap。
                // 用 isDeleted/isFault/managedObjectContext 三重 guard 跳过失效引用。
                if let entity = entities.first(where: { entity in
                    guard !entity.isDeleted,
                          !entity.isFault,
                          entity.managedObjectContext != nil else { return false }
                    return entity.id == id
                }) {
                    RecordingDetailView(
                        entity: entity,
                        isTranscribing: transcribingIds.contains(id),
                        transcriptionError: transcriptionErrors[id],
                        onDeleteRequested: { cancelTranscription(for: id) },
                        onRetryTranscription: { retryTranscription(for: id) }
                    )
                }
            }
            .alert("Cannot start", isPresented: errorBinding) {
                Button("OK") { startError = nil }
            } message: {
                Text(startError ?? "")
            }
            .alert("Recording interrupted", isPresented: interruptedErrorBinding) {
                Button("OK") { service.interruptedError = nil }
            } message: {
                Text(service.interruptedError ?? "")
            }
            .alert("Delete failed", isPresented: deleteErrorBinding) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
            .fullScreenCover(isPresented: $isProbing) {
                EnvironmentProbeView(
                    service: service,
                    onCancel: { isProbing = false },
                    onProceed: { probe in
                        isProbing = false
                        Task { await start(with: probe) }
                    }
                )
            }
        }
    }

    private var home: some View {
        VStack(spacing: 0) {
            recordingsList
            startButton
                .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var recordingsList: some View {
        if entities.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No recordings")
                    .font(.headline)
                Text("Tap the mic to start your first recording.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                // 用 \.objectID 替代默认的 Identifiable.id 做 List diffing。
                // NSManagedObjectID 不依赖 fault 状态，删除 + save 后访问也安全；
                // 默认基于 @NSManaged var id 的身份会在 entity turn into fault 后触发
                // _unconditionallyBridgeFromObjectiveC(nil) → trap（即所谓"删除卡死"）。
                ForEach(entities, id: \.objectID) { entity in
                    NavigationLink(value: entity.id) {
                        row(for: entity)
                    }
                }
                .onDelete(perform: deleteEntities)
            }
            .listStyle(.plain)
        }
    }

    private func row(for entity: RecordingEntity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entity.displayName)
                .font(.body)
            HStack(spacing: 8) {
                Text(formatDuration(entity.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if transcribingIds.contains(entity.id) {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.7)
                        Text("Transcribing…").font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            if let t = entity.transcript, !t.fullText.isEmpty {
                Text(t.fullText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var startButton: some View {
        Button {
            // 先进入环境探测页，由探测结果决定是否进入正式录音
            isProbing = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 88, height: 88)
                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel("Start recording")
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { startError != nil },
            set: { if !$0 { startError = nil } }
        )
    }

    // 修复 5：interruptedError 的 Binding
    private var interruptedErrorBinding: Binding<Bool> {
        Binding(
            get: { service.interruptedError != nil },
            set: { if !$0 { service.interruptedError = nil } }
        )
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )
    }

    private func start(with probe: EnvironmentProbe) async {
        do {
            try await service.start(externalBaseline: probe.avgDB)
        } catch {
            startError = error.localizedDescription
        }
    }

    private func handleStop(_ session: RecordingSession) {
        // 阶段 1：批量插入所有实体（不在循环内 save）
        for segment in session.segments {
            let _ = RecordingEntity.from(segment, context: context)
        }

        // 阶段 2：一次性原子保存，失败时不启动转录
        do {
            try context.save()
        } catch {
            startError = error.localizedDescription
            return
        }

        // 阶段 3：所有实体保存成功后，批量启动转录 Task
        for segment in session.segments {
            startTranscription(for: segment.id, audioURL: segment.url)
        }
    }

    /// 启动单条录音的转录任务。新录音和"重试转录"共用此入口。
    private func startTranscription(for recordingId: UUID, audioURL: URL) {
        // 重复触发时取消旧 task，避免两个 Task 同时跑
        transcriptionTasks[recordingId]?.cancel()

        let svc = transcriptionService
        let ctx = context
        let locale = settings.transcriptionLocale

        transcriptionErrors.removeValue(forKey: recordingId)
        transcribingIds.insert(recordingId)

        let task = Task { @MainActor in
            do {
                let transcript = try await svc.transcribe(
                    audioURL: audioURL,
                    recordingId: recordingId,
                    locale: locale
                )
                if let target = entities.first(where: { entity in
                    guard !entity.isDeleted,
                          !entity.isFault,
                          entity.managedObjectContext != nil else { return false }
                    return entity.id == recordingId
                }) {
                    // 重试场景下可能已存在旧 transcript，先删再建
                    if let existing = target.transcript {
                        ctx.delete(existing)
                    }
                    let te = TranscriptEntity.from(transcript, context: ctx)
                    target.transcript = te
                    te.recording = target
                    do {
                        try ctx.save()
                    } catch {
                        startError = error.localizedDescription
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    transcriptionErrors[recordingId] = error.localizedDescription
                }
            }
            transcribingIds.remove(recordingId)
            transcriptionTasks.removeValue(forKey: recordingId)
        }
        transcriptionTasks[recordingId] = task
    }

    /// 详情页"重新转录"按钮的入口
    private func retryTranscription(for entityId: UUID) {
        guard let entity = entities.first(where: { entity in
            guard !entity.isDeleted,
                  !entity.isFault,
                  entity.managedObjectContext != nil else { return false }
            return entity.id == entityId
        }) else { return }
        startTranscription(for: entityId, audioURL: entity.fileURL)
    }

    private func deleteEntities(at offsets: IndexSet) {
        // 当前帧仅做轻量主线程操作：取消转录 Task、Core Data delete。
        // 文件删除与 context.save() 推迟到下一帧，避免主线程上同步 IO + WAL 落盘卡顿。
        var pendingFiles: [(URL, UUID?)] = []
        for i in offsets {
            let entity = entities[i]
            cancelTranscription(for: entity.id)
            pendingFiles.append((entity.fileURL, entity.sessionId))
            context.delete(entity)
        }

        let ctx = context
        Task { @MainActor in
            for (fileURL, sessionId) in pendingFiles {
                try? FileManager.default.removeItem(at: fileURL)
                if let sid = sessionId {
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let sessionDir = docs
                        .appendingPathComponent(RecordingService.sessionsDirectoryName, isDirectory: true)
                        .appendingPathComponent(sid.uuidString, isDirectory: true)
                    try? FileManager.default.removeItem(at: sessionDir)
                }
            }
            do {
                try ctx.save()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    func cancelTranscription(for id: UUID) {
        transcriptionTasks[id]?.cancel()
        transcriptionTasks.removeValue(forKey: id)
        transcribingIds.remove(id)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    let container = NSPersistentContainer(name: "VoiceFlow")
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { _, _ in }
    return ContentView()
        .environment(\.managedObjectContext, container.viewContext)
}
