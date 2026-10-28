import Foundation
import Testing
@testable import Splash

@MainActor
@Suite
final class ModelDiagnosticTests {

	@Test func testSmokeTestItemsInitializedCorrectly() {
		let service = ModelDiagnosticService()
		#expect(service.smokeTestResults.count == 7)

		let ids = service.smokeTestResults.map { $0.id }
		#expect(ids.contains("health"))
		#expect(ids.contains("ready"))
		#expect(ids.contains("status"))
		#expect(ids.contains("template"))
		#expect(ids.contains("openai"))
		#expect(ids.contains("anthropic"))
		#expect(ids.contains("tools"))

		for item in service.smokeTestResults {
			#expect(item.status == .idle)
			#expect(!item.status.isPassed)
		}
	}

	@Test func testResetSmokeTestsResetsState() {
		let service = ModelDiagnosticService()
		service.smokeTestResults[0].status = .passed(details: "OK", latencyMs: 12.0)
		#expect(service.smokeTestResults[0].status.isPassed)

		service.resetSmokeTests()
		#expect(service.smokeTestResults[0].status == .idle)
		#expect(!service.smokeTestResults[0].status.isPassed)
	}

	@Test func testBenchmarkResultValues() {
		let bench = ModelDiagnosticService.BenchmarkResult(
			coldDecodeTokPerSec: 45.2,
			warmDecodeTokPerSec: 154.8,
			coldTTFTMs: 380.0,
			warmTTFTMs: 95.0,
			cacheSpeedupMultiplier: 4.0,
			promptTokens: 256,
			outputTokens: 128
		)

		#expect(abs(bench.coldDecodeTokPerSec - 45.2) < 0.01)
		#expect(abs(bench.warmDecodeTokPerSec - 154.8) < 0.01)
		#expect(abs(bench.cacheSpeedupMultiplier - 4.0) < 0.01)
		#expect(bench.promptTokens == 256)
		#expect(bench.outputTokens == 128)
	}

	@Test func testCheckStatusEquality() {
		let s1 = ModelDiagnosticService.CheckStatus.passed(details: "OK", latencyMs: 5.0)
		let s2 = ModelDiagnosticService.CheckStatus.passed(details: "OK", latencyMs: 5.0)
		let s3 = ModelDiagnosticService.CheckStatus.failed(error: "Fail")
		let s4 = ModelDiagnosticService.CheckStatus.idle

		#expect(s1 == s2)
		#expect(s1 != s3)
		#expect(s1 != s4)
		#expect(s1.isPassed)
		#expect(!s3.isPassed)
	}

	@Test func testSidebarItemIncludesModelTesting() {
		let allItems = SidebarItem.allCases
		#expect(allItems.contains(.modelTesting))

		let testingItem = SidebarItem.modelTesting
		// `title` es un `LocalizedStringResource` de un solo argumento: la traducción
		// (es, etc.) vive en el catálogo de strings, no en la API.
		#expect(testingItem.title == LocalizedStringResource("Model Testing"))
		#expect(testingItem.icon == "testtube.2")
	}
}
