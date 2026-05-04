import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var schemeTestResults: [String: Bool] = [:]
    @State private var isTesting = false

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
                Link("Support", destination: URL(string: "mailto:tsing@alumni.upenn.edu")!)
            }

            #if DEBUG
            Section("🔧 URL Scheme Debug") {
                Button("Test All Schemes") {
                    testAllSchemes()
                }
                .disabled(isTesting)

                if !schemeTestResults.isEmpty {
                    ForEach(AITarget.allCases, id: \.rawValue) { target in
                        if let result = schemeTestResults[target.rawValue] {
                            HStack {
                                Text(target.displayName)
                                Spacer()
                                if result {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("✓ App installed")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text("✗ Not installed (uses web)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            #endif
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func testAllSchemes() {
        isTesting = true
        schemeTestResults = [:]
        for target in AITarget.allCases {
            schemeTestResults[target.rawValue] = UIApplication.shared.canOpenURL(target.detectionURL)
        }
        isTesting = false
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
