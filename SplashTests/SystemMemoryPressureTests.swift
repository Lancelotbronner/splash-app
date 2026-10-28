import XCTest
@testable import Splash

@MainActor
final class SystemMemoryPressureTests: XCTestCase {

	private final class MockSentinelDelegate: SystemMemoryPressureSentinelDelegate, @unchecked Sendable {
		var lastLevel: SystemMemoryPressureLevel?

		func memoryPressureDidChange(to level: SystemMemoryPressureLevel) {
			self.lastLevel = level
		}
	}

	func testSentinelNotifiesDelegateOnSimulatedPressureChange() async {
		let sentinel = SystemMemoryPressureSentinel.shared
		let delegate = MockSentinelDelegate()
		sentinel.delegate = delegate

		sentinel.simulatePressureChange(to: .warning)

		try? await Task.sleep(nanoseconds: 50_000_000)
		XCTAssertEqual(sentinel.currentPressure, .warning)
		XCTAssertEqual(delegate.lastLevel, .warning)
		XCTAssertNotNil(sentinel.lastWarningDate)

		sentinel.simulatePressureChange(to: .critical)
		try? await Task.sleep(nanoseconds: 50_000_000)
		XCTAssertEqual(sentinel.currentPressure, .critical)
		XCTAssertEqual(delegate.lastLevel, .critical)
		XCTAssertNotNil(sentinel.lastCriticalDate)

		sentinel.simulatePressureChange(to: .normal)
		try? await Task.sleep(nanoseconds: 50_000_000)
		XCTAssertEqual(sentinel.currentPressure, .normal)
		XCTAssertEqual(delegate.lastLevel, .normal)
	}

	func testSplashServiceUpdatesMemoryPressureFromSentinel() async throws {
		let dir = try TempDirectory()
		let service = SplashService(transport: StubStatusTransport(),
									terminator: RecordingServerTerminator(),
									pollInterval: 60,
									dataDirectoryRoot: dir.url,
									bootstrapNetwork: false)

		SystemMemoryPressureSentinel.shared.simulatePressureChange(to: .warning)
		try? await Task.sleep(nanoseconds: 50_000_000)

		XCTAssertEqual(service.systemMemoryPressure, .warning)

		SystemMemoryPressureSentinel.shared.simulatePressureChange(to: .normal)
		try? await Task.sleep(nanoseconds: 50_000_000)
		XCTAssertEqual(service.systemMemoryPressure, .normal)
	}

	func testSplashServiceReleaseMemoryNowSetsNotice() async throws {
		let dir = try TempDirectory()
		let service = SplashService(transport: StubStatusTransport(),
									terminator: RecordingServerTerminator(),
									pollInterval: 60,
									dataDirectoryRoot: dir.url,
									bootstrapNetwork: false)

		service.isRunning = true
		service.releaseMemoryNow()

		try? await Task.sleep(nanoseconds: 50_000_000)
		XCTAssertNotNil(service.memoryReliefNotice)
		XCTAssertFalse(service.isRunning)
	}
}
