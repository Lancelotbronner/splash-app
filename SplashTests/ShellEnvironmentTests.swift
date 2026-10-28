import Foundation
import Testing
@testable import Splash

// MARK: - P-09 / H-09 (consentimiento) y P-13 (política única de entorno)

@MainActor
@Suite(.serialized)
final class ShellEnvironmentTests {

	/// El consentimiento del shell persiste en `@AppStorage`; se capturan los
	/// valores originales y se restauran al terminar cada test.
	private let originalConsent: Bool
	private let originalDeclined: Bool

	init() {
		originalConsent = Preferences.shellConfigConsent
		originalDeclined = Preferences.shellConfigDeclined
	}

	isolated deinit {
		Preferences.shellConfigConsent = originalConsent
		Preferences.shellConfigDeclined = originalDeclined
	}

	private enum Cases {
		struct PortCase: Sendable {
			let port: Int
			let expected: Bool
		}

		static let syncPorts: [PortCase] = [
			.init(port: 8000, expected: true),
			.init(port: 8005, expected: true),
			.init(port: 54321, expected: true),
			.init(port: 0, expected: false),
			.init(port: 70000, expected: false)
		]

		struct ConsentCase: Sendable {
			let hasConsent: Bool
			let userDeclined: Bool
			/// Etiqueta del resultado (`String(describing:)` del enum), para no
			/// almacenar un tipo aislado por `@MainActor` en la tabla de casos.
			let expected: String
		}

		static let consentDecisions: [ConsentCase] = [
			.init(hasConsent: true, userDeclined: false, expected: "write"),
			.init(hasConsent: true, userDeclined: true, expected: "write"),
			.init(hasConsent: false, userDeclined: false, expected: "askUser"),
			.init(hasConsent: false, userDeclined: true, expected: "skip")
		]
	}

	@Test func testEnvironmentFileContentsCarryTheActivePort() {
		let contents = ShellEnvironment.fileContents(port: 8005)
		#expect(contents.contains("export SPLASH_PORT=\"8005\""))
		#expect(contents.contains("export ANTHROPIC_BASE_URL=\"http://127.0.0.1:8005\""))
		#expect(contents.contains("export OPENAI_BASE_URL=\"http://127.0.0.1:8005/v1\""))
	}

	@Test func testInjectionIsIdempotent() {
		let block = ShellEnvironment.injectionBlock(envFilePath: "/Users/x/.splash_monitor_env")
		let initial = "export PATH=/usr/bin\n"
		#expect(ShellEnvironment.needsInjection(into: initial))
		let once = initial + block
		#expect(!ShellEnvironment.needsInjection(into: once))
		#expect(once.components(separatedBy: ShellEnvironment.blockHeader).count - 1 == 1,
				"El encabezado de la inyección debe aparecer una sola vez.")
		// Segunda pasada: `needsInjection` es falso, así que no se vuelve a añadir.
		#expect(once + (ShellEnvironment.needsInjection(into: once) ? block : "") == once)
	}

	/// La app escribía en `~/.zshrc` y no sabía deshacerlo. La reversión debe ser exacta.
	@Test func testRemovingInjectionRestoresOriginalFile() {
		let original = "export PATH=/usr/bin\nalias ll='ls -la'\n"
		let envPath = "/Users/x/.splash_monitor_env"
		let injected = original + ShellEnvironment.injectionBlock(envFilePath: envPath)
		#expect(injected != original)
		#expect(ShellEnvironment.removingInjection(from: injected) == original)
		// Idempotente: quitar dos veces no rompe el fichero.
		#expect(ShellEnvironment.removingInjection(from: original) == original)
	}

	/// P-13: una sola política. Antes, `startServer()` borraba el entorno en 8000
	/// mientras `checkServerStatus()` lo escribía también para 8000.
	@Test(arguments: Self.Cases.syncPorts)
	private func testSyncPolicyIsUniformAcrossPorts(_ c: Cases.PortCase) {
		#expect(ShellEnvironment.shouldSync(port: c.port) == c.expected,
				"shouldSync(port: \(c.port))")
	}

	@Test(arguments: Self.Cases.consentDecisions)
	private func testConsentDecisions(_ c: Cases.ConsentCase) {
		#expect(String(describing: ShellConsent.decide(hasConsent: c.hasConsent, userDeclined: c.userDeclined)) == c.expected,
				"decide(hasConsent: \(c.hasConsent), userDeclined: \(c.userDeclined))")
	}

	/// El servicio no toca el `~/.zshrc` real: escribe en el directorio inyectado y,
	/// sin consentimiento, deja el aviso pendiente en lugar de modificar el perfil.
	@Test func testServiceWithoutConsentOnlyWritesEnvironmentFileAndAsks() throws {
		let dir = try TempDirectory()
		let service = makeTestService(pollInterval: 30, directory: dir.url)
		Preferences.shellConfigConsent = false
		Preferences.shellConfigDeclined = false
		let writtenFiles = Box<[String]>([])
		service.shellWriteOverride = { _, url in writtenFiles.value.append(url.lastPathComponent) }

		service.syncShellEnvironment(port: 8005)

		#expect(dir.exists(ShellEnvironment.fileName))
		#expect(writtenFiles.value.isEmpty, "Sin consentimiento no se escribe en ~/.zshrc.")
		#expect(service.pendingShellConfigPort == 8005)

		// Con consentimiento: escribe el perfil y deja de preguntar.
		service.resolveShellConfigPrompt(allow: true)
		#expect(writtenFiles.value == [".zshrc"])
		#expect(service.pendingShellConfigPort == nil)
		#expect(Preferences.shellConfigConsent)
		#expect(!Preferences.shellConfigDeclined)

		// Deshacer: borra el fichero de entorno y revierte la inyección.
		service.clearShellEnvironment()
		#expect(!dir.exists(ShellEnvironment.fileName))
	}

	@Test func testSyncCodexEnvironmentUpdatesModelAndBaseURL() throws {
		let dir = try TempDirectory()
		let service = makeTestService(pollInterval: 30, directory: dir.url)

		let codexDir = dir.url.appendingPathComponent(".codex")
		try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
		let configURL = codexDir.appendingPathComponent("config.toml")

		let sampleConfig = """
		model = "incoai/Qwen3.6-35B-A3B-Splash"
		model_context_window = 65536
		openai_base_url = "http://127.0.0.1:8000/v1"
		"""
		try sampleConfig.write(to: configURL, atomically: true, encoding: .utf8)

		service.syncCodexEnvironment(model: "peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL", port: 8005)

		let updated = try String(contentsOf: configURL, encoding: .utf8)
		#expect(updated.contains("model = \"peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL\""))
		#expect(updated.contains("openai_base_url = \"http://127.0.0.1:8005/v1\""))
		#expect(updated.contains("model_context_window = 65536"))
	}
}

/// Cofre mutable para capturas de closures no aislados (Swift 6).
private final class Box<T>: @unchecked Sendable {
	var value: T
	init(_ value: T) { self.value = value }
}
