import XCTest
@testable import SplashMonitor

final class AgentLaunchTests: XCTestCase {
    
    func testSupportedAgentsIncludesClaudeCowork() {
        XCTAssertTrue(SplashService.supportedAgents.contains("claude-cowork"), "supportedAgents debe incluir 'claude-cowork'")
        XCTAssertTrue(SplashService.supportedAgents.contains("claude"))
        XCTAssertTrue(SplashService.supportedAgents.contains("opencode"))
        XCTAssertTrue(SplashService.supportedAgents.contains("codex"))
        XCTAssertTrue(SplashService.supportedAgents.contains("hermes"))
        XCTAssertTrue(SplashService.supportedAgents.contains("chatgpt"), "supportedAgents debe incluir 'chatgpt'")
        XCTAssertTrue(SplashService.supportedAgents.contains("pi"), "supportedAgents debe incluir 'pi' (Splash 1.3.1)")
        XCTAssertTrue(SplashService.supportedAgents.contains("dsh"), "supportedAgents debe incluir 'dsh' (DeepSeek Harness)")
    }
    
    @MainActor
    func testAgentInstallURLForClaudeCowork() {
        let service = SplashService()
        let url = service.agentInstallURL(agent: "claude-cowork")
        XCTAssertEqual(url.absoluteString, "https://claude.ai/download")
    }
    
    @MainActor
    func testAgentInstallURLForPi() {
        let service = SplashService()
        let url = service.agentInstallURL(agent: "pi")
        XCTAssertEqual(url.absoluteString, "https://pi.dev/")
    }
    
    @MainActor
    func testAgentInstallURLForChatGPT() {
        let service = SplashService()
        let url = service.agentInstallURL(agent: "chatgpt")
        XCTAssertEqual(url.absoluteString, "https://openai.com/chatgpt/download/")
    }
    
    @MainActor
    func testAgentInstallURLForDeepSeekHarness() {
        let service = SplashService()
        let url = service.agentInstallURL(agent: "dsh")
        XCTAssertEqual(url.absoluteString, "https://github.com/deepseek-ai/deepseek-harness")
    }
    
    @MainActor
    func testIsAgentInstalledDoesNotCrashForClaudeCowork() {
        let service = SplashService()
        // No debe lanzar excepciones ni provocar cuelgues
        _ = service.isAgentInstalled(agent: "claude-cowork")
    }
    
    @MainActor
    func testIsAgentInstalledDoesNotCrashForChatGPT() {
        let service = SplashService()
        _ = service.isAgentInstalled(agent: "chatgpt")
    }
    
    @MainActor
    func testIsAgentInstalledDoesNotCrashForDeepSeekHarness() {
        let service = SplashService()
        _ = service.isAgentInstalled(agent: "dsh")
    }
    
    @MainActor
    func testIsAgentInstalledDetectsDeepSeekHarnessAppIfPresent() {
        let service = SplashService()
        if FileManager.default.fileExists(atPath: "/Applications/DeepSeek Harness.app") {
            XCTAssertTrue(service.isAgentInstalled(agent: "dsh"), "Debe detectar /Applications/DeepSeek Harness.app cuando está instalada")
        }
    }
}
