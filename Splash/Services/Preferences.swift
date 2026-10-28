import SwiftUI

enum Preferences {

	// MARK: -  Splash Settings

	@AppStorage("refreshInterval") static var refreshInterval: Double = 1.5
	@AppStorage("menuBarDisplayMode") static var menuBarDisplayMode: String = "speed" // "icon", "speed", "tokens", "model"
	@AppStorage("runInBackground") static var runInBackground: Bool = true
	@AppStorage("lastUsedPort") static var lastUsedPort: Int = 8000
	@AppStorage("listenOnAllInterfaces") static var listenOnAllInterfaces: Bool = false
	@AppStorage("maxContext") static var maxContext: String = "auto"
	@AppStorage("idleRelease") static var idleRelease: String = "10m"
	@AppStorage("maxMemory") static var maxMemory: String = "auto"
	@AppStorage("autoReleaseOnMemoryPressure") static var autoReleaseOnMemoryPressure: Bool = true
	@AppStorage("allowedHosts") static var allowedHosts: String = ""
	@AppStorage("allowedOrigins") static var allowedOrigins: String = "*"
	@AppStorage("languageOnly") static var languageOnly: Bool = false
	@AppStorage("customServerFlags") static var customServerFlags: String = ""

	// Splash 1.3.2+ Settings
	@AppStorage("stateFormat") static var stateFormat: String = "fp32" // "fp32" | "bf16"
	@AppStorage("thinkingTokenBudget") static var thinkingTokenBudget: String = "auto" // "auto", "2K", "4K", "8K", "16K", "32K", "off" (-1)
	@AppStorage("persistentCache") static var persistentCache: Bool = false

	// Splash 1.4.0+ Settings
	@AppStorage("verifyRows") static var verifyRows: String = "auto" // "auto" | "all"
	@AppStorage("expertMemory") static var expertMemory: String = "auto" // "auto", "off", "4G", "8G", "12G", "16G", "24G"

	// MARK: - Shell Environment Sync

	/// Consentimiento para modificar `~/.zshrc`, persistido entre sesiones.
	@AppStorage("shellConfigConsent") static var shellConfigConsent = false

	/// El usuario rechazó la escritura: no se vuelve a preguntar.
	@AppStorage("shellConfigDeclined") static var shellConfigDeclined = false

	// MARK: - Main Window

	@AppStorage("showMenuBarIcon") static var showMenuBarIcon: Bool = true
	@AppStorage("hasAskedAboutMenuBar") static var hasAskedAboutMenuBar: Bool = false
	@AppStorage("menuBarOnlyMode") static var menuBarOnlyMode: Bool = false

	// MARK: - Notification Service

	@AppStorage("systemNotificationsEnabled") static var systemNotificationsEnabled = true
}
