import Foundation
import UserNotifications
import AppKit

/// Servicio centralizado de notificaciones locales de macOS para Splash Monitor.
/// Maneja alertas de estado del servidor, avisos de modelos y presión de memoria crítica.
@MainActor
public final class NotificationService: ObservableObject {
    public static let shared = NotificationService()
    
    private var center: UNUserNotificationCenter? {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else { return nil }
        if ProcessInfo.processInfo.processName.contains("xctest") ||
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return nil
        }
        return UNUserNotificationCenter.current()
    }
    private let enabledKey = "systemNotificationsEnabled"
    
    @Published public var isNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isNotificationsEnabled, forKey: enabledKey)
            if isNotificationsEnabled {
                requestAuthorization()
            }
        }
    }
    
    public init() {
        // Habilitado por defecto si no ha sido configurado previamente
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            self.isNotificationsEnabled = true
        } else {
            self.isNotificationsEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
        
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
        let isSpanish = Localization.shared.isSpanish
        content.subtitle = isSpanish ? "Servidor Activo 🟢" : "Server Active 🟢"
        
        let modelShort = model.components(separatedBy: "/").last ?? model
        let cleanModel = modelShort
            .replacingOccurrences(of: "-Splash", with: "")
            .replacingOccurrences(of: "-GGUF", with: "")
        
        content.body = isSpanish
            ? "Modelo \(cleanModel) listo en puerto :\(port)."
            : "Model \(cleanModel) ready on port :\(port)."
        content.sound = .default
        
        postNotification(id: "splash.server.started", content: content)
    }
    
    /// Envía una notificación cuando el servidor se detiene o se cae inesperadamente.
    public func notifyServerStopped(reason: String? = nil, isUnexpected: Bool = false) {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Splash Monitor"
        let isSpanish = Localization.shared.isSpanish
        
        if isUnexpected {
            content.subtitle = isSpanish ? "⚠️ Servidor Detenido Inesperadamente" : "⚠️ Server Stopped Unexpectedly"
            content.body = reason ?? (isSpanish ? "El proceso de Splash se cerró de forma no programada." : "The Splash process terminated unexpectedly.")
        } else {
            content.subtitle = isSpanish ? "Servidor Detenido" : "Server Stopped"
            content.body = reason ?? (isSpanish ? "El servidor Splash ha sido detenido." : "Splash server has been stopped.")
        }
        content.sound = isUnexpected ? .defaultCritical : .default
        
        postNotification(id: "splash.server.stopped", content: content)
    }
    
    /// Envía una alerta cuando el sistema entra en presión de memoria crítica.
    public func notifyMemoryPressureCritical() {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Splash Monitor"
        let isSpanish = Localization.shared.isSpanish
        content.subtitle = isSpanish ? "🚨 Presión de Memoria Crítica" : "🚨 Critical Memory Pressure"
        content.body = isSpanish
            ? "macOS reporta agotamiento de memoria unificada. El motor Splash se puso en reposo preventivo."
            : "macOS reports unified memory exhaustion. Splash engine entered preventive standby."
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
