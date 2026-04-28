# App Store Connect Metadata — VoiceFlow

> Use this to populate ASC App Information / Version 0.1.0.
> Bundle ID: `com.lei.voiceflow` · Team: `7337LF5P35`

## App Information

| Field | Value |
|---|---|
| Name | VoiceFlow |
| Subtitle (30 char) | Local AI Audio Transcription |
| Primary Category | Productivity |
| Secondary Category | Utilities |
| Content Rights | Does not contain third-party content |
| Age Rating | 4+ |

## Version 0.1.0

### What's New (4000 char)

> First release.
>
> Record audio. Get a transcript. Send it to any AI app — without leaving your phone.
>
> VoiceFlow records to compact M4A files (0.5 MB / minute) and transcribes them on-device, so a 30-minute meeting becomes a searchable text file in seconds, never leaves your phone, and is small enough for any AI tool to accept.

### Description (4000 char)

```
Record. Transcribe. Send to AI. Locally.

VoiceFlow is the simplest way to turn voice into text on iPhone — and the only one that does the whole workflow on your device.

— Why VoiceFlow exists —

Most "voice recorder" apps save audio in formats that AI tools (Perplexity, ChatGPT, Gemini) refuse because the files are too large. So you end up paying for a recorder, paying again for a converter, and still hitting a 25 MB upload limit. VoiceFlow collapses the whole flow into one tap.

— What you get —

• One-tap recording. Default M4A AAC at 64 kbps mono — half a megabyte per minute. A two-hour meeting weighs ~60 MB.
• On-device transcription. Apple's Speech framework runs on your phone. No cloud upload, no per-minute charges, no privacy compromise.
• Send to AI. One button copies your transcript and opens Perplexity, ChatGPT, Gemini, or Claude. Paste and go.
• Export everything. M4A, MP3, plain text, SRT subtitles, or Markdown — every format your workflow needs.
• Built-in player. Listen back, scrub through the recording, see what you said.
• Tap to send to your AI app of choice. We handle the formats.

— Privacy by design —

Audio and transcripts never leave your device. There is no account. There is no analytics SDK. The app does not collect data. Period.

— What's coming —

Long-form transcription via Apple's new SpeechAnalyzer (iOS 26+), iCloud sync across your devices, and live transcription while recording.

— Pricing —

One-time purchase. No subscription. We mean it.
```

### Keywords (100 char)

```
voice recorder,transcription,audio to text,meeting notes,dictation,interview,subtitle,SRT,ai
```

### Promotional Text (170 char)

```
Record once, get text + audio + AI-ready exports. All on-device. No subscription. Half-MB per minute.
```

### Support URL

`https://github.com/leicheng9/voiceflow-ios` (placeholder — replace with real)

### Marketing URL

(empty)

### Privacy Policy URL

`https://leicheng9.github.io/voiceflow/privacy.html` (placeholder — must be live before submit)

## Privacy Nutrition Label

**Data Not Collected** (single declaration)

Reasoning:
- Audio: stored only in app sandbox (`Documents/recordings/`), never sent off device
- Transcripts: stored only in SwiftData on device
- No analytics SDK
- No crash reporting SDK (will use Apple's Xcode Crash Reports)
- iCloud (when activated, post-Phase 10) is "Linked to You" but counts as user-managed sync, not collection

## App Privacy Q&A (when ASC asks)

| Question | Answer |
|---|---|
| Do you collect data from this app? | **No** |
| Use third-party SDKs? | No |
| Use tracking? | No |

## Required Permissions Strings

Already in Info.plist (Phase 1):
- `NSMicrophoneUsageDescription`: "VoiceFlow records audio so it can transcribe what you said. Audio never leaves your device."
- `NSSpeechRecognitionUsageDescription`: "VoiceFlow transcribes your recordings on-device using Apple's speech recognition. Nothing is uploaded."

## Pricing & Availability

| Field | Value |
|---|---|
| Price Tier | Tier 5 (USD $4.99) |
| Introductory Offer | 7-day promo at Tier 3 ($2.99) for first 30 days |
| Availability | United States only (initial launch) |

## Reject-risk pre-empt

Apple Guideline 4.0 ("design / functionality") concerns for utility apps:
- **Counter-evidence**: VoiceFlow combines record + transcribe + AI-share + 5 export formats — not a single-feature app.
- **Backup plan**: If rejected, add a 2-3 line response template emphasizing "on-device speech recognition + AI workflow integration" as differentiators vs. system Voice Memos.
