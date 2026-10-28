import Foundation
import ServiceManagement

/// Servicio para gestionar el arranque automático de Splash Monitor al iniciar sesión en macOS.
/// Utiliza `SMAppService.mainApp` nativo disponible en macOS 13+.
@MainActor @Observable
final class AutoLaunchService {
	static let shared = AutoLaunchService()

	private(set) var isEnabled: Bool = false
	private(set) var lastError: String?

	init() {
		refreshStatus()
	}

	/// Actualiza el estado actual consultando a macOS.
	func refreshStatus() {
		isEnabled = (SMAppService.mainApp.status == .enabled)
	}

	/// Activa o desactiva el inicio al arrancar el Mac.
	@discardableResult
	func setEnabled(_ enable: Bool) -> Bool {
		do {
			if enable {
				try SMAppService.mainApp.register()
			} else {
				try SMAppService.mainApp.unregister()
			}
			self.lastError = nil
			refreshStatus()
			return true
		} catch {
			let errorMsg = error.localizedDescription
			print("⚠️ [AutoLaunchService] Error configurando Launch at Login: \(errorMsg)")
			self.lastError = errorMsg
			refreshStatus()
			return false
		}
	}
}
