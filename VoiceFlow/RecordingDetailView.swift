import SwiftUI
import CoreData

struct RecordingDetailView: View {
    var entity: RecordingEntity
    var isTranscribing: Bool
    var transcriptionError: String? = nil
    var onDeleteRequested: (() -> Void)? = nil
    var onRetryTranscription: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleted = false
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var exportError: String?
    @State private var isExporting = false

    private let exportService = ExportService()

    var body: some View {
        // pop アニメーション中に body が削除済み entity の @NSManaged プロパティに
        // アクセスして NSObjectInaccessibleException を起こさないよう guard する。
        if isDeleted {
            Color.clear
        } else {
            VStack(spacing: 0) {
                AudioPlayerView(url: entity.fileURL)
                    .frame(maxHeight: 180)

                Divider()

                transcriptSection

                if hasTranscript {
                    Divider()
                    sendToAICTA
                }
            }
            .navigationTitle(entity.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    menu
                }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ShareSheet(items: shareItems)
            }
            .alert("Export failed", isPresented: errorBinding) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private var hasTranscript: Bool {
        if let t = entity.transcript { return !t.segments.isEmpty }
        return false
    }

    private var sendToAICTA: some View {
        Button {
            shareTranscript()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("分享转录")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding()
        }
    }

    @ViewBuilder
    private var menu: some View {
        Menu {
            Section("Export") {
                ForEach(ExportFormat.allCases, id: \.self) { fmt in
                    Button {
                        Task { await export(format: fmt) }
                    } label: {
                        Label(fmt.rawValue, systemImage: fmt.systemImage)
                    }
                    .disabled(isExporting)
                }
            }
            Divider()
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(isExporting)
        } label: {
            if isExporting {
                ProgressView()
            } else {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private var transcriptSection: some View {
        if isTranscribing {
            VStack(spacing: 12) {
                ProgressView()
                Text("Transcribing on-device…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let transcript = entity.transcript, !transcript.segments.isEmpty {
            ScrollView {
                Text(transcript.fullText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        } else if entity.transcript != nil {
            VStack(spacing: 16) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No speech detected")
                    .font(.headline)
                Text("The recording did not contain recognizable speech.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                if let err = transcriptionError {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Transcription failed")
                        .font(.headline)
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let onRetry = onRetryTranscription {
                        Button {
                            onRetry()
                        } label: {
                            Label("Retry transcription", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                } else {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Transcript pending")
                        .font(.headline)
                    Text("Transcription will appear here when complete.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func delete() {
        let fileURL = entity.fileURL
        let sessionId = entity.sessionId

        // 1. 取消正在进行的转录 Task，防止 SFSpeechRecognizer 持续占用 mediaserverd。
        onDeleteRequested?()

        // 2. 先让 body 切到 Color.clear，防止 pop 动画帧访问已删除 entity 的 @NSManaged 属性，
        //    同时下一帧会触发 AudioPlayerView.onDisappear → controller.stop()，
        //    在文件被删除前先释放 AVAudioPlayer 与 AVAudioSession。
        isDeleted = true

        context.delete(entity)
        dismiss()

        // 3. 文件删除与 ctx.save() 全部推迟到下一帧：
        //    - 让 onDisappear 先执行，AVAudioPlayer 释放完再 unlink 文件，避免 AVFoundation 长尾；
        //    - 让 @FetchRequest 的导航更新跨帧执行，避免同一帧内两次导航更新触发
        //      "NavigationRequestObserver multiple updates" 崩溃。
        let ctx = context
        Task { @MainActor in
            try? FileManager.default.removeItem(at: fileURL)
            if let sid = sessionId {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let sessionDir = docs
                    .appendingPathComponent(RecordingService.sessionsDirectoryName, isDirectory: true)
                    .appendingPathComponent(sid.uuidString, isDirectory: true)
                try? FileManager.default.removeItem(at: sessionDir)
            }
            try? ctx.save()
        }
    }

    private func export(format: ExportFormat) async {
        guard !isExporting else { return }
        isExporting = true
        let ctx = ExportContext.from(entity)
        do {
            let url = try await exportService.export(ctx, format: format)
            shareItems = [url]
            isShareSheetPresented = true
        } catch {
            exportError = error.localizedDescription
        }
        isExporting = false
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    /// 弹系统 Share Sheet 让用户选目标 app（豆包/ChatGPT/Claude/Kimi/微信...）。
    /// 文本通过 NSItemProvider 走系统级共享，目标 app 的 Share Extension 会
    /// 把内容直接放进对话框/输入框，**用户不需要再手动粘贴**。
    /// 同时把文本写入剪贴板作为兜底（用户取消 ShareSheet 后可手动粘贴）。
    private func shareTranscript() {
        let segments = entity.transcript?.segments ?? []
        guard !segments.isEmpty else {
            exportError = "No transcript yet to send."
            return
        }
        let text = segments.map(\.text).joined(separator: " ")
        UIPasteboard.general.string = text
        shareItems = [text]
        isShareSheetPresented = true
    }
}
