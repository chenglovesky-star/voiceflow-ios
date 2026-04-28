import SwiftUI

struct ContentView: View {
    @State private var service = RecordingService()
    @State private var recordings: [Recording] = []
    @State private var transcripts: [UUID: Transcript] = [:]
    @State private var transcribingIds: Set<UUID> = []
    @State private var startError: String?

    private let transcriptionService: any TranscriptionService = OnDeviceTranscriptionService()

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
        if recordings.isEmpty {
            ContentUnavailableView(
                "No recordings",
                systemImage: "waveform",
                description: Text("Tap the mic to start your first recording.")
            )
            .frame(maxHeight: .infinity)
        } else {
            List(recordings) { recording in
                row(for: recording)
            }
            .listStyle(.plain)
        }
    }

    private func row(for recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.displayName)
                .font(.body)
            HStack(spacing: 8) {
                Text(formatDuration(recording.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if transcribingIds.contains(recording.id) {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.7)
                        Text("Transcribing…").font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            if let t = transcripts[recording.id], !t.fullText.isEmpty {
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
        recordings.insert(recording, at: 0)
        transcribingIds.insert(recording.id)
        let svc = transcriptionService
        Task {
            do {
                let transcript = try await svc.transcribe(
                    audioURL: recording.url,
                    recordingId: recording.id,
                    locale: .current
                )
                transcripts[recording.id] = transcript
            } catch {
                // Phase 4 will surface errors in detail view; row falls back to no preview
            }
            transcribingIds.remove(recording.id)
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
    ContentView()
}
