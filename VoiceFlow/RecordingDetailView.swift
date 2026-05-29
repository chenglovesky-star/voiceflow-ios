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
    private let aiShareService = AIShareService()

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

    /// Send to AI 入口：国产 AI（豆包/Kimi/通义/DeepSeek）走 deep link 直送，
    /// 其余 app 走系统 Share Sheet（ShareLink）。
    private var sendToAICTA: some View {
        let text = transcriptText
        return Menu {
            ForEach(AITarget.allCases, id: \.self) { target in
                Button {
                    Task { await sendToAI(target) }
                } label: {
                    Label(target.displayName, systemImage: target.systemImage)
                }
            }
            Divider()
            ShareLink(item: text) {
                Label("Share to other AI…", systemImage: "square.and.arrow.up")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Send to AI")
                Image(systemName: "chevron.down")
                    .font(.caption)
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

    /// 当前 transcript 拼接后的完整文本；空字符串表示无内容。
    private var transcriptText: String {
        (entity.transcript?.segments ?? []).map(\.text).joined(separator: " ")
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

    /// 海外 4 家：先尝试 deep link 直送 app，失败回退 https
    /// （AIShareService.send 内部已有逻辑，调用方只需处理空 transcript）。
    private func sendToAI(_ target: AITarget) async {
        let text = transcriptText
        guard !text.isEmpty else {
            exportError = "No transcript yet to send."
            return
        }
        _ = await aiShareService.send(text, to: target)
    }
}
