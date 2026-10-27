import Foundation
import ServiceManagement

/// Servicio para gestionar el arranque automático de Splash Monitor al iniciar sesión en macOS.
/// Utiliza `SMAppService.mainApp` nativo disponible en macOS 13+.
@MainActor
public final class AutoLaunchService: ObservableObject {
    public static let shared = AutoLaunchService()
    
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var lastError: String?
    
    public init() {
        refreshStatus()
    }
    
    /// Actualiza el estado actual consultando a macOS.
    public func refreshStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    /// Activa o desactiva el inicio al arrancar el Mac.
    @discardableResult
    public func setEnabled(_ enable: Bool) -> Bool {
        if #available(macOS 13.0, *) {
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
        return false
    }
}
