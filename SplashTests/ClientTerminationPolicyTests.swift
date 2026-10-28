import Foundation
import Testing
@testable import Splash

// MARK: - P-04 / H-05: política de terminación de clientes

@MainActor
@Suite
final class ClientTerminationPolicyTests {

	private enum Cases {
		struct Case: Sendable {
			let note: String
			let pid: Int32
			let recordedBundleID: String?
			let currentBundleID: String?
			let currentName: String?
			let isRunning: Bool
			let ownBundleID: String?
			let expected: Bool
		}

		static let all: [Case] = [
			.init(note: "Aplicación en ejecución con bundle coincidente",
				  pid: 12345,
				  recordedBundleID: "com.anthropic.claudefordesktop",
				  currentBundleID: "com.anthropic.claudefordesktop",
				  currentName: "Claude",
				  isRunning: true,
				  ownBundleID: "com.incoai.splashmonitor",
				  expected: true),
			// PID reciclado: el proceso registrado ya no es la misma aplicación.
			.init(note: "PID reciclado: el proceso registrado ya no es la misma aplicación",
				  pid: 12345,
				  recordedBundleID: "com.anthropic.claudefordesktop",
				  currentBundleID: "com.apple.finder",
				  currentName: "Finder",
				  isRunning: true,
				  ownBundleID: "com.incoai.splashmonitor",
				  expected: false),
			.init(note: "Nunca se termina al propio monitor",
				  pid: 4242,
				  recordedBundleID: "com.incoai.splashmonitor",
				  currentBundleID: "com.incoai.splashmonitor",
				  currentName: "Splash Monitor",
				  isRunning: true,
				  ownBundleID: "com.incoai.splashmonitor",
				  expected: false),
			.init(note: "El proceso ya no existe",
				  pid: 12345,
				  recordedBundleID: "com.anthropic.claudefordesktop",
				  currentBundleID: nil,
				  currentName: nil,
				  isRunning: false,
				  ownBundleID: "com.incoai.splashmonitor",
				  expected: false),
			.init(note: "PID 0 nunca se termina",
				  pid: 0,
				  recordedBundleID: "com.x",
				  currentBundleID: "com.x",
				  currentName: "X",
				  isRunning: true,
				  ownBundleID: nil,
				  expected: false),
			// Sin bundle identificado (script suelto) solo se admite si el nombre sigue vivo.
			.init(note: "Script suelto: el nombre sigue vivo",
				  pid: 777,
				  recordedBundleID: nil,
				  currentBundleID: nil,
				  currentName: "python3",
				  isRunning: true,
				  ownBundleID: "com.incoai.splashmonitor",
				  expected: true),
			.init(note: "Script suelto sin nombre: se rechaza",
				  pid: 777,
				  recordedBundleID: nil,
				  currentBundleID: nil,
				  currentName: nil,
				  isRunning: true,
				  ownBundleID: "com.incoai.splashmonitor",
				  expected: false)
		]
	}

	@Test(arguments: Self.Cases.all)
	private func testCanTerminatePolicy(_ c: Cases.Case) {
		#expect(ClientTerminationPolicy.canTerminate(
			pid: c.pid,
			recordedBundleID: c.recordedBundleID,
			currentBundleID: c.currentBundleID,
			currentName: c.currentName,
			isRunning: c.isRunning,
			ownBundleID: c.ownBundleID
		) == c.expected, "\(c.note)")
	}
}
