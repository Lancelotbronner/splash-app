import Foundation
import Testing
@testable import Splash

// MARK: - P-01 / H-02 y H-04: a quién es lícito señalizar

@MainActor
@Suite
final class ProcessIntrospectionTests {

	private enum Cases {
		struct ListeningCase: Sendable {
			let output: String
			let expected: [Int32]
		}

		static let listening: [ListeningCase] = [
			.init(output: "50528\n50529\n", expected: [50528, 50529]),
			.init(output: "50529\n", expected: [50529]),
			.init(output: "", expected: []),
			.init(output: "   \n", expected: []),
			.init(output: "abc\n-3\n0\n", expected: [])
		]

		struct IdentityCase: Sendable {
			let command: String
			let isEngine: Bool
		}

		static let identity: [IdentityCase] = [
			.init(command: "/opt/homebrew/bin/splash serve --model incoai/x", isEngine: true),
			.init(command: "/opt/homebrew/Cellar/splash/1.0.2/libexec/engine/splash serve-native", isEngine: true),
			.init(command: "/opt/homebrew/opt/splash/libexec/server/server.py", isEngine: true),
			.init(command: "/usr/bin/python3 -m uvicorn backend:app", isEngine: false),
			.init(command: "/Applications/Visual Studio Code.app/Contents/MacOS/Electron", isEngine: false),
			.init(command: "", isEngine: false)
		]
	}

	/// Salida real de `lsof -tiTCP:18097 -sTCP:LISTEN` (solo el servidor).
	private let listenerOutput = "50529\n"
	/// Salida real de `lsof -ti :18097` (servidor **y** cliente conectado).
	private let listenerAndClientOutput = "50528\n50529\n"

	@Test(arguments: Self.Cases.listening)
	private func testParsesListeningPIDs(_ c: Cases.ListeningCase) {
		#expect(ListerOutput.listeningPIDs(c.output) == c.expected, "listeningPIDs(\(c.output))")
	}

	/// La regresión clave: el cliente conectado (PID 50528) nunca debe ser objetivo.
	/// Con la lógica antigua (`lsof -ti :puerto` + `SIGKILL` a todo) sí lo era.
	@Test func testResolverOnlyTargetsListeningEngineProcesses() {
		let commands: [Int32: String] = [
			50528: "/usr/bin/ssh -N -L 18097:127.0.0.1:18097 host",
			50529: "/opt/homebrew/opt/splash/libexec/python/bin/python3 /opt/homebrew/opt/splash/libexec/server/server.py --port 18097"
		]
		let targets = KillTargetResolver.enginePIDsToStop(lsofOutput: listenerOutput) { commands[$0] }
		#expect(targets == [50529])

		// Si por error se pasaran las dos entradas de `lsof -ti :puerto`, el resolver
		// sigue descartando al cliente por identidad, no por puerto.
		let guarded = KillTargetResolver.enginePIDsToStop(lsofOutput: listenerAndClientOutput) { commands[$0] }
		#expect(guarded == [50529])
	}

	@Test func testUnknownProcessIsNotTargeted() {
		let targets = KillTargetResolver.enginePIDsToStop(lsofOutput: listenerOutput) { pid in
			pid == 50529 ? "/usr/local/bin/uvicorn backend:app --port 8000" : nil
		}
		#expect(targets.isEmpty)
		#expect(KillTargetResolver.enginePIDsToStop(lsofOutput: listenerOutput) { _ in nil }.isEmpty)
		#expect(KillTargetResolver.enginePIDsToStop(lsofOutput: listenerOutput) { _ in "" }.isEmpty)
	}

	@Test(arguments: Self.Cases.identity)
	private func testEngineIdentityRecognisesInstalledLayouts(_ c: Cases.IdentityCase) {
		#expect(SplashEngineIdentity.isEngineCommand(c.command) == c.isEngine, "isEngineCommand(\(c.command))")
	}

	/// Escalada declarada: nunca se empieza por `SIGKILL`.
	@Test func testSignalEscalationStartsCourteous() {
		#expect(KillTargetResolver.escalation.first == .interrupt)
		#expect(KillTargetResolver.escalation.last == .forceKill)
		#expect(KillTargetResolver.escalation.count == 3)
	}

	@Test func testParsesEstablishedConnections() {
		let output = """
		COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
		claude    12345 hometrix   23u  IPv4 0x8f2b1c4d5e6f7a8b      0t0  TCP 127.0.0.1:61012->127.0.0.1:18097 (ESTABLISHED)
		Code\\x20H 23456 hometrix   44u  IPv4 0x1a2b3c4d5e6f7a8c      0t0  TCP 127.0.0.1:61028->127.0.0.1:18097 (ESTABLISHED)
		python3   50529 hometrix   18u  IPv4 0x2b3c4d5e6f7a8b9c      0t0  TCP 127.0.0.1:18097->127.0.0.1:61012 (ESTABLISHED)
		"""
		let connections = ListerOutput.establishedConnections(output)
		#expect(connections.count == 3)
		#expect(connections.first?.pid == 12345)
		#expect(connections.first?.command == "claude")
		#expect(connections.first?.remoteAddress == "127.0.0.1:61012->127.0.0.1:18097")
	}

	@Test func testEstablishedParserIgnoresHeaderAndMalformedRows() {
		#expect(ListerOutput.establishedConnections("").isEmpty)
		#expect(ListerOutput.establishedConnections("COMMAND PID USER").isEmpty)
		#expect(ListerOutput.establishedConnections("claude abc hometrix 1u IPv4 0x1 0t0 TCP x->y").isEmpty)
	}
}
