import SwiftUI

struct ContentView: View {
    @State private var service = RecordingService()
    @State private var recordings: [Recording] = []
    @State private var startError: String?

    var body: some View {
        NavigationStack {
            Group {
                if service.isRecording {
                    RecordingView(service: service) { recording in
                        recordings.insert(recording, at: 0)
                    }
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.displayName)
                        .font(.body)
                    Text(formatDuration(recording.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
        }
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
