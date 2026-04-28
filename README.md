# VoiceFlow iOS

Record. Transcribe. Send to AI. Locally.

> Status: Phase 1 scaffold (2026-04-28)
> See [ROADMAP.md](ROADMAP.md) for full milestone plan.

## Build

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build for simulator
xcodebuild -scheme VoiceFlow -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  build

# Run tests
xcodebuild -scheme VoiceFlow -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test
```

## Why this exists

iOS users who want to convert recordings to text have to chain 4 apps: recorder → file
manager → format converter → AI tool. Each step costs money and breaks. VoiceFlow
collapses the workflow into one screen, transcribes locally on-device, and ships the
text directly to Perplexity / ChatGPT / Gemini.

See `.seed/SOURCE-CARD.md` for the original user pain evidence.

## Architecture (target)

| Layer | Tech | Why |
|-------|------|-----|
| UI | SwiftUI | iOS 26+ first-class |
| Recording | AVAudioRecorder + AVAudioEngine | Native, M4A/AAC default |
| Transcription | SpeechAnalyzer + SpeechTranscriber (iOS 26+) | Local, free, long-form |
| Transcription fallback | WhisperKit (iOS 17-25) | Cover legacy devices |
| Storage | Core Data + CloudKit | iCloud sync without backend |
| Distribution | App Store (US first), one-time \$4.99 | No subscription |

## Project hygiene

- `project.yml` is canonical — `.xcodeproj` is regenerable, gitignored.
- Min iOS 17, target iOS 26+ APIs gated by `if #available`.
- Privacy: Data Not Collected. Audio never leaves device.

## License

TBD.
