import Foundation
import Testing
@testable import Splash

@MainActor
@Suite(.serialized)
final class SystemMemoryPressureTests {

	private final class MockSentinelDelegate: SystemMemoryPressureSentinelDelegate, @unchecked Sendable {
		var lastLevel: SystemMemoryPressureLevel?

		func memoryPressureDidChange(to level: SystemMemoryPressureLevel) {
			self.lastLevel = level
		}
	}

	/// `SplashService.init` (y cualquier otra suite en paralelo) reasigna
	/// `SystemMemoryPressureSentinel.shared.delegate`; se captura el delegado
	/// original y se restaura al terminar cada test.
	private let previousDelegate: SystemMemoryPressureSentinelDelegate?

	init() {
		previousDelegate = SystemMemoryPressureSentinel.shared.delegate
	}

	isolated deinit {
		SystemMemoryPressureSentinel.shared.delegate = previousDelegate
	}

	/// `simulatePressureChange` despacha por `DispatchQueue.main.async`; en vez de
	/// dormir un tiempo fijo, se reasigna el delegado (por si otra suite lo robó)
	/// y se reenvía hasta que el delegado observe el nivel esperado.
	private func simulateAndAwait(sentinel: SystemMemoryPressureSentinel,
								  delegate: MockSentinelDelegate,
								  level: SystemMemoryPressureLevel) async {
		for _ in 0..<10 {
			sentinel.delegate = delegate
			sentinel.simulatePressureChange(to: level)
			try? await Task.sleep(for: .milliseconds(50))
			if delegate.lastLevel == level { return }
		}
	}

	@Test func testSentinelNotifiesDelegateOnSimulatedPressureChange() async {
		let sentinel = SystemMemoryPressureSentinel.shared
		let delegate = MockSentinelDelegate()

		await simulateAndAwait(sentinel: sentinel, delegate: delegate, level: .warning)
		#expect(sentinel.currentPressure == .warning)
		#expect(delegate.lastLevel == .warning)
		#expect(sentinel.lastWarningDate != nil)

		await simulateAndAwait(sentinel: sentinel, delegate: delegate, level: .critical)
		#expect(sentinel.currentPressure == .critical)
		#expect(delegate.lastLevel == .critical)
		#expect(sentinel.lastCriticalDate != nil)

		await simulateAndAwait(sentinel: sentinel, delegate: delegate, level: .normal)
		#expect(sentinel.currentPressure == .normal)
		#expect(delegate.lastLevel == .normal)
	}

	@Test func testSplashServiceUpdatesMemoryPressureFromSentinel() async throws {
		let dir = try TempDirectory()
		let service = makeTestService(pollInterval: 60, directory: dir.url)

		for _ in 0..<10 {
			SystemMemoryPressureSentinel.shared.delegate = service
			SystemMemoryPressureSentinel.shared.simulatePressureChange(to: .warning)
			try? await Task.sleep(for: .milliseconds(50))
			if service.systemMemoryPressure == .warning { break }
		}
		#expect(service.systemMemoryPressure == .warning)

		for _ in 0..<10 {
			SystemMemoryPressureSentinel.shared.delegate = service
			SystemMemoryPressureSentinel.shared.simulatePressureChange(to: .normal)
			try? await Task.sleep(for: .milliseconds(50))
			if service.systemMemoryPressure == .normal { break }
		}
		#expect(service.systemMemoryPressure == .normal)
	}

	@Test func testSplashServiceReleaseMemoryNowSetsNotice() async throws {
		let dir = try TempDirectory()
		let service = makeTestService(pollInterval: 60, directory: dir.url)

		service.isRunning = true
		// Puerto sin motor real: la llamada POST falla y el fallback seguro detiene el
		// servidor. No usar el puerto por defecto para no depender de un motor vivo.
		service.activePort = 58931
		service.releaseMemoryNow()

		// El fallback encadena varios hops de Task/MainActor (release → POST fallido →
		// stopServer → stopServerAsync); se espera la condición, no un tiempo fijo.
		try await waitFor(where: { service.memoryReliefNotice != nil && !service.isRunning },
						  timeout: .seconds(5),
						  message: "releaseMemoryNow debe dejar aviso y detener el servidor")
	}
}
