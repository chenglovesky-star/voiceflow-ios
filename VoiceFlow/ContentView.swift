import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var service = RecordingService()
    @ObservedObject private var settings = AppSettings.shared
    @State private var transcribingIds: Set<UUID> = []
    @State private var startError: String?
    @State private var deleteError: String?
    @State private var transcriptionErrors: [UUID: String] = [:]

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
            .alert("Cannot start", isPresented: errorBinding) {
                Button("OK") { startError = nil }
            } message: {
                Text(startError ?? "")
            }
            // 修复 5：观察 RecordingService.interruptedError，系统中断时提示用户
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
                ForEach(entities) { entity in
                    NavigationLink {
                        RecordingDetailView(
                            entity: entity,
                            isTranscribing: transcribingIds.contains(entity.id),
                            transcriptionError: transcriptionErrors[entity.id]
                        )
                    } label: {
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
            Task { await start() }
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

    private func start() async {
        do {
            try await service.start()
        } catch {
            startError = error.localizedDescription
        }
    }

    private func handleStop(_ session: RecordingSession) {
        let svc = transcriptionService
        let ctx = context
        let locale = settings.transcriptionLocale

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
            transcribingIds.insert(segment.id)
            let recordingId = segment.id

            Task { @MainActor in
                do {
                    let transcript = try await svc.transcribe(
                        audioURL: segment.url,
                        recordingId: recordingId,
                        locale: locale
                    )
                    if let target = entities.first(where: { $0.id == recordingId }) {
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
                    transcriptionErrors[recordingId] = error.localizedDescription
                }
                transcribingIds.remove(recordingId)
            }
        }
    }

    private func deleteEntities(at offsets: IndexSet) {
        for i in offsets {
            let entity = entities[i]
            try? FileManager.default.removeItem(at: entity.fileURL)
            // 修复 4：消除 TOCTOU，直接尝试删除 session 目录，目录非空时失败属预期行为
            if let sid = entity.sessionId {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let sessionDir = docs
                    .appendingPathComponent(RecordingService.sessionsDirectoryName, isDirectory: true)
                    .appendingPathComponent(sid.uuidString, isDirectory: true)
                try? FileManager.default.removeItem(at: sessionDir)
            }
            context.delete(entity)
        }
        // 修复 2：CoreData save 错误不再静默丢弃
        do {
            try context.save()
        } catch {
            deleteError = error.localizedDescription
        }
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
