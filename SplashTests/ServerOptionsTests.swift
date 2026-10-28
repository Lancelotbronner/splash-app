import Foundation
import Testing
@testable import Splash

@MainActor
@Suite(.serialized)
final class ServerOptionsTests {

	private let testPort = 58921
	private let dir: TempDirectory
	private let capturedCommand: Box<String?>
	private let service: SplashService

	/// El contenedor es `throws` en Swift Testing: un fallo aquí falla cada test.
	/// La closure captura un `Box` local (no `self`): se invoca desde un Task
	/// detached dentro de `startServer` y `self` es aislado por `@MainActor`.
	init() throws {
		dir = try TempDirectory()
		let box = Box<String?>(nil)
		capturedCommand = box
		service = makeTestService(pollInterval: 60, directory: dir.url)
		service.serverLaunchOverride = { cmd, _, _ in
			box.value = cmd
		}
	}

	/// `startServer` (y `restoreOptimalProfile`) mutan ~17 preferencias en
	/// `UserDefaults.standard`; se limpian al terminar cada test.
	isolated deinit {
		let keys = [
			"listenOnAllInterfaces", "maxContext", "allowedHosts", "allowedOrigins",
			"languageOnly", "customServerFlags", "idleRelease", "maxMemory",
			"stateFormat", "thinkingTokenBudget", "persistentCache", "lastUsedPort",
			"verifyRows", "expertMemory", "autoReleaseOnMemoryPressure",
			"refreshInterval", "runInBackground"
		]
		for key in keys { UserDefaults.standard.removeObject(forKey: key) }
	}

	private enum LaunchCases {
		struct Case: Sendable {
			let name: String
			let model: String
			let configure: @MainActor @Sendable () -> Void
			let expected: [String]
			let unexpected: [String]
		}

		static let all: [Case] = [
			Case(name: "default-localhost",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: {
					 Preferences.listenOnAllInterfaces = false
					 Preferences.maxContext = "auto"
				 },
				 expected: ["--host \"127.0.0.1\"", "Solo localhost"],
				 unexpected: ["--host \"0.0.0.0\"", "--max-context"]),
			Case(name: "all-interfaces",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: {
					 Preferences.listenOnAllInterfaces = true
					 Preferences.maxContext = "auto"
				 },
				 expected: ["--host \"0.0.0.0\"", "Toda la red local / LAN"],
				 unexpected: ["--host \"127.0.0.1\""]),
			Case(name: "custom-max-context",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: {
					 Preferences.listenOnAllInterfaces = false
					 Preferences.maxContext = "64K"
				 },
				 expected: ["--max-context \"64K\"", "🧠 Contexto: 64K"],
				 unexpected: []),
			Case(name: "malformed-context-sanitized",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: {
					 Preferences.listenOnAllInterfaces = false
					 Preferences.maxContext = "32K; rm -rf /"
				 },
				 expected: [],
				 unexpected: ["rm -rf", "--max-context"]),
			Case(name: "allowed-hosts",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: {
					 Preferences.listenOnAllInterfaces = true
					 Preferences.allowedHosts = "midominio.duckdns.org, mimac.local; test.com"
				 },
				 expected: ["--allowed-host \"midominio.duckdns.org\"",
							  "--allowed-host \"mimac.local\"",
							  "--allowed-host \"test.com\"",
							  "🛡️ Dominios:"],
				 unexpected: []),
			Case(name: "allowed-origins",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: { Preferences.allowedOrigins = "*" },
				 expected: ["--allowed-origin \"*\"", "🌍 Orígenes:"],
				 unexpected: []),
			Case(name: "model-aliases",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: { },
				 // Verifica que se inyectan los alias requeridos por la pestaña Code (Codex / CCD)
				 expected: ["--served-model-name \"claude-sonnet-4-6\"",
							  "--served-model-name \"claude-sonnet-5\"",
							  "--served-model-name \"claude-haiku-4-5-20251001\"",
							  "--served-model-name \"claude-3-7-sonnet-20250219\"",
							  "--served-model-name \"claude-sonnet-4-5\"",
							  // Verifica alias para ChatGPT / OpenAI y Codex
							  "--served-model-name \"gpt-4o\"",
							  "--served-model-name \"codex\""],
				 unexpected: []),
			Case(name: "custom-flags",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: { Preferences.customServerFlags = "--no-webui --max-cache-disk 50GB" },
				 expected: ["--no-webui",
							  "--max-cache-disk 50GB",
							  "🛠️ Flags CLI:  --no-webui --max-cache-disk 50GB"],
				 unexpected: []),
			Case(name: "malicious-flags-sanitized",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: { Preferences.customServerFlags = "--no-webui ; rm -rf /" },
				 expected: [],
				 unexpected: ["rm -rf", "--no-webui"]),
			Case(name: "idle-release-and-max-memory",
				 model: "incoai/Qwen3.6-35B-A3B-Splash",
				 configure: {
					 Preferences.idleRelease = "2m"
					 Preferences.maxMemory = "24G"
				 },
				 expected: ["--idle-release \"2m\"",
							  "--max-memory \"24G\"",
							  "⏳ Inactividad: 2m",
							  "💾 Límite RAM: 24G"],
				 unexpected: []),
			Case(name: "splash-132-features",
				 model: "nvidia/Qwen3.8-27B-NVFP4",
				 configure: {
					 Preferences.stateFormat = "bf16"
					 Preferences.thinkingTokenBudget = "8K"
					 Preferences.persistentCache = true
				 },
				 expected: ["--state-format \"bf16\"",
							  "--thinking-token-budget \"8000\"",
							  "--persistent-cache",
							  "⚡️ Estado GDN: BF16 (-50% RAM)",
							  "💭 Thinking:  8K",
							  "💾 Caché SSD:  Persistente activada"],
				 unexpected: []),
			Case(name: "splash-140-features",
				 model: "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:Q2_0",
				 configure: {
					 Preferences.maxContext = "1M"
					 Preferences.verifyRows = "all"
					 Preferences.expertMemory = "12G"
				 },
				 expected: ["--max-context \"1M\"",
							  "--verify-rows \"all\"",
							  "--expert-memory \"12g\"",
							  "🎯 Verificación: Todas las filas (--verify-rows all)",
							  "🧠 Memoria Expertos MoE: 12g"],
				 unexpected: [])
		]
	}

	/// Espera el comando capturado por `serverLaunchOverride` (condición, no sleep).
	private func waitForCapturedCommand(attempts: Int = 150) async throws -> String {
		for _ in 0..<attempts {
			if let val = capturedCommand.value { return val }
			try await Task.sleep(for: .milliseconds(20))
		}
		return try #require(capturedCommand.value, "No command was captured in serverLaunchOverride")
	}

	@Test(arguments: Self.LaunchCases.all)
	private func testServerLaunchInjectsRequestedOptions(_ c: LaunchCases.Case) async throws {
		await c.configure()
		capturedCommand.value = nil
		service.startServer(model: c.model, port: testPort)
		let cmd = try await waitForCapturedCommand()
		for token in c.expected {
			#expect(cmd.contains(token), "Faltaba '\(token)' en: \(cmd)")
		}
		for token in c.unexpected {
			#expect(!cmd.contains(token), "Sobró '\(token)' en: \(cmd)")
		}
	}

	@Test func testPreferredHostOrIPReflectsListenOnAllInterfaces() {
		Preferences.allowedHosts = ""
		Preferences.listenOnAllInterfaces = false
		#expect(service.preferredHostOrIP == "127.0.0.1")

		Preferences.listenOnAllInterfaces = true
		if let ip = service.localNetworkIP {
			#expect(service.preferredHostOrIP == ip)
		} else {
			#expect(service.preferredHostOrIP == "127.0.0.1")
		}

		Preferences.allowedHosts = "midominio.duckdns.org"
		#expect(service.preferredHostOrIP == "midominio.duckdns.org")
	}

	@Test func testLanClientAppCategoryProperties() {
		let app = ConnectedApp(
			pid: 91234,
			name: "Cliente LAN (192.168.1.120)",
			category: .lanClient,
			connectionCount: 2,
			remoteAddress: "192.168.1.120:54321"
		)
		#expect(app.category == .lanClient)
		#expect(app.category.iconName == "network")
		// `localizedName` es un `LocalizedStringResource` de un solo argumento: la
		// traducción (es, etc.) vive en el catálogo de strings, no en la API.
		#expect(app.category.localizedName == LocalizedStringResource("Remote Client / LAN Network"))
	}

	@Test func testServerLaunchInjectsLanguageOnlyFlag() async throws {
		// Sin flag activo
		Preferences.languageOnly = false
		capturedCommand.value = nil
		service.startServer(model: "incoai/Qwen3.6-35B-A3B-Splash", port: testPort)
		let cmdNormal = try await waitForCapturedCommand()
		#expect(!cmdNormal.contains("--language-only"), "No debe inyectar --language-only si está desactivado")
		#expect(cmdNormal.contains("👁️ Modalidad: Multimodal (Texto y Visión)"))

		// Con flag activo
		Preferences.languageOnly = true
		capturedCommand.value = nil
		service.startServer(model: "incoai/Qwen3.6-35B-A3B-Splash", port: testPort)
		let cmdLangOnly = try await waitForCapturedCommand()
		#expect(cmdLangOnly.contains("--language-only"), "Debe inyectar --language-only cuando está activado: \(cmdLangOnly)")
		#expect(cmdLangOnly.contains("👁️ Modalidad: Solo Texto / Código (--language-only)"))
	}

	@Test func testServerLaunchWithModelVariant() async throws {
		// Modelo con variante GGUF (peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL)
		let variantModel = "peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL"
		capturedCommand.value = nil
		service.startServer(model: variantModel, port: testPort)
		let cmd = try await waitForCapturedCommand()

		#expect(cmd.contains("--model \"\(variantModel)\""), "Debe interpolar el modelo completo con su variante: \(cmd)")
		#expect(cmd.contains("📦 Modelo:   \(variantModel)"), "El banner debe incluir la variante: \(cmd)")
		#expect(service.lastError == nil, "No debe registrar error de validación para un modelo con variante")
	}

	@Test func testRestoreOptimalProfileSetsAllParametersAndPersistsToUserDefaults() {
		// Mutar a valores distintos para comprobar la restauración
		Preferences.stateFormat = "fp32"
		Preferences.thinkingTokenBudget = "auto"
		Preferences.persistentCache = false
		Preferences.maxContext = "16K"
		Preferences.idleRelease = "1m"
		Preferences.languageOnly = false
		Preferences.maxMemory = "16G"
		Preferences.lastUsedPort = 9999
		Preferences.listenOnAllInterfaces = false
		Preferences.allowedHosts = "otro.dominio.org"
		Preferences.allowedOrigins = "http://localhost:3000"
		Preferences.autoReleaseOnMemoryPressure = false
		Preferences.refreshInterval = 4.0
		Preferences.runInBackground = false

		service.restoreOptimalProfile()

		// Validar propiedades en SplashService
		#expect(Preferences.stateFormat == "bf16")
		#expect(Preferences.thinkingTokenBudget == "8K")
		#expect(Preferences.persistentCache)
		#expect(Preferences.maxContext == "128K")
		#expect(Preferences.idleRelease == "off")
		#expect(Preferences.languageOnly)
		#expect(Preferences.maxMemory == "auto")
		#expect(Preferences.verifyRows == "auto")
		#expect(Preferences.expertMemory == "auto")
		#expect(Preferences.lastUsedPort == 8005)
		#expect(Preferences.listenOnAllInterfaces)
		#expect(Preferences.allowedHosts == "jmgrepdevsrl.duckdns.org")
		#expect(Preferences.allowedOrigins == "*")
		#expect(Preferences.autoReleaseOnMemoryPressure)
		#expect(Preferences.refreshInterval == 1.5)
		#expect(Preferences.runInBackground)

		// Validar persistencia en UserDefaults
		let defaults = UserDefaults.standard
		#expect(defaults.string(forKey: "stateFormat") == "bf16")
		#expect(defaults.string(forKey: "thinkingTokenBudget") == "8K")
		#expect(defaults.bool(forKey: "persistentCache"))
		#expect(defaults.string(forKey: "maxContext") == "128K")
		#expect(defaults.string(forKey: "idleRelease") == "off")
		#expect(defaults.bool(forKey: "languageOnly"))
		#expect(defaults.string(forKey: "maxMemory") == "auto")
		#expect(defaults.string(forKey: "verifyRows") == "auto")
		#expect(defaults.string(forKey: "expertMemory") == "auto")
		#expect(defaults.integer(forKey: "lastUsedPort") == 8005)
		#expect(defaults.bool(forKey: "listenOnAllInterfaces"))
		#expect(defaults.string(forKey: "allowedHosts") == "jmgrepdevsrl.duckdns.org")
		#expect(defaults.string(forKey: "allowedOrigins") == "*")
		#expect(defaults.bool(forKey: "showMenuBarIcon"))
		#expect(defaults.bool(forKey: "autoReleaseOnMemoryPressure"))
		#expect(defaults.double(forKey: "refreshInterval") == 1.5)
		#expect(defaults.bool(forKey: "runInBackground"))
	}
}

/// Helper para capturar valores dentro de closures concurrentes en tests
private final class Box<T>: @unchecked Sendable {
	var value: T
	init(_ value: T) { self.value = value }
}
