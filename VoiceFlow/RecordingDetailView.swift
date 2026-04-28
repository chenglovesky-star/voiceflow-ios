import SwiftUI
import SwiftData

struct RecordingDetailView: View {
    @Bindable var entity: RecordingEntity
    var isTranscribing: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var exportError: String?
    @State private var isExporting = false

    private let exportService = ExportService()

    var body: some View {
        VStack(spacing: 0) {
            AudioPlayerView(url: entity.fileURL)
                .frame(maxHeight: 180)

            Divider()

            transcriptSection
        }
        .navigationTitle(entity.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                menu
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(items: shareItems)
        }
        .alert("Export failed", isPresented: errorBinding) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    @ViewBuilder
    private var menu: some View {
        Menu {
            Section("Export") {
                ForEach(ExportFormat.allCases, id: \.self) { fmt in
                    Button {
                        Task { await export(format: fmt) }
                    } label: {
                        Label(fmt.rawValue, systemImage: fmt.systemImage)
                    }
                    .disabled(isExporting)
                }
            }
            Divider()
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            if isExporting {
                ProgressView()
            } else {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private var transcriptSection: some View {
        if isTranscribing {
            VStack(spacing: 12) {
                ProgressView()
                Text("Transcribing on-device…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let transcript = entity.transcript, !transcript.segments.isEmpty {
            ScrollView {
                Text(transcript.fullText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        } else if entity.transcript != nil {
            ContentUnavailableView(
                "No speech detected",
                systemImage: "waveform.slash",
                description: Text("The recording did not contain recognizable speech.")
            )
        } else {
            ContentUnavailableView(
                "Transcript pending",
                systemImage: "text.bubble",
                description: Text("Transcription will appear here when complete.")
            )
        }
    }

    private func delete() {
        try? FileManager.default.removeItem(at: entity.fileURL)
        modelContext.delete(entity)
        try? modelContext.save()
    }

    private func export(format: ExportFormat) async {
        guard !isExporting else { return }
        isExporting = true
        let ctx = ExportContext.from(entity)
        do {
            let url = try await exportService.export(ctx, format: format)
            shareItems = [url]
            isShareSheetPresented = true
        } catch {
            exportError = error.localizedDescription
        }
        isExporting = false
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }
}
