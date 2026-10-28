import Foundation
import Testing
@testable import Splash

// MARK: - Sonda V-4: contrato real de `/status` frente al modelo Swift

@MainActor
@Suite
final class StatusModelTests {

	/// La fixture replica la carga útil real del motor 1.0.2 (30 claves observadas) más
	/// una clave desconocida. El modelo debe decodificar e ignorar lo que no conoce.
	@Test func testDecodesRealStatusPayloadAndToleratesUnknownKeys() throws {
		let status = try #require(Fixtures.status(port: 8005))
		#expect(try #require(status.ready))
		#expect(status.maximumContextTokens == 262_144)
		#expect(status.memoryPressure == "nominal")
		#expect(status.thermalState == "nominal")
		#expect(status.aneFfn?.state == "active")
		#expect(status.aneFfn?.share == 0.6667)
		#expect(status.aneFfn?.minPromptChunk == 128)
		#expect(status.weights?.released == false)
		#expect(status.weights?.idleReleaseSeconds == 300.0)
		#expect(status.instance?.pid == 4242)
		#expect(status.instance?.host == "127.0.0.1")
		#expect(status.instance?.port == 8005)
		#expect(status.instance?.startedAt == 1_758_700_000.0)
	}

	@Test func testEveryModelledFieldIsPopulatedByTheRealPayload() throws {
		let status = try #require(Fixtures.status(port: 8005))
		// Sonda V-4: las 11 claves modeladas existen todas en la carga útil real.
		#expect(status.memoryPlan?.device?.physicalMemoryBytes != nil)
		#expect(status.memoryPlan?.device?.recommendedMaxWorkingSetBytes != nil)
		#expect(status.memoryPlan?.model?.maximumContextTokens != nil)
		#expect(status.memoryPlan?.budget?.hardBudgetBytes != nil)
		#expect(status.memoryActual?.currentBytes != nil)
		#expect(status.memoryActual?.peakBytes != nil)
		#expect(status.memoryGovernor?.limitBytes != nil)
		#expect(status.memoryGovernor?.systemPressure != nil)
		#expect(status.cache?.hitRate != nil)
		#expect(status.cache?.reusedTokens != nil)
		#expect(status.scheduler?.decoding != nil)
		#expect(status.requests?.completed != nil)
		#expect(status.metrics?.decodeTokensPerSecond != nil)
		#expect(status.metrics?.ttftMs?.p50 != nil)
	}

	/// Valores medidos en la auditoría: prefill 763 tok/s, decodificación 42,5 tok/s.
	@Test func testMetricValuesMatchTheAuditedPayload() throws {
		let metrics = try #require(try #require(Fixtures.status(port: 8005)).metrics)
		#expect(abs(try #require(metrics.prefillTokensPerSecond) - 763.5) < 0.001)
		#expect(abs(try #require(metrics.decodeTokensPerSecond) - 42.5) < 0.001)
		#expect(abs(try #require(metrics.draftAcceptanceRate) - 0.8) < 0.001)
		#expect(metrics.decodeOutputTokens == 2048)
	}

	@Test func testMissingOptionalSectionsDecodeToNil() throws {
		let minimal = Data(#"{ "ready": false }"#.utf8)
		let status = try JSONDecoder().decode(SplashStatus.self, from: minimal)
		#expect(status.ready == false)
		#expect(status.instance == nil)
		#expect(status.metrics == nil)
		#expect(status.cache == nil)
	}

	/// Formateadores del servicio sobre la carga útil auditada.
	@Test func testFormattedMetricsFromAuditedPayload() throws {
		let dir = try TempDirectory()
		let service = makeTestService(pollInterval: 30, directory: dir.url)
		service.status = try #require(Fixtures.status(port: 8005))
		#expect(service.formattedDecodeSpeed == "42.5")
		#expect(service.formattedPrefillSpeed == "763.5")
		#expect(service.formattedCacheHitRate == "93.3%")
		#expect(service.formattedTokensDecode == "2.0K")
		#expect(service.formattedMemoryUsed == "2.5 GB")
		#expect(service.formattedMemoryLimit == "26.0 GB")
		#expect(abs(service.memoryUsageRatio - 0.0963) < 0.001)
	}
}
