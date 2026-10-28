import SwiftUI
import UserNotifications

/// Servicio centralizado de notificaciones locales de macOS para Splash Monitor.
/// Maneja alertas de estado del servidor, avisos de modelos y presión de memoria crítica.
@MainActor @Observable
final class NotificationService {
	@Bindable static private(set) var shared = NotificationService()

	private var center: UNUserNotificationCenter? {
		guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else { return nil }
		if ProcessInfo.processInfo.processName.contains("xctest") ||
			ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
			return nil
		}
		return UNUserNotificationCenter.current()
	}

	var isNotificationsEnabled: Bool {
		didSet {
			Preferences.systemNotificationsEnabled = isNotificationsEnabled
			if isNotificationsEnabled {
				requestAuthorization()
			}
		}
	}

	init() {
		// Habilitado por defecto si no ha sido configurado previamente
		isNotificationsEnabled = Preferences.systemNotificationsEnabled

		if isNotificationsEnabled {
			requestAuthorization()
		}
	}

	/// Solicita autorización para mostrar notificaciones al usuario si aún no está otorgada.
	func requestAuthorization() {
		center?.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
			if let error = error {
				print("⚠️ [NotificationService] Error solicitando permisos: \(error.localizedDescription)")
			}
		}
	}

	/// Envía una notificación cuando el servidor inicia exitosamente.
	func notifyServerStarted(model: String, port: Int) {
		guard isNotificationsEnabled else { return }

		let content = UNMutableNotificationContent()
		content.title = String(localized: "Splash Monitor")
		content.subtitle = String(localized: "Server Active 🟢")

		let modelShort = model.components(separatedBy: "/").last ?? model
		let cleanModel = modelShort
			.replacingOccurrences(of: "-Splash", with: "")
			.replacingOccurrences(of: "-GGUF", with: "")

		content.body = String(localized: "Model \(cleanModel) ready on port :\(port).")
		content.sound = .default

		postNotification(id: "splash.server.started", content: content)
	}

	/// Envía una notificación cuando el servidor se detiene o se cae inesperadamente.
	func notifyServerStopped(reason: LocalizedStringResource? = nil, isUnexpected: Bool = false) {
		guard isNotificationsEnabled else { return }

		let content = UNMutableNotificationContent()
		content.title = String(localized: "Splash Monitor")

		if isUnexpected {
			content.subtitle = String(localized: "⚠️ Server Stopped Unexpectedly")
			content.body = String(localized: reason ?? "The Splash process terminated unexpectedly.")
		} else {
			content.subtitle = String(localized: "Server Stopped")
			content.body = String(localized: reason ?? "Splash server has been stopped.")
		}
		content.sound = isUnexpected ? .defaultCritical : .default

		postNotification(id: "splash.server.stopped", content: content)
	}

	/// Envía una alerta cuando el sistema entra en presión de memoria crítica.
	func notifyMemoryPressureCritical() {
		guard isNotificationsEnabled else { return }

		let content = UNMutableNotificationContent()
		content.title = String(localized: "Splash Monitor")
		content.subtitle = String(localized: "🚨 Critical Memory Pressure")
		content.body = String(localized: "macOS reports unified memory exhaustion. Splash engine entered preventive standby.")
		content.sound = .defaultCritical

		postNotification(id: "splash.memory.critical", content: content)
	}

	private func postNotification(id: String, content: UNMutableNotificationContent) {
		let request = UNNotificationRequest(
			identifier: "\(id).\(Date().timeIntervalSince1970)",
			content: content,
			trigger: nil // Inmediato
		)
		center?.add(request) { error in
			if let error = error {
				print("⚠️ [NotificationService] Fallo enviando notificación: \(error.localizedDescription)")
			}
		}
	}
}
