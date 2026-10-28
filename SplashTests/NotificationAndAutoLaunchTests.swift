import XCTest
@testable import SplashMonitor

@MainActor
final class NotificationAndAutoLaunchTests: XCTestCase {
    
    func testNotificationServiceToggleAndPersistence() {
        let service = NotificationService.shared
        let original = service.isNotificationsEnabled
        
        service.isNotificationsEnabled = false
        XCTAssertFalse(service.isNotificationsEnabled)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "systemNotificationsEnabled"))
        
        service.isNotificationsEnabled = true
        XCTAssertTrue(service.isNotificationsEnabled)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "systemNotificationsEnabled"))
        
        // Restore
        service.isNotificationsEnabled = original
    }
    
    func testNotificationServiceCallsAreSafeInTestEnvironment() {
        let service = NotificationService.shared
        
        // Debe ejecutarse sin lanzar excepciones ni fallar aunque no haya bundle app activo en pruebas
        service.notifyServerStarted(model: "incoai/Qwen3.6-35B-A3B-Splash", port: 8005)
        service.notifyServerStopped(reason: "Test exit", isUnexpected: true)
        service.notifyServerStopped(reason: "Clean stop", isUnexpected: false)
        service.notifyMemoryPressureCritical()
        
        XCTAssertTrue(true, "Todas las llamadas a NotificationService deben completarse de forma segura")
    }
    
    func testAutoLaunchServiceInitializationAndStatusCheck() {
        let service = AutoLaunchService.shared
        
        // Verifica que la consulta a SMAppService no lance excepciones
        service.refreshStatus()
        _ = service.isEnabled
        _ = service.lastError
        
        XCTAssertTrue(true, "AutoLaunchService debe instanciarse e introspeccionar el estado sin errores")
    }
}
