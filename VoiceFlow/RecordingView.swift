import SwiftUI

struct RecordingView: View {
    @ObservedObject var service: RecordingService
    var onStop: (Recording) -> Void
    @State private var stopError: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(formatTime(service.elapsed))
                .font(.system(size: 56, weight: .light, design: .monospaced))
                .contentTransition(.numericText())
                .accessibilityLabel("Elapsed \(Int(service.elapsed)) seconds")

            WaveformView(levels: service.recentLevels)
                .frame(height: 100)
                .padding(.horizontal, 24)

            Spacer()

            Button(action: stop) {
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 4)
                        .frame(width: 88, height: 88)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                }
            }
            .accessibilityLabel("Stop recording")
            .padding(.bottom, 40)
        }
        .alert("Error stopping", isPresented: errorBinding) {
            Button("OK") { stopError = nil }
        } message: {
            Text(stopError ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { stopError != nil },
            set: { if !$0 { stopError = nil } }
        )
    }

    private func stop() {
        do {
            let recording = try service.stop()
            onStop(recording)
        } catch {
            stopError = error.localizedDescription
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
