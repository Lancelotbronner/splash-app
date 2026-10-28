import Foundation
import Testing
@testable import Splash

@MainActor
@Suite(.serialized)
final class NotificationAndAutoLaunchTests {

	/// `isNotificationsEnabled` persiste en `UserDefaults.standard`; se captura el
	/// estado original y se restaura al terminar cada test.
	private let originalNotificationsEnabled: Bool

	init() {
		originalNotificationsEnabled = NotificationService.shared.isNotificationsEnabled
	}

	isolated deinit {
		NotificationService.shared.isNotificationsEnabled = originalNotificationsEnabled
	}

	@Test func testNotificationServiceToggleAndPersistence() {
		let service = NotificationService.shared

		service.isNotificationsEnabled = false
		#expect(!service.isNotificationsEnabled)
		#expect(!UserDefaults.standard.bool(forKey: "systemNotificationsEnabled"))

		service.isNotificationsEnabled = true
		#expect(service.isNotificationsEnabled)
		#expect(UserDefaults.standard.bool(forKey: "systemNotificationsEnabled"))
		// El `deinit` de la suite restaura el valor original.
	}

	@Test func testNotificationServiceCallsAreSafeInTestEnvironment() {
		let service = NotificationService.shared
		let stateBefore = service.isNotificationsEnabled

		// Debe ejecutarse sin lanzar excepciones ni fallar aunque no haya bundle app activo en pruebas
		service.notifyServerStarted(model: "incoai/Qwen3.6-35B-A3B-Splash", port: 8005)
		service.notifyServerStopped(reason: "Test exit", isUnexpected: true)
		service.notifyServerStopped(reason: "Clean stop", isUnexpected: false)
		service.notifyMemoryPressureCritical()

		#expect(service.isNotificationsEnabled == stateBefore,
				"Las llamadas a NotificationService no deben mutar su estado de habilitación")
	}

	@Test func testAutoLaunchServiceInitializationAndStatusCheck() {
		let service = AutoLaunchService.shared

		// Verifica que la consulta a SMAppService no lance excepciones
		service.refreshStatus()
		let firstRead = service.isEnabled
		_ = service.lastError

		// Segunda lectura: la introspección debe ser repetible y estable.
		service.refreshStatus()
		#expect(service.isEnabled == firstRead,
				"AutoLaunchService debe instanciarse e introspeccionar el estado sin errores ni deriva")
		#expect(service.lastError.map { !$0.isEmpty } ?? true)
	}
}
