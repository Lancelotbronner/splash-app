import SwiftUI

public enum Preferences {

    // MARK: -  Splash Settings

    @AppStorage("refreshInterval") public static var refreshInterval: Double = 1.5
    @AppStorage("menuBarDisplayMode") public static var menuBarDisplayMode: String = "speed" // "icon", "speed", "tokens", "model"
    @AppStorage("runInBackground") public static var runInBackground: Bool = true
    @AppStorage("lastUsedPort") public static var lastUsedPort: Int = 8000
    @AppStorage("listenOnAllInterfaces") public static var listenOnAllInterfaces: Bool = false
    @AppStorage("maxContext") public static var maxContext: String = "auto"
    @AppStorage("idleRelease") public static var idleRelease: String = "10m"
    @AppStorage("maxMemory") public static var maxMemory: String = "auto"
    @AppStorage("autoReleaseOnMemoryPressure") public static var autoReleaseOnMemoryPressure: Bool = true
    @AppStorage("allowedHosts") public static var allowedHosts: String = ""
    @AppStorage("allowedOrigins") public static var allowedOrigins: String = "*"
    @AppStorage("languageOnly") public static var languageOnly: Bool = false
    @AppStorage("customServerFlags") public static var customServerFlags: String = ""

    // Splash 1.3.2+ Settings
    @AppStorage("stateFormat") public static var stateFormat: String = "fp32" // "fp32" | "bf16"
    @AppStorage("thinkingTokenBudget") public static var thinkingTokenBudget: String = "auto" // "auto", "2K", "4K", "8K", "16K", "32K", "off" (-1)
    @AppStorage("persistentCache") public static var persistentCache: Bool = false

    // Splash 1.4.0+ Settings
    @AppStorage("verifyRows") public static var verifyRows: String = "auto" // "auto" | "all"
    @AppStorage("expertMemory") public static var expertMemory: String = "auto" // "auto", "off", "4G", "8G", "12G", "16G", "24G"

    // MARK: - Shell Environment Sync

    /// Consentimiento para modificar `~/.zshrc`, persistido entre sesiones.
    @AppStorage("shellConfigConsent") public static var shellConfigConsent = false

    /// El usuario rechazó la escritura: no se vuelve a preguntar.
    @AppStorage("shellConfigDeclined") static var shellConfigDeclined = false

    // MARK: - Main Window

    @AppStorage("showMenuBarIcon") static var showMenuBarIcon: Bool = true
    @AppStorage("hasAskedAboutMenuBar") static var hasAskedAboutMenuBar: Bool = false
    @AppStorage("menuBarOnlyMode") static var menuBarOnlyMode: Bool = false

    // MARK: - Notification Service

    @AppStorage("systemNotificationsEnabled") static var systemNotificationsEnabled = true

    // MARK: - App Settings

    @AppStorage("appLanguageMode") static var appLanguageMode = "es"
}
