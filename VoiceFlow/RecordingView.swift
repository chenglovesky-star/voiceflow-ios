import SwiftUI

struct RecordingView: View {
    @ObservedObject var service: RecordingService
    var onStop: (RecordingSession) -> Void
    @State private var stopError: String?
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(formatTime(service.elapsed))
                .font(.system(size: 56, weight: .light, design: .monospaced))
                .contentTransition(.numericText())
                .accessibilityLabel("Elapsed \(Int(service.elapsed)) seconds")

            WaveformView(levels: service.recentLevels, style: settings.waveformStyle)
                .frame(height: 100)
                .padding(.horizontal, 24)

            if let warning = service.noiseWarning {
                noiseBanner(warning)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

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
        .animation(.easeInOut(duration: 0.2), value: service.noiseWarning)
        .alert("Error stopping", isPresented: errorBinding) {
            Button("OK") { stopError = nil }
        } message: {
            Text(stopError ?? "")
        }
        .alert("录音中断", isPresented: interruptedErrorBinding) {
            Button("确定") { service.interruptedError = nil }
        } message: {
            Text(service.interruptedError ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { stopError != nil },
            set: { if !$0 { stopError = nil } }
        )
    }

    private var interruptedErrorBinding: Binding<Bool> {
        Binding(
            get: { service.interruptedError != nil },
            set: { if !$0 { service.interruptedError = nil } }
        )
    }

    private func stop() {
        Task { @MainActor in
            do {
                let recording = try await service.stop()
                onStop(recording)
            } catch {
                stopError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func noiseBanner(_ warning: NoiseWarning) -> some View {
        HStack(spacing: 10) {
            Image(systemName: warning.systemImage)
                .font(.body)
            Text(warning.message)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
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
