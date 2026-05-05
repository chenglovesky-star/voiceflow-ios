import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Sample rate", selection: $settings.defaultSampleRate) {
                    Text("16 kHz (smaller files)").tag(16_000)
                    Text("44.1 kHz (default)").tag(44_100)
                    Text("48 kHz (high quality)").tag(48_000)
                }
                Picker("Bit rate", selection: $settings.defaultBitRate) {
                    Text("32 kbps").tag(32_000)
                    Text("64 kbps (default)").tag(64_000)
                    Text("128 kbps (high quality)").tag(128_000)
                }
            } header: {
                Text("Recording")
            } footer: {
                Text("New recordings use these settings. Existing recordings keep their original encoding.")
            }

            Section {
                Picker("Waveform style", selection: $settings.waveformStyleId) {
                    ForEach(WaveformStyle.allCases, id: \.rawValue) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
                // App display language picker — independent of system language.
                // Native names (English / 简体中文 / ...) are intentionally NOT
                // localized so users can find their language regardless of the
                // current UI locale.
                Picker("App language", selection: $settings.appLocaleId) {
                    ForEach(AppSettings.appLocaleOptions, id: \.id) { option in
                        Text(option.displayName).tag(option.id)
                    }
                }
            } header: {
                Text("Display")
            } footer: {
                Text("Choose how the waveform looks and what language the app UI uses.")
            }

            Section {
                Picker("Transcription language", selection: $settings.transcriptionLocaleId) {
                    Text("Auto (device language)").tag(AppSettings.autoLocaleId)
                    Text("简体中文").tag("zh-CN")
                    Text("繁體中文").tag("zh-TW")
                    Text("English (US)").tag("en-US")
                    Text("English (UK)").tag("en-GB")
                    Text("日本語").tag("ja-JP")
                    Text("한국어").tag("ko-KR")
                    Text("Español").tag("es-ES")
                    Text("Français").tag("fr-FR")
                    Text("Deutsch").tag("de-DE")
                }
            } header: {
                Text("Transcription")
            } footer: {
                Text("Pick the language you actually speak in recordings. iOS may need to download an on-device model for the chosen language the first time.")
            }

            Section("iCloud") {
                Toggle("Sync across my devices", isOn: $settings.iCloudEnabled)
                if settings.iCloudEnabled {
                    Text("CloudKit container provisioning is required to actually sync. See README — sync is wired in Phase 10 of the roadmap.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Label {
                    Text("Audio and transcripts never leave your device.")
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                }
                .font(.footnote)
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
                // Contact 行：邮箱地址直接当作可点击 Link 显示在 trailing 位置，
                // 比单独的 "Support" 链接更明确——用户一眼能看到联系邮箱本身。
                if let supportEmail = Bundle.main.object(forInfoDictionaryKey: "SupportEmail") as? String,
                   let supportURL = URL(string: "mailto:\(supportEmail)") {
                    LabeledContent("Contact") {
                        Link(supportEmail, destination: supportURL)
                    }
                }
            }

        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
