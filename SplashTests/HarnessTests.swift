import Foundation
import Testing
@testable import Splash

/// F0.1 — El objetivo de pruebas puede importar el módulo del ejecutable.
/// Confirma que no hace falta extraer un target de librería para probar la app.
@MainActor
@Suite
final class HarnessTests {
	@Test func testTestTargetCanImportExecutableModuleAndDecodeFixture() {
		let status: SplashStatus = Fixtures.status(port: 8005)
		#expect(status.ready == true)
		#expect(status.instance?.model == "incoai/Qwen3.8-27B-Splash")
		#expect(status.instance?.port == 8005)
	}
}
