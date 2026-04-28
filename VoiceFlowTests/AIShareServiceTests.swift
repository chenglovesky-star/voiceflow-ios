import Testing
import Foundation
@testable import VoiceFlow

@Suite("AITarget URLs")
struct AITargetTests {

    @Test("each target exposes detection / web URLs")
    func urls() {
        for t in AITarget.allCases {
            #expect(t.detectionURL.absoluteString.contains("://"))
            #expect(t.webURL.scheme == "https")
            #expect(!t.displayName.isEmpty)
        }
    }

    @Test("known schemes are stable")
    func schemes() {
        #expect(AITarget.perplexity.detectionURL.scheme == "perplexity")
        #expect(AITarget.chatgpt.detectionURL.scheme == "chatgpt")
        #expect(AITarget.gemini.detectionURL.scheme == "googlegemini")
        #expect(AITarget.claude.detectionURL.scheme == "claude")
    }

    @Test("web URLs are HTTPS")
    func webHTTPS() {
        for t in AITarget.allCases {
            #expect(t.webURL.scheme == "https")
        }
    }
}
