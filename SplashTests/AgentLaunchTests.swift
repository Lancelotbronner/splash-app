import Foundation
import Testing
@testable import Splash

@MainActor
@Suite
final class AgentLaunchTests {

	private enum Cases {
		struct InstallURLCase: Sendable {
			let agent: String
			let expectedURL: String
		}

		static let installURLs: [InstallURLCase] = [
			.init(agent: "claude-cowork", expectedURL: "https://claude.ai/download"),
			.init(agent: "pi", expectedURL: "https://pi.dev/"),
			.init(agent: "chatgpt", expectedURL: "https://openai.com/chatgpt/download/"),
			.init(agent: "dsh", expectedURL: "https://github.com/deepseek-ai/deepseek-harness")
		]
	}

	@Test func testSupportedAgentsIncludesClaudeCowork() {
		#expect(SplashService.supportedAgents.contains("claude-cowork"), "supportedAgents debe incluir 'claude-cowork'")
		#expect(SplashService.supportedAgents.contains("claude"))
		#expect(SplashService.supportedAgents.contains("opencode"))
		#expect(SplashService.supportedAgents.contains("codex"))
		#expect(SplashService.supportedAgents.contains("hermes"))
		#expect(SplashService.supportedAgents.contains("chatgpt"), "supportedAgents debe incluir 'chatgpt'")
		#expect(SplashService.supportedAgents.contains("pi"), "supportedAgents debe incluir 'pi' (Splash 1.3.1)")
		#expect(SplashService.supportedAgents.contains("dsh"), "supportedAgents debe incluir 'dsh' (DeepSeek Harness)")
	}

	@Test(arguments: Self.Cases.installURLs)
	private func testAgentInstallURL(_ c: Cases.InstallURLCase) throws {
		let dir = try TempDirectory()
		let service = makeTestService(pollInterval: 60, directory: dir.url)
		let url = service.agentInstallURL(agent: c.agent)
		#expect(url.absoluteString == c.expectedURL, "URL de instalación para \(c.agent)")
	}

	/// Humo explícito: la detección de agentes debe ser estable y sin cuelgues.
	/// (Los tres tests `testIsAgentInstalledDoesNotCrashFor*` de la suite anterior
	/// no contenían ninguna aserción; aquí se comprueba al menos la estabilidad
	/// de dos lecturas consecutivas del mismo agente.)
	@Test(arguments: ["claude-cowork", "chatgpt", "dsh"])
	func testIsAgentInstalledDoesNotCrashFor(_ agent: String) throws {
		let dir = try TempDirectory()
		let service = makeTestService(pollInterval: 60, directory: dir.url)
		let first = service.isAgentInstalled(agent: agent)
		#expect(first == service.isAgentInstalled(agent: agent),
				"El resultado de isAgentInstalled debe ser estable para \(agent)")
	}

	/// §3.5: `isAgentInstalled` ahora lee solo el cache `installedAgents`
	/// (antes hacía 20–40 `stat` síncronos por llamada), por lo que la
	/// detección hay que desencadenarla con `refreshAgentAvailability()`.
	@Test(.enabled(if: FileManager.default.fileExists(atPath: "/Applications/DeepSeek Harness.app")))
	func testIsAgentInstalledDetectsDeepSeekHarnessApp() async throws {
		let dir = try TempDirectory()
		let service = makeTestService(pollInterval: 60, directory: dir.url)
		service.refreshAgentAvailability()
		try await waitFor(where: { service.isAgentInstalled(agent: "dsh") },
						  message: "Debe detectar /Applications/DeepSeek Harness.app tras refrescar el cache")
	}
}
