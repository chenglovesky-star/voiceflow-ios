import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            VStack(spacing: 4) {
                Text("VoiceFlow")
                    .font(.largeTitle.bold())
                Text("Record. Transcribe. Send to AI.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Phase 1 scaffold — recording UI ships in Phase 2")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 12)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
