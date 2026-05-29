# VoiceFlow iOS — 全功能代码审查报告

**审查日期：** 2026-05-04
**审查范围：** VoiceFlow/ 全部 20 个源文件 + VoiceFlowTests/ 全部测试
**审查深度：** Standard（逐文件精读 + 跨文件引用分析）
**审查员：** Claude Sonnet 4.6

---

## 目录

1. [已确认修复项](#1-已确认修复项)
2. [Critical — 严重问题](#2-critical--严重问题)
3. [Important — 重要问题](#3-important--重要问题)
4. [Suggestion — 一般建议](#4-suggestion--一般建议)
5. [测试覆盖评估](#5-测试覆盖评估)
6. [总体评价](#6-总体评价)

---

## 1. 已确认修复项

以下问题经过逐行代码核实，确认均已正确修复：

| # | 修复项 | 确认位置 |
|---|--------|---------|
| F1 | `RecordingDetailView.delete()` 先调用 `dismiss()` 再删除，避免 use-after-free 崩溃 | `RecordingDetailView.swift:177-182` — `context.save()` 成功后才 `dismiss()` |
| F2 | Delete 按钮在 `isExporting` 时被 `.disabled(isExporting)` 禁用 | `RecordingDetailView.swift:103-104` ✓ |
| F3 | `RecordingService.startNewSegment()` 使用 `AppSettings.shared` 的 `sampleRate/bitRate` | `RecordingService.swift:95-102` ✓ |
| F4 | `AudioPlayerController.play()` 使用 `.mixWithOthers` 选项 | `AudioPlayerView.swift:31` ✓ |
| F5 | `ContentView` 的 Task 标注 `@MainActor` | `ContentView.swift:183` ✓ |
| F6 | `RecordingService.cleanup()` 调用 `AVAudioSession.setActive(false)` | `RecordingService.swift:269` ✓ |
| F7 | `TranscriptEntity` 设置反向关系 `te.recording = target` | `ContentView.swift:194` ✓ |
| F8 | `ContentView.deleteEntities` 直接 `removeItem`（修复 TOCTOU） | `ContentView.swift:214-221` ✓ |
| F9 | `OnDeviceTranscriptionService` 使用 `TaskHolder + withTaskCancellationHandler` | `OnDeviceTranscriptionService.swift:147-213` ✓ |

> **注意**：F6 已在 `cleanup()` 中修复，但 `AudioPlayerController.stop()` 另有相同模式，见 Important I2。

---

## 2. Critical — 严重问题

### CR-01：`advanceToNextSegment` 中 `startNewSegment()` 错误被静默丢弃，`isRecording` 状态错乱

**文件：** `RecordingService.swift:158-164`

**问题：** `advanceToNextSegment()` 中使用 `do { let newSegment = try startNewSegment(); segments.append(newSegment) } catch { interruptedError = ...; cleanup() }`，代码逻辑本身有捕获错误，但检查代码实际执行路径：`cleanup()` 被调用后 `isRecording` 被设为 `false`，然而 `meteringTimer` 的回调 `tick()` 在 `cleanup()` 之前仍可被调度一次（Timer 的 `invalidate()` 不是同步取消已入队的 GCD 任务）。更大问题是：**`startSegmentTimer` 的 Timer 回调通过 `Task { @MainActor }` 派发，若 `advanceToNextSegment` 在 Timer 回调中执行，而此时 `recorder` 已被 `stop()` 但 `recorder` 属性尚未清空（`cleanup()` 之前），第 137 行 `recorder.stop()` 会被重复调用。**

更严重的是：若 `startNewSegment()` 抛出并执行 `cleanup()`，`segmentTimer` 被 `invalidate()`，但调用此函数的是 `segmentTimer` 的闭包本身，此时 `cleanup()` 内 `segmentTimer?.invalidate()` 是安全的；但 `segments` 中已添加的前几段的 `totalSegments` 值此后无法再被更新为正确值（永远保留为临时值），导致最终 `RecordingSession` 中各段的 `totalSegments` 不一致。

**影响：** 录音中断时，UI 状态可能残留"录音中"显示；导出时各段 `totalSegments` 字段值不一致。

**修复：**

```swift
private func advanceToNextSegment() {
    guard let rec = recorder, let started = startedAt,
          let sessionId = currentSessionId else { return }

    rec.stop()
    let duration = Date().timeIntervalSince(started)

    // 更新最后一段的实际 duration
    if currentSegmentIndex < segments.count {
        var updated = segments[currentSegmentIndex]
        updated = Recording(
            id: updated.id, url: updated.url, duration: duration,
            createdAt: updated.createdAt, displayName: updated.displayName,
            sessionId: updated.sessionId, segmentIndex: updated.segmentIndex,
            totalSegments: updated.totalSegments
        )
        segments[currentSegmentIndex] = updated
    }

    currentSegmentIndex += 1
    do {
        let newSegment = try startNewSegment()
        segments.append(newSegment)
    } catch {
        // 开启新分段失败：终止录音并通知 UI
        interruptedError = "录音分段失败：\(error.localizedDescription)"
        cleanup()  // cleanup 内部 recorder=nil，不会重复 stop
    }
}
```

---

### CR-02：`TranscriptionServiceFactory.make()` 用 `Locale.current` 判断可用性，与运行时实际 locale 不一致

**文件：** `OnDeviceTranscriptionService.swift:18-20`，`TranscriptionServiceFactory.swift:5-10`

**问题：** `isAvailable` 使用 `SFSpeechRecognizer(locale: .current)` 检查可用性，而实际 `transcribe()` 方法使用用户在 `AppSettings` 中配置的 locale（可能是 `zh-CN`）。若 `Locale.current` 是 `en-US`（可用），但 `zh-CN` 的 on-device 模型未下载，工厂返回 `OnDeviceTranscriptionService`，但实际转录时 `resolvedLocale(for:)` 无法找到匹配的支持 locale，抛出 `TranscriptionError.unavailable`。这对选择非系统语言的中文用户尤为明显。

**影响：** 用户看到转录失败错误（而非优雅的降级提示），且工厂的 Fallback 到 `WhisperKitTranscriptionService` 实际上永远不触发（因为工厂判断和运行时判断基准不同）。

**修复：** 在工厂中传入目标 locale，或将 `isAvailable` 改为接受 locale 参数：

```swift
// TranscriptionServiceFactory.swift
static func make(locale: Locale = AppSettings.shared.transcriptionLocale) -> any TranscriptionService {
    let primary = OnDeviceTranscriptionService()
    if primary.isAvailable(for: locale) {
        return primary
    }
    return WhisperKitTranscriptionService()
}

// OnDeviceTranscriptionService.swift
func isAvailable(for locale: Locale = .current) -> Bool {
    guard let resolvedLocale = Self.resolvedLocale(for: locale) else { return false }
    guard let recognizer = SFSpeechRecognizer(locale: resolvedLocale) else { return false }
    return recognizer.isAvailable
}
```

---

### CR-03：`VoiceFlowApp` 中 `loadPersistentStores` 的嵌套重试逻辑存在数据静默丢失风险

**文件：** `VoiceFlowApp.swift:8-24`

**问题：** 当 CoreData 存储加载失败时，代码会静默删除整个存储文件（包括 `-shm` 和 `-wal`），然后再次调用 `loadPersistentStores`。这意味着用户**所有历史录音元数据（名称、转录、时长等）都被永久删除**，而用户没有收到任何警告或提示。即使录音音频文件仍在磁盘上，CoreData 关联信息消失后用户无法从 UI 找到这些文件。

此外，`container.loadPersistentStores` 的回调不保证在哪个线程执行，而第二次嵌套调用 `container.loadPersistentStores` 在 store 加载闭包内部执行，行为未定义（可能导致死锁）。

**影响：** 任何 CoreData 存储异常（schema migration 错误、iOS 升级后格式变化）都会触发静默数据清除，用户无法感知数据丢失。

**修复：** 至少在删除前记录错误并通过某种机制通知用户：

```swift
container.loadPersistentStores { storeDescription, error in
    if let error = error as NSError? {
        // 生产中：向 crash reporter 上报，并展示错误 UI 而非静默删除
        // 开发中：直接 fatalError 暴露问题
        #if DEBUG
        fatalError("CoreData load failed: \(error)")
        #else
        // 最后手段：删除并重建（用户数据丢失，需 UI 告知）
        // 建议：通过 @Published var needsDataReset = true 触发 UI 提示
        if let url = storeDescription.url {
            try? FileManager.default.removeItem(at: url)
        }
        container.loadPersistentStores { _, _ in }
        #endif
    }
}
```

---

## 3. Important — 重要问题

### I1：`audioRecorderEncodeErrorDidOccur` 静默 cleanup，不通知 UI

**文件：** `RecordingService.swift:299-303`

**问题：** 编码错误（低内存、格式不支持）发生时，`cleanup()` 被调用（`isRecording` = false），但 `interruptedError` 未被设置。UI 的录音界面突然消失，没有任何错误提示，用户不知道发生了什么。

**修复：**
```swift
nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    Task { @MainActor [weak self] in
        self?.interruptedError = error?.localizedDescription ?? "录音编码错误"
        self?.cleanup()
    }
}
```

---

### I2：`AudioPlayerController.play()` 切换 AVAudioSession 类别后 `stop()/pause()` 未恢复

**文件：** `AudioPlayerView.swift:28-35`, `63-72`

**问题：** `play()` 将 session 切换为 `.playback` 类别，但 `stop()` 中虽然调用了 `setActive(false)`，并未将 category 重置回任何状态。若用户播放录音后立即点击开始录音，`RecordingService.start()` 中 `setCategory(.playAndRecord, ...)` 会重新配置，但两个 session 操作之间没有同步点，可能导致 `setActive(true)` 失败（前一个 session 未完全停止）。

另外，`pause()` 不调用 `setActive(false)`，这意味着即使暂停后，音频会话仍处于激活状态，阻止其他 App 的音频恢复。

**修复：**
```swift
func pause() {
    player?.pause()
    isPlaying = false
    ticker?.invalidate()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
}
```

---

### I3：`RecordingDetailView` 中 `delete()` 删除文件但不处理 `sessionId` 目录

**文件：** `RecordingDetailView.swift:173-183`

**问题：** `delete()` 只删除 `entity.fileURL`（单个音频文件），但若录音属于多段 session（`entity.sessionId != nil`），对应的 session 目录（`sessions/{uuid}/`）中可能还有其他段文件，这些文件永远不会被清理。`ContentView.deleteEntities` 有处理 `sessionId` 目录的逻辑（第 216-221 行），但 `RecordingDetailView.delete()` 没有。

随着用户使用积累，磁盘上会累积大量孤立的音频文件段。

**修复：**
```swift
private func delete() {
    try? FileManager.default.removeItem(at: entity.fileURL)
    // 同步清理 session 目录（非空目录删除会失败，属预期行为）
    if let sid = entity.sessionId {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sessionDir = docs
            .appendingPathComponent(RecordingService.sessionsDirectoryName, isDirectory: true)
            .appendingPathComponent(sid.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: sessionDir)
    }
    context.delete(entity)
    do {
        try context.save()
        dismiss()
    } catch {
        exportError = error.localizedDescription
    }
}
```

---

### I4：`ContentView.handleStop` 中每个 segment 单独 `context.save()`，批量写入效率低且中途失败导致数据不一致

**文件：** `ContentView.swift:170-208`

**问题：** `handleStop` 对每个 `segment` 单独执行 `context.save()`（第 173-177 行）。若录音有 3 段，段 1 和段 2 保存成功，段 3 保存失败，CoreData 中会有部分数据，`entities` FetchRequest 会显示前两段，但 session 不完整。此外，多次 `save()` 的性能也明显低于批量保存。

**修复：**
```swift
// 先批量插入所有实体，最后一次性 save
for segment in session.segments {
    let _ = RecordingEntity.from(segment, context: context)
}
do {
    try context.save()
} catch {
    startError = error.localizedDescription
    return  // 保存失败则不启动转录
}
// 再启动各段的转录 Task
for segment in session.segments { ... }
```

---

### I5：`TranscriptEntity.segments` 的 JSON 编解码错误使用 `assertionFailure` 而非正式错误处理

**文件：** `TranscriptEntity.swift:14-28`

**问题：** `segments` computed property 的 getter 在解码失败时调用 `assertionFailure`（仅 DEBUG 生效），在 Release 中直接返回 `[]`。若模型添加新字段（如 `speakerLabel: String`，非可选）后，历史数据解码失败，用户的所有历史转录内容在界面上消失，但 `segmentsData` 仍在数据库中，数据并未真正丢失——问题是完全没有错误提示。

同样，setter 中 `assertionFailure` 在 Release 中写入空 `Data()`，下次打开 App 时历史转录全部消失。

**修复：** 生产环境需要迁移机制。短期内至少做到：
```swift
var segments: [TranscriptSegment] {
    get {
        guard !segmentsData.isEmpty else { return [] }
        do {
            return try JSONDecoder().decode([TranscriptSegment].self, from: segmentsData)
        } catch {
            // TODO: 触发数据迁移或展示降级 UI，而非静默返回空
            return []
        }
    }
}
```

---

### I6：`OnDeviceTranscriptionService.waitForAvailability` 中 `try?` 静默吞掉 Swift Task 取消信号

**文件：** `OnDeviceTranscriptionService.swift:122-123`

**问题：** 当前代码为：
```swift
try await Task.sleep(nanoseconds: 300_000_000)
```
（已修复为 `try await`，非 `try?`——经核实第 123 行确实使用了 `try await`，会正确传播 `CancellationError`）

**实际状态：** 此问题已正确修复，`CancellationError` 会传播到调用方。✓

---

### I7：`WaveformView` 动画 `value` 参数只对 `levels.last` 触发，大量更新不触发动画

**文件：** `WaveformView.swift:24`

**问题：** `.animation(.linear(duration: 0.2), value: levels.last ?? 0)` 在 `levels` 数组内容变化但末尾值相同时（两次相邻音量相同）不触发动画。更关键的是，当 `levels` 从 60 个元素变化时（`removeFirst` 后 `append`），`last` 不变，动画不触发，视觉上波形"跳变"而非平滑过渡。

**修复：**
```swift
// 用 levels.count 与末尾值组合触发动画
.animation(.linear(duration: 0.2), value: levels.last.map { Int($0 * 1000) } ?? 0)
// 或直接在 RecordingService.tick() 中用 withAnimation { } 包裹 recentLevels 更新
```

---

### I8：`RecordingService.startNewSegment()` 第 125 行强制解包 `startedAt!`

**文件：** `RecordingService.swift:125`

**问题：** `startedAt` 在第 115 行赋值后紧接着在第 125 行被 `startedAt!` 解包。逻辑上不会为 nil，但强制解包会在未来重构中引入崩溃风险（如有人在 `startedAt` 赋值前插入 return 路径）。

**修复：**
```swift
let now = Date()
startedAt = now
// ...
return Recording(url: url, duration: 0, createdAt: now, ...)
```

---

### I9：`ExportFormat.aac` 实际导出 M4A 容器，UI 标签具有误导性

**文件：** `ExportService.swift:108-133`，`ExportFormat`定义第 6 行

**问题：** 用户在导出菜单中选择"AAC"，实际收到的文件扩展名是 `.m4a`（`fileExtension` 返回 `"m4a"`）。这是技术正确的（AAC 编码在 M4A 容器中），但 UI 标签 `"AAC"` 会让用户困惑，误以为收到的是 `.aac` 裸流文件。若用户将文件发送给不支持 M4A 的系统会遇到意外的格式不匹配。

**建议：** 将 `ExportFormat.aac` 的 `rawValue` 改为 `"AAC (M4A)"` 或 `"重新编码 M4A"`，或在 label 旁加注说明。

---

### I10：`AppSettings` 标注 `@MainActor` 但在 `RecordingService.startNewSegment()` 中同步访问

**文件：** `RecordingService.swift:95`，`AppSettings.swift:4`

**问题：** `RecordingService` 是 `@MainActor` 类，`startNewSegment()` 是其方法，因此实际上在主线程执行，访问 `AppSettings.shared` 是安全的。**但如果未来 `startNewSegment()` 被移到后台（如通过 `Task.detached`）**，`AppSettings.shared.defaultSampleRate` 在非主线程访问会违反 `@MainActor` 约束且可能崩溃。

当前无 bug，但建议在注释中明确说明依赖 `@MainActor` 上下文：
```swift
// 必须在 @MainActor 上下文调用（AppSettings.shared 是 @MainActor 隔离的）
private func startNewSegment() throws -> Recording {
```

---

## 4. Suggestion — 一般建议

### S1：`RecordingView` 和 `ContentView` 对 `interruptedError` 显示重复，可能产生双重弹窗

**文件：** `RecordingView.swift:41-45`，`ContentView.swift:49-53`

`RecordingView` 内嵌在 `ContentView` 的 `NavigationStack` 中（`ContentView.swift:24-27`）。两个 View 都对 `service.interruptedError` 绑定了 `.alert`，理论上 SwiftUI 只会展示最近的 alert modifier，但此处是两个 View 层级中都有绑定，行为依赖 SwiftUI 内部实现，可能导致 alert 竞争。建议只在一处（顶层 `ContentView`）处理该 alert。

---

### S2：`deleteEntities` 中 `startError` 被用于 CoreData 删除失败的提示，语义混淆

**文件：** `ContentView.swift:228-230`

`startError` 的语义是"录音无法开始"，但此处被复用为"删除保存失败"的错误提示。两种错误共享同一个 `@State` 变量，alert 标题显示"Cannot start"而实际错误是删除失败，对用户造成混淆。

**建议：** 添加专用的 `@State private var deleteError: String?` 和对应的 alert。

---

### S3：`SafeName` 正则允许文件名中包含空格

**文件：** `ExportService.swift:187-192`

字符类 `[^A-Za-z0-9_\\u4e00-\\u9fff -]` 中 ` -` 代表"空格"和"连字符"，保留了空格。文件名中的空格在某些 Share Extension（如发送到 Files App 后再复制路径）处理时可能导致 URL 编码问题。

**建议：** 将空格替换为下划线 `_`：
```swift
.replacingOccurrences(of: " ", with: "_")
```

---

### S4：`RecordingSession` 中 `id` 和 `sessionId` 字段重复

**文件：** `Recording.swift:66-92`

`RecordingSession` 同时有 `id: UUID` 和 `sessionId: UUID`，两者在 `init` 中被赋值为同一个值（第 88 行）。这是冗余字段，容易在未来维护中产生不一致。

**建议：** 移除 `id`，只保留 `sessionId`，并让 `Identifiable` 的 `id` 返回 `sessionId`：
```swift
var id: UUID { sessionId }
```

---

### S5：`TranscriptionServiceFactory.make()` 在 View 初始化时同步调用，阻塞主线程

**文件：** `ContentView.swift:19`

```swift
private let transcriptionService: any TranscriptionService = TranscriptionServiceFactory.make()
```

`make()` 内部调用 `SFSpeechRecognizer(locale: .current)` 和 `.isAvailable`，虽然通常很快，但在低端设备或首次安装时可能阻塞主线程 View 初始化。

**建议：** 改为懒加载或在 `.task {}` 中异步初始化。

---

### S6：`ExportService` 导出的临时文件没有清理机制

**文件：** `ExportService.swift:180-183`

每次导出都写入 `tmp/exports/` 目录，但从不清理旧文件。用户多次导出同名文件时使用 `try? removeItem` 覆盖，但不同名文件会无限积累。

**建议：** 在 App 启动时或导出完成后清理 `tmp/exports/` 目录。

---

### S7：`SettingsView` 的 URL Scheme Debug Section 使用了 emoji，与代码风格不一致

**文件：** `SettingsView.swift:76`

```swift
Section("🔧 URL Scheme Debug") {
```

仅是 DEBUG 构建，但 emoji 在代码中是风格问题（部分 linter 规则会标记）。

---

### S8：`Recording.defaultName(for:)` 中 `DateFormatter` 每次调用都创建新实例

**文件：** `Recording.swift:50-54`

`DateFormatter` 初始化开销较大。`defaultName` 是静态方法，每次调用 `Recording(...)` 时都会创建新的 `DateFormatter`。

**建议：** 使用 `static let` 缓存：
```swift
private static let nameFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f
}()

static func defaultName(for date: Date) -> String {
    "Recording \(nameFormatter.string(from: date))"
}
```

---

## 5. 测试覆盖评估

### 已覆盖（良好）

| 测试文件 | 覆盖内容 |
|---------|---------|
| `ExportServiceTests.swift` | TXT/SRT/Markdown 格式、`srtTime` 边界值、`ExportFormat` 属性 |
| `RecordingTests.swift` | `Recording` 值类型语义、`defaultName`、`makeRecordingURL` |

### 关键路径缺失

| 缺失场景 | 风险等级 | 说明 |
|---------|---------|------|
| `RecordingService.advanceToNextSegment()` 分段 `totalSegments` 正确性 | **高** | CR-01 相关，目前无测试覆盖 |
| `ContentView.handleStop` 中 `transcribingIds` 并发状态管理 | **高** | 多 Task 并发插入/移除 |
| `OnDeviceTranscriptionService` 超时路径（90s）| **高** | `ResumptionGuard` 有测试但超时逻辑无 |
| `RecordingService.stop()` 多段 `RecordingSession` 合并 | **高** | 单段已测，多段未测 |
| `deleteEntities` 文件 + CoreData 联动删除 | **中** | 孤立文件问题 |
| `ExportService.export(.m4a)` 文件不存在路径 | **中** | 只测了格式化逻辑 |
| `TranscriptEntity` 模型变化后 JSON 解码降级 | **中** | I5 相关 |
| `AudioPlayerController` 播放→暂停→Seek 状态机 | **中** | 完全无覆盖 |
| `TranscriptionServiceFactory` locale 不匹配降级 | **中** | CR-02 相关 |

---

## 6. 总体评价

VoiceFlow 的整体架构设计清晰，Swift 并发模型（`@MainActor`、`async/await`、`withTaskCancellationHandler`）的运用达到较高水准，CoreData + SwiftUI 的结合方式符合 iOS 16+ 最佳实践，`ResumptionGuard` 等机制显示出对底层并发细节的思考。

**主要问题集中在三个维度：**

1. **功能正确性**：`TranscriptionServiceFactory` 用错误的 locale 做可用性判断（CR-02），导致中文用户的转录可能始终走失败路径；`RecordingDetailView.delete()` 不清理 session 目录导致磁盘文件泄漏（I3）。

2. **状态一致性**：`advanceToNextSegment()` 中各段 `totalSegments` 字段在异常路径下不一致（CR-01）；`handleStop` 批量 save 的原子性问题（I4）。

3. **用户体验**：`audioRecorderEncodeErrorDidOccur` 静默 cleanup 不提示用户（I1）；`ExportFormat.aac` 标签与实际文件格式不符（I9）；`startError` 被复用于删除错误（S2）。

**优先修复顺序：** CR-02（转录功能核心正确性）→ I3（文件泄漏）→ I1（无声失败）→ CR-01（分段状态一致性）→ I4（批量保存原子性）。

---

_审查员：Claude Sonnet 4.6（gsd-code-reviewer）_
_审查日期：2026-05-04_
