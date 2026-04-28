# TestFlight + App Store Submission Checklist

> Use this in order. Every box should be checked before tapping "Submit for Review".

## A. Before opening Xcode (you do, ~10 min)

- [ ] Apple Developer membership active (`developer.apple.com/account`)
- [ ] App Store Connect access (`appstoreconnect.apple.com`)
- [ ] Bundle ID `com.lei.voiceflow` registered (Identifiers)
- [ ] If iCloud sync is wanted: container `iCloud.com.lei.voiceflow` created
- [ ] Privacy Policy URL is **live** (placeholder in METADATA.md must be replaced)
- [ ] Support URL is **live**
- [ ] Pricing tier decided (default: Tier 5 $4.99 with $2.99 launch promo, 30 days)

## B. Real-device verification rounds (you do)

### Round #1 — Phase 3 (transcription quality)
- [ ] Connect iPhone 12 mini (iOS 26.2) to Mac, trust device
- [ ] Run on device from Xcode
- [ ] Record 30 sec EN sample → transcript readable, < 5 sec processing
- [ ] Record 30 sec ZH-Hans sample → transcript readable
- [ ] Record 5 min meeting → no crash
- [ ] If quality < 80%, flag for Phase 8.5 (WhisperKit activation)

### Round #2 — Phase 5 + 6 (export + AI share)
- [ ] Tap recording → detail page → Export menu
  - [ ] M4A export → share to Mail / Files
  - [ ] MP3 export → share to Files
  - [ ] TXT export → share to Notes
  - [ ] SRT export → share to Files (open in VLC to verify)
  - [ ] Markdown export → share to Notes
- [ ] "Send to AI" CTA appears with valid transcript
  - [ ] Send to Perplexity → app opens, paste shows full transcript
  - [ ] Send to ChatGPT → ditto
  - [ ] Send to Gemini → ditto
  - [ ] Uninstall one, retry → web fallback opens

### Round #3 — Phase 7 (settings)
- [ ] Toggle sample rate / bit rate / iCloud → persists across app relaunch
- [ ] About page shows correct version + build

## C. Archive & upload (Mac, ~15 min)

```bash
# 1. Generate Xcode project from project.yml
cd ~/Desktop/voiceflow-ios
xcodegen generate

# 2. Run full test suite one more time
xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' \
  test

# 3. Archive (signed Distribution build)
./scripts/archive.sh

# 4. Open Xcode Organizer → Validate → Distribute App → App Store Connect
```

## D. ASC metadata (~30 min)

Open https://appstoreconnect.apple.com → My Apps → VoiceFlow:

- [ ] **App Information**: copy from `asc/METADATA.md` § "App Information"
- [ ] **Pricing & Availability**: Tier 5 / United States only
- [ ] **App Privacy**: declare **Data Not Collected** (see § "App Privacy Q&A")
- [ ] **Version 0.1.0**:
  - [ ] What's New
  - [ ] Description
  - [ ] Keywords
  - [ ] Promotional Text
  - [ ] Support URL (live)
  - [ ] Privacy Policy URL (live)
- [ ] **Screenshots** (4 required, 6.7"):
  - [ ] Recording view (waveform mid-recording)
  - [ ] Recordings list with 3-5 sample entries
  - [ ] Detail page with audio player + transcript visible
  - [ ] "Send to AI" menu open
- [ ] **App Preview** (optional, 30 sec):
  - Screen recording showing: tap mic → record 5 sec → stop → transcript appears → tap "Send to AI" → Perplexity opens
- [ ] **Build**: select 0.1.0 (1) from TestFlight uploaded build

## E. Submit for Review

- [ ] **Sign-in info**: not required (no account in app)
- [ ] **Notes for review**:
  ```
  VoiceFlow records audio and transcribes it entirely on-device using
  Apple's Speech framework. No data is collected or transmitted.
  The "Send to AI" feature copies the transcript to the system clipboard
  and opens the chosen AI app (Perplexity / ChatGPT / Gemini / Claude)
  if installed, falling back to its web URL otherwise. We do not call
  any AI API ourselves.
  Microphone permission is required to record. Speech recognition
  permission is required for on-device transcription.
  ```
- [ ] Click **Submit for Review**

## F. Post-submission

Watch ASC inbox. Typical review: 24-72h. If rejected, see `METADATA.md` § "Reject-risk pre-empt" for response template.
