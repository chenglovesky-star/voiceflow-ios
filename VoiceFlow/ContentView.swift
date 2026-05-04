import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var service = RecordingService()
    @ObservedObject private var settings = AppSettings.shared
    @State private var transcribingIds: Set<UUID> = []
    @State private var startError: String?

    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordingEntity.createdAt, ascending: false)],
        animation: .default
    )
    private var entities: FetchedResults<RecordingEntity>

    private let transcriptionService: any TranscriptionService = TranscriptionServiceFactory.make()

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
                            isTranscribing: transcribingIds.contains(entity.id)
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

    private func start() async {
        do {
            try await service.start()
        } catch {
            startError = error.localizedDescription
        }
    }

    private func handleStop(_ recording: Recording) {
        let entity = RecordingEntity.from(recording, context: context)
        try? context.save()

        transcribingIds.insert(recording.id)
        let svc = transcriptionService
        let ctx = context
        let recordingId = recording.id
        let locale = settings.transcriptionLocale

        Task {
            do {
                let transcript = try await svc.transcribe(
                    audioURL: recording.url,
                    recordingId: recordingId,
                    locale: locale
                )
                if let target = entities.first(where: { $0.id == recordingId }) {
                    let te = TranscriptEntity.from(transcript, context: ctx)
                    target.transcript = te
                    try? ctx.save()
                }
            } catch {
                // Phase 9 will surface in detail view; row falls back to no preview
            }
            transcribingIds.remove(recordingId)
        }
    }

    private func deleteEntities(at offsets: IndexSet) {
        for i in offsets {
            let entity = entities[i]
            try? FileManager.default.removeItem(at: entity.fileURL)
            context.delete(entity)
        }
        try? context.save()
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
