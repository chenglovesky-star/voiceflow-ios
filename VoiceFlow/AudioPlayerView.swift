import SwiftUI
import AVFoundation
import Combine

@MainActor
final class AudioPlayerController: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var ticker: Timer?

    func load(url: URL) {
        stop()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            p.delegate = self
            duration = p.duration
            player = p
        } catch {
            duration = 0
            player = nil
        }
    }

    func play() {
        guard let player else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // best effort; playback may still work
        }
        player.play()
        isPlaying = true
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let p = self.player else { return }
                self.currentTime = p.currentTime
                if !p.isPlaying {
                    self.isPlaying = false
                    self.ticker?.invalidate()
                }
            }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        ticker?.invalidate()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = max(0, min(duration, time))
        currentTime = player.currentTime
    }

    func stop() {
        player?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        player = nil
        ticker?.invalidate()
        ticker = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }
}

extension AudioPlayerController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            self?.ticker?.invalidate()
            self?.currentTime = 0
        }
    }
}

struct AudioPlayerView: View {
    let url: URL
    var onSeekRequest: ((TimeInterval) -> Void)?
    @StateObject private var controller = AudioPlayerController()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(format(controller.currentTime))
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { controller.currentTime },
                        set: { controller.seek(to: $0) }
                    ),
                    in: 0...max(controller.duration, 0.1)
                )
                Text(format(controller.duration))
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
            }
            Button(action: toggle) {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
        }
        .padding()
        .onAppear { controller.load(url: url) }
        .onDisappear { controller.stop() }
    }

    private func toggle() {
        if controller.isPlaying { controller.pause() } else { controller.play() }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
