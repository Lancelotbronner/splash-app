import Foundation
import UserNotifications
import AppKit

/// Servicio centralizado de notificaciones locales de macOS para Splash Monitor.
/// Maneja alertas de estado del servidor, avisos de modelos y presión de memoria crítica.
@MainActor @Observable
public final class NotificationService {
    public static let shared = NotificationService()
    
    private var center: UNUserNotificationCenter? {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else { return nil }
        if ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return nil
        }
        return UNUserNotificationCenter.current()
    }

    public var isNotificationsEnabled: Bool {
        didSet {
            Preferences.systemNotificationsEnabled = isNotificationsEnabled
            if isNotificationsEnabled {
                requestAuthorization()
            }
        }
    }
    
    public init() {
        // Habilitado por defecto si no ha sido configurado previamente
        isNotificationsEnabled = Preferences.systemNotificationsEnabled

        if isNotificationsEnabled {
            requestAuthorization()
        }
    }
    
    /// Solicita autorización para mostrar notificaciones al usuario si aún no está otorgada.
    public func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("⚠️ [NotificationService] Error solicitando permisos: \(error.localizedDescription)")
            }
        }
    }
    
    /// Envía una notificación cuando el servidor inicia exitosamente.
    public func notifyServerStarted(model: String, port: Int) {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Splash Monitor"
        content.subtitle = "Server Active 🟢" /*FIXME: "Servidor Activo 🟢" */
        
        let modelShort = model.components(separatedBy: "/").last ?? model
        let cleanModel = modelShort
            .replacingOccurrences(of: "-Splash", with: "")
            .replacingOccurrences(of: "-GGUF", with: "")
        
        content.body = "Model \(cleanModel) ready on port :\(port)." /*FIXME: "Modelo \(cleanModel) listo en puerto :\(port)." */
        content.sound = .default
        
        postNotification(id: "splash.server.started", content: content)
    }
    
    /// Envía una notificación cuando el servidor se detiene o se cae inesperadamente.
    public func notifyServerStopped(reason: String? = nil, isUnexpected: Bool = false) {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Splash Monitor"
        
        if isUnexpected {
            content.subtitle = "⚠️ Server Stopped Unexpectedly" /*FIXME: "⚠️ Servidor Detenido Inesperadamente" */
            content.body = reason ?? ("The Splash process terminated unexpectedly." /*FIXME: "El proceso de Splash se cerró de forma no programada." */)
        } else {
            content.subtitle = "Server Stopped" /*FIXME: "Servidor Detenido" */
            content.body = reason ?? ("Splash server has been stopped." /*FIXME: "El servidor Splash ha sido detenido." */)
        }
        content.sound = isUnexpected ? .defaultCritical : .default
        
        postNotification(id: "splash.server.stopped", content: content)
    }
    
    /// Envía una alerta cuando el sistema entra en presión de memoria crítica.
    public func notifyMemoryPressureCritical() {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Splash Monitor"
        content.subtitle = "🚨 Critical Memory Pressure" /*FIXME: "🚨 Presión de Memoria Crítica" */
        content.body = "macOS reports unified memory exhaustion. Splash engine entered preventive standby." /*FIXME: "macOS reporta agotamiento de memoria unificada. El motor Splash se puso en reposo preventivo." */
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
