import SwiftUI
import SwiftData

struct RecordingDetailView: View {
    @Bindable var entity: RecordingEntity
    var isTranscribing: Bool

    @Environment(\.modelContext) private var modelContext

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
                Menu {
                    Button(role: .destructive, action: delete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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
}
