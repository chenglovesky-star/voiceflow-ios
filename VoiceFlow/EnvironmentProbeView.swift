import SwiftUI

/// 录前环境探测 UI：先 1.5s 采样麦克风电平，再展示结果。
/// - quiet/acceptable：1.5s 倒计时后自动开始录音；用户可点"立即开始"打断
/// - noisy/clipping：建议重新检测，但仍允许"仍要录音"
/// - 结果停留 15s 未操作自动重测，避免拿到陈旧数据
struct EnvironmentProbeView: View {
    @ObservedObject var service: RecordingService
    var onCancel: () -> Void
    var onProceed: (EnvironmentProbe) -> Void

    @State private var probe: EnvironmentProbe?
    @State private var error: String?
    @State private var probeTask: Task<Void, Never>?
    @State private var autoProceedDeadline: Date?
    @State private var staleDeadline: Date?
    @State private var now = Date()
    @State private var pulseScale: CGFloat = 1.0

    private static let autoProceedSeconds: TimeInterval = 1.5
    private static let staleAfterSeconds: TimeInterval = 15

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            content
            Spacer()
            Button("取消", action: cancelAndClose)
                .buttonStyle(.bordered)
                .padding(.bottom, 32)
        }
        .padding()
        .onAppear { startProbe() }
        .onDisappear {
            probeTask?.cancel()
        }
        .onReceive(tick) { now in
            self.now = now
            // 倒计时到点 → 自动 proceed
            if let deadline = autoProceedDeadline,
               now >= deadline,
               let probe {
                autoProceedDeadline = nil
                onProceed(probe)
            }
            // 防鲜：结果停留过久 → 重测
            if let deadline = staleDeadline, now >= deadline {
                staleDeadline = nil
                startProbe()
            }
        }
        .alert("环境检测失败", isPresented: errorBinding) {
            Button("OK") { cancelAndClose() }
        } message: {
            Text(error ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let probe {
            resultSection(probe)
        } else {
            probingSection
        }
    }

    private var probingSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "ear.and.waveform")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        pulseScale = 1.15
                    }
                }
            Text("正在检测环境…")
                .font(.headline)
            Text("请保持安静约 1.5 秒")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            levelBar
                .padding(.top, 8)
                .padding(.horizontal, 60)
        }
    }

    private var levelBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * CGFloat(service.currentLevel))
                    .animation(.linear(duration: 0.1), value: service.currentLevel)
            }
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func resultSection(_ probe: EnvironmentProbe) -> some View {
        VStack(spacing: 18) {
            Image(systemName: probe.systemImage)
                .font(.system(size: 56))
                .foregroundColor(probe.isFavorable ? .green : .orange)
            Text(probe.headline)
                .font(.title3.bold())
            Text(probe.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 24) {
                metric(label: "avg", value: String(format: "%.0f dB", probe.avgDB))
                metric(label: "peak", value: String(format: "%.0f dB", probe.peakDB))
            }
            .padding(.top, 4)

            Spacer().frame(height: 12)

            if probe.isFavorable {
                Button {
                    autoProceedDeadline = nil
                    staleDeadline = nil
                    onProceed(probe)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                        Text(autoProceedLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    startProbe()
                } label: {
                    Label("重新检测", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    autoProceedDeadline = nil
                    staleDeadline = nil
                    onProceed(probe)
                } label: {
                    Text("仍要录音")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 24)
    }

    private var autoProceedLabel: String {
        guard let deadline = autoProceedDeadline else { return "开始录音" }
        let remaining = max(0, deadline.timeIntervalSince(now))
        return String(format: "开始录音（%.1fs）", remaining)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.callout.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func startProbe() {
        probeTask?.cancel()
        autoProceedDeadline = nil
        staleDeadline = nil
        error = nil
        probe = nil

        probeTask = Task { @MainActor in
            do {
                let result = try await service.probeEnvironment(duration: 1.5)
                guard !Task.isCancelled else { return }
                probe = result
                if result.isFavorable {
                    autoProceedDeadline = Date().addingTimeInterval(Self.autoProceedSeconds)
                }
                staleDeadline = Date().addingTimeInterval(Self.staleAfterSeconds)
            } catch is CancellationError {
                // ignore
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func cancelAndClose() {
        probeTask?.cancel()
        autoProceedDeadline = nil
        staleDeadline = nil
        error = nil
        onCancel()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )
    }
}
