import SwiftUI
import ServiceManagement

/// Servicio para gestionar el arranque automático de Splash Monitor al iniciar sesión en macOS.
/// Utiliza `SMAppService.mainApp` nativo disponible en macOS 13+.
@MainActor @Observable
final class AutoLaunchService {
	@Bindable static private(set) var shared = AutoLaunchService()

	private var isEnabledCache = false
	private(set) var lastError: String?

	init() {
		refreshStatus()
	}

	var isEnabled: Bool {
		get { isEnabledCache }
		set { setEnabled(newValue) }
	}

	/// Actualiza el estado actual consultando a macOS.
	func refreshStatus() {
		isEnabledCache = (SMAppService.mainApp.status == .enabled)
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
