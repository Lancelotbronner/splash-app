import Foundation
import Dispatch

/// Niveles de presión de memoria del kernel de macOS.
enum SystemMemoryPressureLevel: String, CaseIterable, Codable {
	case normal = "Normal"
	case warning = "Advertencia"
	case critical = "Crítica"

	var isConstrained: Bool {
		return self == .warning || self == .critical
	}
}

/// Delegado opcional para notificaciones síncronas/asíncronas de cambio de presión de memoria.
@MainActor
protocol SystemMemoryPressureSentinelDelegate: AnyObject {
	func memoryPressureDidChange(to level: SystemMemoryPressureLevel)
}

/// Centinela del sistema operativo que escucha eventos del kernel de macOS sobre la presión de memoria unificada.
/// Permite a Splash Monitor reaccionar antes de que el kernel envíe `SIGKILL` o degrade la capacidad de respuesta.
@Observable
final class SystemMemoryPressureSentinel {
	static let shared = SystemMemoryPressureSentinel()

	private(set) var currentPressure: SystemMemoryPressureLevel = .normal
	private(set) var lastWarningDate: Date?
	private(set) var lastCriticalDate: Date?

	weak var delegate: SystemMemoryPressureSentinelDelegate?

	/// Contenedor sin aislamiento para que el manejador del source (que corre en la
	/// cola `.utility`) pueda leerlo sin tocar estado MainActor (§7).
	private final class SourceBox: @unchecked Sendable {
		var source: DispatchSourceMemoryPressure?
	}
	private let sourceBox = SourceBox()
	private let queue = DispatchQueue(label: "com.splashmonitor.memorypressure", qos: .utility)

	/// §7: sin efectos secundarios — `SplashService` invoca `startMonitoring()`
	/// de forma explícida (idempotente) al registrarse como delegado.
	init() {}

	isolated deinit {
		stopMonitoring()
	}

	func startMonitoring() {
		guard sourceBox.source == nil else { return }

		let newSource = DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical], queue: queue)
		sourceBox.source = newSource
		newSource.setEventHandler { [weak self] in
			guard let self = self, let src = self.sourceBox.source else { return }
			let data = src.data

			let level: SystemMemoryPressureLevel
			if data.contains(.critical) {
				level = .critical
			} else if data.contains(.warning) {
				level = .warning
			} else {
				level = .normal
			}

			Task { @MainActor in
				self.currentPressure = level
				if level == .warning {
					self.lastWarningDate = Date()
				} else if level == .critical {
					self.lastCriticalDate = Date()
				}
				self.delegate?.memoryPressureDidChange(to: level)
			}
		}

		// §7: el source se publica antes de `resume()`: antes, un evento que
		// llegase en ese hueo leía `source == nil` y se perdía.
		newSource.resume()
	}

	func stopMonitoring() {
		sourceBox.source?.cancel()
		sourceBox.source = nil
	}

	/// Método de prueba para simular eventos de presión sin esperar a que el Mac se quede sin RAM.
	func simulatePressureChange(to level: SystemMemoryPressureLevel) {
		Task { @MainActor in
			self.currentPressure = level
			if level == .warning {
				self.lastWarningDate = Date()
			} else if level == .critical {
				self.lastCriticalDate = Date()
			}
			self.delegate?.memoryPressureDidChange(to: level)
		}
	}
}
