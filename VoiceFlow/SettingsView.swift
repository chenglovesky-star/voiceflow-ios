import SwiftUI

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
