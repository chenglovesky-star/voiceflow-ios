import Testing
import Foundation
@testable import VoiceFlow

@Suite("Performance baselines")
@MainActor
struct PerformanceTests {

    @Test("SRT generation handles 5000 segments under 100ms")
    func srtLargeInput() {
        let svc = ExportService()
        let segs = (0..<5000).map { i in
            TranscriptSegment(
                text: "segment \(i)",
                start: TimeInterval(i),
                end: TimeInterval(i) + 0.9
            )
        }
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            _ = svc.srtTranscript(segments: segs)
        }
        let ms = Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
        #expect(ms < 100, "SRT generation took \(ms) ms (target < 100 ms for 5000 segs)")
    }

    @Test("Transcript fullText handles 5000 segments quickly")
    func fullTextLargeInput() {
        let segs = (0..<5000).map { i in
            TranscriptSegment(text: "word\(i)", start: TimeInterval(i), end: TimeInterval(i) + 0.5)
        }
        let t = Transcript(recordingId: UUID(), segments: segs, locale: "en-US")
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            _ = t.fullText
        }
        let ms = Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
        #expect(ms < 50, "fullText took \(ms) ms (target < 50 ms for 5000 segs)")
    }

    @Test("ResumptionGuard high-contention is correct")
    func guardConcurrency() async {
        let guardian = ResumptionGuard()
        let counter = AtomicCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<200 {
                group.addTask { @Sendable in
                    guardian.tryRun {
                        counter.increment()
                    }
                }
            }
        }
        #expect(counter.value == 1)
    }
}

final class AtomicCounter: @unchecked Sendable {
    private var _value = 0
    private let lock = NSLock()

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return _value
    }

    func increment() {
        lock.lock(); defer { lock.unlock() }
        _value += 1
    }
}
