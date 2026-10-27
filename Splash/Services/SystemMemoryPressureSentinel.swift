import Foundation
import Dispatch

/// Niveles de presión de memoria del kernel de macOS.
public enum SystemMemoryPressureLevel: String, CaseIterable, Codable {
    case normal = "Normal"
    case warning = "Advertencia"
    case critical = "Crítica"
    
    public var isConstrained: Bool {
        return self == .warning || self == .critical
    }
}

/// Delegado opcional para notificaciones síncronas/asíncronas de cambio de presión de memoria.
@MainActor
public protocol SystemMemoryPressureSentinelDelegate: AnyObject {
    func memoryPressureDidChange(to level: SystemMemoryPressureLevel)
}

/// Centinela del sistema operativo que escucha eventos del kernel de macOS sobre la presión de memoria unificada.
/// Permite a Splash Monitor reaccionar antes de que el kernel envíe `SIGKILL` o degrade la capacidad de respuesta.
@Observable
public final class SystemMemoryPressureSentinel {
    public static let shared = SystemMemoryPressureSentinel()
    
    public private(set) var currentPressure: SystemMemoryPressureLevel = .normal
    public private(set) var lastWarningDate: Date?
    public private(set) var lastCriticalDate: Date?
    
    public weak var delegate: SystemMemoryPressureSentinelDelegate?
    
    private var source: DispatchSourceMemoryPressure?
    private let queue = DispatchQueue(label: "com.splashmonitor.memorypressure", qos: .utility)
    
    public init() {
        startMonitoring()
    }
    
    isolated deinit {
        stopMonitoring()
    }
    
    public func startMonitoring() {
        guard source == nil else { return }
        
        let newSource = DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical], queue: queue)
        newSource.setEventHandler { [weak self] in
            guard let self = self, let src = self.source else { return }
            let data = src.data
            
            let level: SystemMemoryPressureLevel
            if data.contains(.critical) {
                level = .critical
            } else if data.contains(.warning) {
                level = .warning
            } else {
                level = .normal
            }
            
            DispatchQueue.main.async {
                self.currentPressure = level
                if level == .warning {
                    self.lastWarningDate = Date()
                } else if level == .critical {
                    self.lastCriticalDate = Date()
                }
                self.delegate?.memoryPressureDidChange(to: level)
            }
        }
        
        newSource.resume()
        self.source = newSource
    }
    
    public func stopMonitoring() {
        source?.cancel()
        source = nil
    }
    
    /// Método de prueba para simular eventos de presión sin esperar a que el Mac se quede sin RAM.
    public func simulatePressureChange(to level: SystemMemoryPressureLevel) {
        DispatchQueue.main.async {
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
