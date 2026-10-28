import Foundation
import Testing
@testable import Splash

// MARK: - P-08 / H-07: ficheros de bloqueo del motor

@MainActor
@Suite
final class ServeLockTests {

	@Test func testCandidateNamesPreferPortSpecificLock() {
		#expect(ServeLockStore.candidateFileNames(port: 8005) == ["serve-8005.lock", "serve.lock"])
		#expect(ServeLockStore.candidateFileNames(port: 8008).first == "serve-8008.lock")
	}

	/// El motor 1.0.2 deja `serve.lock` con 0 bytes: debía devolver `nil`, no fallar.
	@Test func testEmptyOrCorruptLockDecodesToNil() {
		#expect(ServeLockStore.decode(Data()) == nil)
		#expect(ServeLockStore.decode(Data("no es json".utf8)) == nil)
		#expect(ServeLockStore.decode(nil) == nil)
		let lock = ServeLockStore.decode(Fixtures.lockData(pid: 1234, port: 8005))
		#expect(lock?.pid == 1234)
		#expect(lock?.port == 8005)
	}

	@Test func testLockIsUsableOnlyWithLiveMatchingPID() {
		let lock = ServeLockStore.decode(Fixtures.lockData(pid: 1234, port: 8005))
		#expect(ServeLockStore.isUsable(lock, port: 8005, pidAlive: { $0 == 1234 }))
		// PID muerto
		#expect(!ServeLockStore.isUsable(lock, port: 8005, pidAlive: { _ in false }))
		// Bloqueo de otro puerto (serve-8008.lock con un motor en 8005)
		#expect(!ServeLockStore.isUsable(lock, port: 8008, pidAlive: { _ in true }))
		#expect(!ServeLockStore.isUsable(nil, port: 8005, pidAlive: { _ in true }))
	}

	/// Caso real medido en el equipo auditado: `serve-8008.lock` con un PID ya muerto
	/// que nadie limpiaba y que hacía creer a la app que había un motor en 8008.
	@Test func testDeadOldLockIsStale() {
		let lock = ServeLockStore.decode(Fixtures.lockData(pid: 99999, port: 8008))
		#expect(ServeLockStore.isStale(lock, pidAlive: false, age: 86_400))
		#expect(ServeLockStore.isStale(nil, pidAlive: false, age: 86_400))
	}

	/// Margen de arranque: un motor recién lanzado puede tardar; su bloqueo se respeta.
	@Test func testFreshLockOfStartingEngineIsNotStale() {
		let lock = ServeLockStore.decode(Fixtures.lockData(pid: 99999, port: 8008))
		#expect(!ServeLockStore.isStale(lock, pidAlive: false, age: 5))
		#expect(!ServeLockStore.isStale(lock, pidAlive: true, age: 86_400))
	}
}
