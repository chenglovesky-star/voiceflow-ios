import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var currentPage = 0
    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                privacyPage.tag(1)
                aiSharePage.tag(2)
                getStartedPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            pageIndicator
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundStyle(Color.purple)

            Text("Welcome to VoiceFlow")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                featureRow(icon: "mic.fill", text: "Record your voice anytime")
                featureRow(icon: "text.bubble.fill", text: "Transcribe on your device")
                featureRow(icon: "sparkles", text: "Send to your favorite AI")
            }
            .padding(.horizontal, 32)

            Spacer()
            nextButton
        }
        .padding(.horizontal, 24)
    }

    private var privacyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.green)

            Text("Your Privacy Matters")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                Text("Audio and transcripts never leave your device.")
                    .font(.body)
                    .multilineTextAlignment(.center)

                Text("Transcription runs entirely on-device using Apple's speech recognition. No cloud upload, no data collection.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
            nextButton
        }
        .padding(.horizontal, 24)
    }

    /// 重点：国内 AI 分享需要复制粘贴的说明
    private var aiSharePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(Color.purple)

            Text("Send to AI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                Text("Share your transcript directly to Doubao, DeepSeek, Tongyi Qianwen, Kimi, and more.")
                    .font(.body)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "1.circle.fill")
                            .foregroundStyle(.purple)
                        Text("Tap **Send to AI** on any recording")
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "2.circle.fill")
                            .foregroundStyle(.purple)
                        Text("Choose your AI app — it opens automatically")
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "3.circle.fill")
                            .foregroundStyle(.purple)
                        Text("Paste the text into the chat")
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 16)

                // 重点提示：国内 AI
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(.orange)
                    Text("For Doubao, DeepSeek, Qwen, and Kimi — the transcript is copied to your clipboard. Just paste after the app opens.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)

            Spacer()
            nextButton
        }
        .padding(.horizontal, 24)
    }

    private var getStartedPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.purple)

            Text("You're All Set")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Tap the microphone to start your first recording.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation {
                    settings.onboardingComplete = true
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Components

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.purple)
                .frame(width: 32)
            Text(text)
                .font(.body)
            Spacer()
        }
    }

    private var nextButton: some View {
        Button {
            withAnimation {
                currentPage += 1
            }
        } label: {
            Text("Next")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.purple : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(currentPage == index ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
