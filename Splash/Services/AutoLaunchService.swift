import SwiftUI
import ServiceManagement
import OSLog

/// Servicio para gestionar el arranque automático de Splash Monitor al iniciar sesión en macOS.
/// Utiliza `SMAppService.mainApp` nativo disponible en macOS 13+.
@MainActor @Observable
final class AutoLaunchService {
	@Bindable static private(set) var shared = AutoLaunchService()

	private let logger = Logger(subsystem: "do.jmgrep.splashmonitor", category: "AutoLaunchService")

	private var isEnabledCache = false
	private(set) var lastError: String?

	/// §7: sin efectos secundarios — `AppDelegate.applicationDidFinishLaunching`
	/// invoca `refreshStatus()` explícitamente al arrancar.
	init() {}

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
			logger.error("Error configurando Launch at Login: \(errorMsg, privacy: .public)")
			self.lastError = errorMsg
			refreshStatus()
			return false
		}
	}
}
