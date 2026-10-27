import Foundation
import AppKit

// MARK: - App Category
public enum AppCategory: String, Codable, CaseIterable {
    case ide = "IDE / Editor"
    case codingAgent = "Agente de Código"
    case chatbot = "Chatbot / WebUI"
    case terminal = "Terminal / CLI"
    case customScript = "Script / Proceso"
    case lanClient = "Cliente LAN"
    
    public var iconName: String {
        switch self {
        case .ide: return "chevron.left.forwardslash.chevron.right"
        case .codingAgent: return "brain.head.profile"
        case .chatbot: return "bubble.left.and.bubble.right.fill"
        case .terminal: return "terminal.fill"
        case .customScript: return "gearshape.2.fill"
        case .lanClient: return "network"
        }
    }
    
    public var localizedName: LocalizedStringResource {
        switch self {
        case .ide: return "IDE / Code Editor"
        case .codingAgent: return "Autonomous Coding Agent"
        case .chatbot: return "Chatbot / Graphical UI" /*FIXME: "Chatbot / Interfaz Gráfica" */
        case .terminal: return "Terminal / CLI Console" /*FIXME: "Terminal / Consola CLI" */
        case .customScript: return "Script / Custom Process" /*FIXME: "Script / Proceso Personalizado" */
        case .lanClient: return "Remote Client / LAN Network" /*FIXME: "Cliente Remoto / Red LAN" */
        }
    }
}

// MARK: - Connection Status
public enum AppConnectionStatus: String, Codable {
    case active = "active"       // Currently has active open sockets or recent stream
    case idle = "idle"           // Connected but waiting
    case recent = "recent"       // Was connected recently in current session
    
    public var localizedName: LocalizedStringResource {
        switch self {
        case .active: return "Streaming" /*FIXME: "Transmitiendo" */
        case .idle: return "Connected (Idle)" /*FIXME: "Conectado (En espera)" */
        case .recent: return "Recently Disconnected" /*FIXME: "Desconectado reciente" */
        }
    }
}

// MARK: - Connected App Model
public struct ConnectedApp: Identifiable, Hashable {
    public var id: String { "\(pid)-\(name)" }
    public let pid: Int32
    public let name: String
    public let bundleId: String?
    public let executablePath: String?
    public let category: AppCategory
    public let icon: NSImage?
    public var connectionCount: Int
    public var status: AppConnectionStatus
    public var firstConnected: Date
    public var lastSeen: Date
    public var remoteAddress: String
    
    public init(
        pid: Int32,
        name: String,
        bundleId: String? = nil,
        executablePath: String? = nil,
        category: AppCategory = .customScript,
        icon: NSImage? = nil,
        connectionCount: Int = 1,
        status: AppConnectionStatus = .active,
        firstConnected: Date = Date(),
        lastSeen: Date = Date(),
        remoteAddress: String = "127.0.0.1"
    ) {
        self.pid = pid
        self.name = name
        self.bundleId = bundleId
        self.executablePath = executablePath
        self.category = category
        self.icon = icon
        self.connectionCount = connectionCount
        self.status = status
        self.firstConnected = firstConnected
        self.lastSeen = lastSeen
        self.remoteAddress = remoteAddress
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(name)
    }
    
    public static func == (lhs: ConnectedApp, rhs: ConnectedApp) -> Bool {
        return lhs.pid == rhs.pid && lhs.name == rhs.name
    }
}
