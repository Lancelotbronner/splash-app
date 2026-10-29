import Foundation
import Combine
import SwiftUI
import AppKit
import OSLog

// MARK: - Port Conflict Model

struct PortConflictInfo: Identifiable, Equatable {
	var id: String { "\(port)-\(pid)" }
	let port: Int
	let processName: String
	let pid: Int32
	let suggestedPort: Int

	init(port: Int, processName: String, pid: Int32, suggestedPort: Int) {
		self.port = port
		self.processName = processName
		self.pid = pid
		self.suggestedPort = suggestedPort
	}
}

@Observable
class SplashService {
	@Bindable private(set) static var shared = SplashService()

	// MARK: - Dependencias inyectables (pruebas y sustitución)
	/// Transporte HTTP para `/status`. Sustituible para probar el ciclo de sondeo sin motor.
	let transport: StatusTransport
	/// Operaciones destructivas sobre procesos. Las pruebas inyectan un doble que no
	/// envía señales reales.
	let terminator: ServerTerminating
	/// Intervalo base de sondeo. Las pruebas lo amplían para no depender del reloj.
	let pollInterval: TimeInterval
	/// Raíz de datos de la app. `nil` = `~/Library/Application Support/Splash`.
	let dataDirectoryRoot: URL?
	/// Sustituto del lanzamiento real del motor (escritura de `.command` + `/bin/bash`).
	var serverLaunchOverride: ((_ command: String, _ logFile: URL?, _ background: Bool) -> Void)?
	/// Sustituto de la escritura en el `~/.zshrc` del usuario.
	var shellWriteOverride: ((_ contents: String, _ url: URL) -> Void)?
	/// Directorio donde vive `~/.splash_monitor_env`. `nil` = directorio personal real.
	/// Las pruebas lo apuntan a un directorio temporal para no escribir en el HOME.
	var shellEnvironmentDirectory: URL?
	/// Omite la comprobación previa de conflictos de puerto (pruebas herméticas:
	/// evita abrir un socket real y depender del estado de la máquina).
	var skipPortConflictCheck: Bool = false

	// MARK: - Published State
	var isRunning: Bool = false
	var activePid: Int? = nil
	var activePort: Int = 8000
	var portConflict: PortConflictInfo? = nil
	var activeModel: String = "Ninguno"
	var status: SplashStatus? = nil
	var lastError: LocalizedStringResource? = nil

	// MARK: - §3.4: Valores derivados de `status` en caché
	//
	// Las vistas leían ~10 sub-rutas del payload (`status?.metrics?.ttftMs?.p50`,
	// `status?.memoryPlan?.device`, `status?.vision`, …); cada sub-lectura creaba una
	// dependencia sobre el `SplashStatus` entero. Ahora leen estos valores simples,
	// refrescados en bloque por `updateStatusDerivedCaches()` cuando el sondeo
	// escribe `status`.
	private(set) var ttftP50Ms: Double? = nil
	private(set) var itlP50Ms: Double? = nil
	private(set) var memoryDevice: DeviceInfo? = nil
	private(set) var thermalState: String? = nil
	private(set) var statusMemoryPressure: String? = nil
	private(set) var weights: WeightsStatus? = nil
	private(set) var aneFfn: AneFfnMetrics? = nil
	private(set) var requestsCompleted: Int? = nil
	private(set) var requestsCancelled: Int? = nil
	private(set) var requestsFailed: Int? = nil
	private(set) var schedulerQueued: Int? = nil
	private(set) var statusVision: Bool? = nil

	// §3.4: Contadores de clientes almacenados en lugar de `filter`/`reduce`
	// sobre `connectedApps` en cada evaluación de la barra lateral y el resumen.
	private(set) var activeClientCount: Int = 0
	private(set) var totalSockets: Int = 0

	/// Rastreo de transiciones de estado para notificaciones del sistema macOS
	private var previousRunningState: Bool? = nil

	// Dependencies & CLI state
	var isSplashInstalled: Bool = false
	var splashVersion: String? = nil
	var hasHomebrew: Bool = false
	var isInstallingDependency: Bool = false
	var dependencyInstallLogs: [String] = []
	var dependencyInstallSuccess: Bool? = nil

	// Model lists
	var installedModels: [InstalledSplashModel] = []
	var availableOnlineModels: [HuggingFaceModelItem] = []
	var isLoadingOnlineModels: Bool = false
	var selectedModelForLaunch: String = "incoai/Qwen3.6-35B-A3B-Splash"

	// Model Installation state & metrics
	var isInstalling: Bool = false
	var installingModelId: String? = nil
	var installLogs: [String] = []
	var installSuccess: Bool? = nil
	var downloadSpeedMBs: Double = 0.0
	var downloadedBytes: Int64 = 0
	var totalExpectedBytes: Int64 = 0
	var downloadProgressFraction: Double? = nil
	var downloadPhase: String = ""

	// Server Launching state
	var isStartingServer: Bool = false
	var startingModelId: String? = nil

	// Performance history for graphing
	var speedHistory: [Double] = []

	// MARK: - Perfil de Configuración Óptima (Apple Silicon M4 Max / 64 GB)

	/// Restaura la configuración óptima de alto rendimiento para Apple Silicon M4 Max (64 GB de RAM)
	/// alineada con scripts/apply_local_profile.sh.
	func restoreOptimalProfile() {
		// 1. Motor de Inferencia y Splash 1.3.2
		Preferences.stateFormat = "bf16"
		Preferences.thinkingTokenBudget = "8K"
		Preferences.persistentCache = true
		Preferences.maxContext = "128K"
		Preferences.idleRelease = "off"
		Preferences.languageOnly = true
		Preferences.maxMemory = "auto"
		Preferences.verifyRows = "auto"
		Preferences.expertMemory = "auto"

		// 2. Red, Puerto y Dominios
		Preferences.lastUsedPort = 8005
		Preferences.listenOnAllInterfaces = true
		Preferences.allowedHosts = "jmgrepdevsrl.duckdns.org"
		Preferences.allowedOrigins = "*"

		// 3. Monitor y Sistema
		Preferences.autoReleaseOnMemoryPressure = true
		Preferences.refreshInterval = 1.5
		Preferences.runInBackground = true

		// Persistir directamente en UserDefaults para sincronización con scripts y reinicios
		Preferences.stateFormat = "bf16"
		Preferences.thinkingTokenBudget = "8K"
		Preferences.persistentCache = true
		Preferences.maxContext = "128K"
		Preferences.idleRelease = "off"
		Preferences.languageOnly = true
		Preferences.maxMemory = "auto"
		Preferences.verifyRows = "auto"
		Preferences.expertMemory = "auto"
		Preferences.lastUsedPort = 8005
		Preferences.listenOnAllInterfaces = true
		Preferences.allowedHosts = "jmgrepdevsrl.duckdns.org"
		Preferences.allowedOrigins = "*"
		Preferences.showMenuBarIcon = true
		Preferences.autoReleaseOnMemoryPressure = true
		Preferences.refreshInterval = 1.5
		Preferences.runInBackground = true
	}

	/// Nivel actual de presión de memoria del sistema macOS.
	var systemMemoryPressure: SystemMemoryPressureLevel = .normal
	/// Mensaje informativo cuando la memoria se ha liberado por presión o manualmente.
	var memoryReliefNotice: String? = nil

	/// Dirección IPv4 primaria en la red de área local (ej. "192.168.1.49").
	///
	/// Valor almacenado (§3.5): se refresca durante el sondeo y al cambiar la
	/// configuración LAN. Antes era una propiedad calculada que ejecutaba
	/// `getifaddrs`/`getnameinfo` en cada lectura, y se leía directamente
	/// desde cuerpos de SwiftUI.
	private(set) var localNetworkIP: String?

	/// Refresca `localNetworkIP` consultando las interfaces del sistema.
	func refreshLocalNetworkIP() {
		localNetworkIP = NetworkInterfaceHelper.primaryLocalIPv4()
	}

	/// Host o IP preferida para clientes e integraciones según la configuración activa.
	/// Si `listenOnAllInterfaces` está activo, prioriza el primer dominio permitido configurado
	/// (ej. DDNS como midominio.duckdns.org) o la IP en la red LAN.
	/// En caso contrario, devuelve `127.0.0.1`.
	var preferredHostOrIP: String {
		if Preferences.listenOnAllInterfaces {
			let userHosts = Preferences.allowedHosts
				.components(separatedBy: CharacterSet(charactersIn: ",; \n\t"))
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }
			if let primaryDomain = userHosts.first {
				return primaryDomain
			}
			if let ip = localNetworkIP {
				return ip
			}
		}
		return "127.0.0.1"
	}

	// Update check (Splash Monitor App)
	var hasUpdate: Bool = false
	var latestVersion: String? = nil
	var latestReleaseURL: String? = nil
	let currentVersion = SplashVersion.current
	private let githubRepo = "hometrix/SplashMonitor"

	// Splash CLI Engine Version & Updates (incoai/splash)
	var installedSplashCliVersion: String = ""
	var latestSplashCliVersion: String = ""
	var latestSplashCliReleaseURL: String = "https://github.com/incoai/splash/releases/latest"
	var hasSplashCliUpdate: Bool = false
	var isCheckingSplashCliUpdate: Bool = false

	// Agent installation cache (checked async, not on main thread)
	var installedAgents: Set<String> = []

	// Connected Applications & Clients
	var connectedApps: [ConnectedApp] = []
	private var knownClientsSession: [Int32: ConnectedApp] = [:]

	// Timers & Processes
	private var timer: Timer?
	private var watchdog: Timer?
	/// Intervalo del vigía de recuperación cuando el servidor está detenido.
	var watchdogInterval: TimeInterval { max(5.0, pollInterval * 4) }
	/// Contador para no reescanear el directorio de modelos en cada ciclo (P-12).
	private var ticksSinceModelRefresh = 0
	private var sizeCache = ModelSizeCache()
	/// §3.6: guarda contra ejecuciones superpuestas del sondeo — el intervalo
	/// mínimo (0,5 s) es menor que el timeout del fetch (1,0 s), y sin la guarda
	/// dos `checkServerStatus` podían solaparse (I/O de bloqueos y notificaciones
	/// de transición duplicadas).
	private var isCheckingStatus = false
	/// §7: sustituye los `print` por `os.Logger`.
	private let logger = Logger(subsystem: "do.jmgrep.splashmonitor", category: "SplashService")
	private var installProcess: Process?
	private var isInstallCancelled: Bool = false
	private var dependencyProcess: Process?

	// Paths
	let dataDirectory: URL

	var modelsDirectory: URL {
		dataDirectory.appendingPathComponent("models")
	}

	var runtimeDirectory: URL {
		dataDirectory.appendingPathComponent("runtime")
	}

	/// Ficheros de bloqueo candidatos, en orden de preferencia (P-08).
	/// El motor 1.0.2 escribe `serve-<puerto>.lock`; `serve.lock` se mantiene como
	/// compatibilidad con versiones anteriores y suele llegar vacío.
	func lockFileURLs(port: Int) -> [URL] {
		ServeLockStore.candidateFileNames(port: port).map { runtimeDirectory.appendingPathComponent($0) }
	}

	/// Ruta histórica; se conserva para depuración y para la limpieza de residuos.
	var lockFileURL: URL {
		runtimeDirectory.appendingPathComponent("serve.lock")
	}

	var serverLogURL: URL {
		dataDirectory.appendingPathComponent("logs/server.log")
	}

	func readRecentServerLogs(lines: Int = 100) -> String {
		guard let data = try? Data(contentsOf: serverLogURL),
			  let text = String(data: data, encoding: .utf8) else {
			return ""
		}
		let allLines = text.components(separatedBy: .newlines)
		let slice = allLines.suffix(lines)
		return slice.joined(separator: "\n")
	}

	var brewExecutablePath: String? {
		SplashPaths.firstExisting(SplashPaths.brewExecutableCandidates())
	}

	var splashExecutablePath: String {
		SplashPaths.firstExisting(SplashPaths.splashExecutableCandidates()) ?? "splash"
	}

	var splashPythonPath: String {
		if let stable = SplashPaths.firstExisting(SplashPaths.pythonCandidates(),
												  exists: { FileManager.default.fileExists(atPath: $0) }) {
			return stable
		}
		let versions: (String) -> [String]? = { try? FileManager.default.contentsOfDirectory(atPath: $0) }
		if let cellar = SplashPaths.firstCellarCandidate(subpath: "libexec/python/bin/python3", versions: versions) {
			return cellar
		}
		return "/usr/bin/python3"
	}

	var splashModelsScriptPath: String {
		if let stable = SplashPaths.firstExisting(SplashPaths.modelsScriptCandidates(),
												  exists: { FileManager.default.fileExists(atPath: $0) }) {
			return stable
		}
		let versions: (String) -> [String]? = { try? FileManager.default.contentsOfDirectory(atPath: $0) }
		return SplashPaths.firstCellarCandidate(subpath: "libexec/install/models.py", versions: versions) ?? ""
	}

	init(transport: StatusTransport = URLSessionStatusTransport(),
				terminator: ServerTerminating = HardenedServerTerminator(),
				pollInterval: TimeInterval? = nil,
				dataDirectoryRoot: URL? = nil,
				bootstrapNetwork: Bool = true) {
		self.transport = transport
		self.terminator = terminator
		self.dataDirectoryRoot = dataDirectoryRoot
		// El intervalo configurable por el usuario (`@AppStorage("refreshInterval")`)
		// sigue gobernando el sondeo; las pruebas inyectan uno propio.
		let storedInterval = Preferences.refreshInterval
		let baseInterval = storedInterval > 0 ? storedInterval : 1.5
		self.pollInterval = max(0.5, pollInterval ?? baseInterval)
		self.dataDirectory = dataDirectoryRoot ?? FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent("Library/Application Support/Splash")

		self.activePort = Preferences.lastUsedPort
		refreshLocalNetworkIP()
		checkDependencies()
		startPolling()
		refreshInstalledModels()
		cleanLegacyArtifacts()
		SystemMemoryPressureSentinel.shared.delegate = self
		// §7: el centinela ya no arranca su DispatchSource desde el init (efecto
		// secundario); se arma explícitamente aquí, junto a su delegado. Idempotente.
		SystemMemoryPressureSentinel.shared.startMonitoring()
		// `bootstrapNetwork: false` evita tráfico real (Hugging Face, GitHub) en las
		// pruebas y en cualquier integración que necesite un arranque hermético.
		if bootstrapNetwork {
			Task {
				await fetchOnlineModels()
				await checkForUpdate()
				refreshAgentAvailability()
			}
		}
	}

	// MARK: - Residuos de versiones anteriores (P-17 / H-14)

	/// Elimina restos del *bridge launcher* que se retiró en 1.0.1 pero que sigue en
	/// disco tras actualizar (`~/Library/Application Support/Splash/splash_launcher.py`),
	/// y bloqueos huérfanos del motor.
	func cleanLegacyArtifacts() {
		let fm = FileManager.default
		let legacyFiles = ["splash_launcher.py"]
		for name in legacyFiles {
			let url = dataDirectory.appendingPathComponent(name)
			if fm.fileExists(atPath: url.path) {
				try? fm.removeItem(at: url)
			}
		}
		cleanStaleLocks()
	}

	/// Borra bloqueos del motor cuyo PID ya no existe y que superan el margen de
	/// arranque (P-08). No toca bloqueos vivos.
	func cleanStaleLocks() {
		let fm = FileManager.default
		guard let entries = try? fm.contentsOfDirectory(at: runtimeDirectory,
														includingPropertiesForKeys: [.contentModificationDateKey],
														options: [.skipsHiddenFiles]) else { return }
		for url in entries where url.pathExtension == "lock" {
			let attributes = try? fm.attributesOfItem(atPath: url.path)
			let age = -(attributes?[.modificationDate] as? Date ?? .distantPast).timeIntervalSinceNow
			let data = try? Data(contentsOf: url)
			let lock = ServeLockStore.decode(data)
			let alive = lock.map { kill(Int32($0.pid), 0) == 0 } ?? false
			if ServeLockStore.isStale(lock, pidAlive: alive, age: age) {
				try? fm.removeItem(at: url)
			}
		}
	}

	// MARK: - Dependency Management

	func checkDependencies() {
		self.hasHomebrew = brewExecutablePath != nil
		guard let directPath = SplashPaths.firstExisting(SplashPaths.splashExecutableCandidates()) else {
			self.isSplashInstalled = false
			self.splashVersion = nil
			return
		}
		self.isSplashInstalled = true
		// `splash --version` medido en 30-50 ms (motor 1.0.2, M4 Max): coste acotado.
		let result = CommandRunner.run(directPath, ["--version"])
		let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
		if result.succeeded, !version.isEmpty {
			let clean = version.replacingOccurrences(of: "Splash ", with: "")
				.replacingOccurrences(of: "splash ", with: "")
				.trimmingCharacters(in: .whitespacesAndNewlines)
			self.installedSplashCliVersion = clean
			self.splashVersion = "v\(clean)"
		} else {
			self.installedSplashCliVersion = "1.0"
			self.splashVersion = "v1.0"
		}
	}

	func installSplashDependency() {
		guard !isInstallingDependency else { return }
		isInstallingDependency = true
		dependencyInstallLogs = [
			"Iniciando instalación de la dependencia Splash...",
			"Comando: brew install incoai/tap/splash"
		]
		dependencyInstallSuccess = nil

		guard let brewPath = brewExecutablePath else {
			dependencyInstallLogs.append("Error: No se encontró Homebrew instalado en /opt/homebrew/bin/brew o /usr/local/bin/brew.")
			dependencyInstallLogs.append("Por favor instala Homebrew primero desde https://brew.sh")
			isInstallingDependency = false
			dependencyInstallSuccess = false
			return
		}

		Task.detached(priority: .userInitiated) {
			let proc = Process()
			proc.executableURL = URL(fileURLWithPath: brewPath)
			proc.arguments = ["install", "incoai/tap/splash"]

			var env = ProcessInfo.processInfo.environment
			env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
			proc.environment = env

			let pipe = Pipe()
			proc.standardOutput = pipe
			proc.standardError = pipe

			let outHandle = pipe.fileHandleForReading
			outHandle.readabilityHandler = { handle in
				let data = handle.availableData
				guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
				let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
				Task { @MainActor in
					for line in lines {
						self.dependencyInstallLogs.append(line)
					}
				}
			}

			await MainActor.run {
				self.dependencyProcess = proc
			}

			do {
				try proc.run()
				proc.waitUntilExit()
				outHandle.readabilityHandler = nil

				let status = proc.terminationStatus
				await MainActor.run {
					self.dependencyProcess = nil
					self.isInstallingDependency = false
					if status == 0 {
						self.dependencyInstallSuccess = true
						self.dependencyInstallLogs.append(" Splash se instaló correctamente.")
						self.checkDependencies()
						self.refreshInstalledModels()
					} else {
						self.dependencyInstallSuccess = false
						self.dependencyInstallLogs.append(" brew install finalizó con código de error \(status).")
					}
				}
			} catch {
				await MainActor.run {
					self.dependencyProcess = nil
					self.isInstallingDependency = false
					self.dependencyInstallSuccess = false
					self.dependencyInstallLogs.append(" Error al ejecutar el instalador: \(error.localizedDescription)")
				}
			}
		}
	}

	func cancelDependencyInstall() {
		dependencyProcess?.terminate()
		dependencyProcess = nil
		isInstallingDependency = false
		dependencyInstallLogs.append(" Proceso de instalación cancelado.")
	}

	func installSplashInTerminal() {
		let cmd = """
		echo "🍺 Instalando Splash Engine via Homebrew..."
		echo ""
		brew install incoai/tap/splash
		echo ""
		echo "Instalación finalizada. Ya puedes cerrar esta ventana."
		"""
		runInTerminal(command: cmd, title: "Instalar Splash", scriptFileName: "install_splash.command")
	}

	func upgradeSplashInTerminal() {
		let cmd = """
		echo "🍺 Actualizando Splash Engine via Homebrew..."
		echo ""
		brew update && brew upgrade splash
		echo ""
		echo "Actualización finalizada. Ya puedes cerrar esta ventana."
		"""
		runInTerminal(command: cmd, title: "Actualizar Splash", scriptFileName: "upgrade_splash.command")
	}

	private func runInTerminal(command: String, title: String, scriptFileName: String) {
		try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
		let scriptURL = dataDirectory.appendingPathComponent(scriptFileName)
		let scriptContent = """
		#!/bin/bash
		printf "\\e]0;\(title)\\a"
		\(command)
		"""
		try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
		try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

		let proc = Process()
		proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
		proc.arguments = ["-a", "Terminal", scriptURL.path]
		try? proc.run()

		// Also bring Terminal window to foreground
		let actProc = Process()
		actProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
		actProc.arguments = ["-e", "tell application \"Terminal\" to activate"]
		try? actProc.run()
	}

	// MARK: - Polling & Status Fetching

	func startPolling() {
		timer?.invalidate()
		watchdog?.invalidate()
		watchdog = nil
		timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			Task { @MainActor in
				await self.checkServerStatus()
			}
		}
		// Immediate check
		Task { @MainActor in
			await self.checkServerStatus()
		}
	}

	/// `true` mientras el sondeo periódico está vivo (P-02). Expuesto para las pruebas.
	var isPollingActive: Bool {
		timer?.isValid ?? false
	}

	/// `true` mientras el vigía de recuperación está armado. Expuesto para las pruebas.
	var isWatchdogActive: Bool {
		watchdog?.isValid ?? false
	}

	/// Vigía de recuperación (P-02).
	///
	/// Defecto corregido: `stopServerAsync()` invalidaba el temporizador y **ninguna ruta
	/// lo recreaba**, de modo que tras pulsar «Detener Servidor» una vez el panel dejaba
	/// de actualizarse durante el resto de la sesión, y un motor arrancado desde la
	/// terminal nunca se detectaba. Ahora, con el servidor detenido, un vigía lento
	/// comprueba el estado y reconstruye el sondeo en cuanto aparece un motor vivo.
	private func ensureWatchdog() {
		guard watchdog == nil else { return }
		watchdog = Timer.scheduledTimer(withTimeInterval: watchdogInterval, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			Task { @MainActor in
				await self.watchdogTick()
			}
		}
	}

	/// Un ciclo del vigía: comprueba el estado y reconstruye el sondeo si hay motor.
	/// Expuesto para poder probarlo sin depender del reloj.
	func watchdogTick() async {
		await checkServerStatus()
		if isRunning { restorePollingAfterDetection() }
	}

	/// Reconstruye el sondeo periódico y apaga el vigía.
	func restorePollingAfterDetection() {
		watchdog?.invalidate()
		watchdog = nil
		if !isPollingActive { startPolling() }
	}

	func checkServerStatus() async {
		// §3.6: guarda en vuelo — el timeout del fetch (1,0 s) supera el intervalo
		// mínimo (0,5 s) y dos ciclos podían solaparse duplicando I/O de bloqueos y
		// notificaciones de transición.
		guard !isCheckingStatus else { return }
		isCheckingStatus = true
		defer { isCheckingStatus = false }

		// 1. Resolver el bloqueo del motor (serve-<puerto>.lock y compatibilidad con
		//    serve.lock) fuera del actor principal (§3.6): antes era I/O de fichero
		//    síncrona (Data + atributos + remove) en cada tick del sondeo.

		let lock = await resolveActiveLock(candidateURLs: lockCandidateURLs(), fallbackPort: activePort)

		if lock.pid != nil {
			self.activePort = lock.port
			// §3.1: solo escribir si cambia, para que el setter observable haga
			// cortocircuito y no invalide las vistas en cada tick.
			if let model = lock.model, model != self.activeModel {
				self.activeModel = model
			}
		}
		self.activePid = lock.pid

		// 2. Consultar /status a través del transporte inyectable
		if let decoded = await transport.fetchStatus(port: activePort, timeout: 1.0) {
			// §3.1: escrituras condicionales — el fetch corre cada 1,5 s y asignar
			// valores idénticos disparaba la invalidación observable de cada vista.
			if self.status != decoded {
				self.status = decoded
			}
			let running = decoded.ready ?? true
			if self.isRunning != running {
				self.isRunning = running
			}
			if let instanceModel = decoded.instance?.model, instanceModel != self.activeModel {
				self.activeModel = instanceModel
			}
			if let pid = decoded.instance?.pid {
				self.activePid = pid
			}

			// Track decode speed for chart
			let currentSpeed = decoded.metrics?.decodeTokensPerSecond ?? 0.0
			self.speedHistory.append(currentSpeed)
			if self.speedHistory.count > 30 {
				self.speedHistory.removeFirst()
			}
			self.lastError = nil

			// Sync shell env if port changed (e.g. after brew upgrade)
			if self.activePort != Preferences.lastUsedPort {
				Preferences.lastUsedPort = self.activePort
				self.syncShellEnvironment(port: self.activePort)
			}
		} else {
			// Fallback: scan flexible de puertos si no hay bloqueo vivo
			if lock.pid == nil {
				await scanAndConnectPort()
			} else {
				if self.isRunning {
					self.isRunning = false
				}
				if self.status != nil {
					self.status = nil
				}
			}
		}

		// §3.4: refrescar las cachés derivadas de `status` tras el fetch.
		updateStatusDerivedCaches()

		// Comprobar transiciones de estado para notificaciones macOS
		if let wasRunning = previousRunningState {
			if !wasRunning && self.isRunning {
				NotificationService.shared.notifyServerStarted(model: self.activeModel, port: self.activePort)
			} else if wasRunning && !self.isRunning && !self.isStartingServer {
				NotificationService.shared.notifyServerStopped(reason: self.lastError, isUnexpected: true)
			}
		}
		previousRunningState = self.isRunning

		// Scan active connected apps/clients
		await scanConnectedClients()

		// §3.5: mantener la IP LAN almacenada fresca en cada ciclo (era un
		// `getifaddrs` por lectura en el cuerpo de la vista).
		refreshLocalNetworkIP()

		// 3. Reescaneo del catálogo local: como mucho una vez cada 10 ciclos (P-12).
		//    El tamaño en disco no cambia entre ciclos y resolver 215 ficheros con
		//    symlinks costaba 7,5 ms de E/S síncrona sobre el @MainActor cada 1,5 s.
		ticksSinceModelRefresh += 1
		if ticksSinceModelRefresh >= 10 || installedModels.isEmpty {
			ticksSinceModelRefresh = 0
			refreshInstalledModels()
			// El cache de agentes (incluida la presencia de apps) puede quedar
			// obsoleto si el usuario instala/desinstala con la app abierta (§3.5).
			refreshAgentAvailability()
		}
	}

	/// Valor del bloqueo activo resuelto fuera del actor principal (§3.6).
	nonisolated private struct LockSnapshot: Sendable {
		let pid: Int?
		let port: Int
		let model: String?
	}

	/// Lee, decodifica y poda los ficheros de bloqueo en segundo plano (§3.6):
	/// antes eran I/O síncrona (`Data` + atributos + `removeItem`) en cada tick.
	private func resolveActiveLock(candidateURLs: [URL], fallbackPort: Int) async -> LockSnapshot {
		await Task.detached(priority: .utility) {
			for url in candidateURLs {
				guard let data = try? Data(contentsOf: url),
					  let lock = ServeLockStore.decode(data), lock.pid > 0 else { continue }
				let alive = kill(Int32(lock.pid), 0) == 0
				if alive {
					return LockSnapshot(pid: lock.pid, port: lock.port, model: lock.model)
				}
				// PID muerto: se limpia solo si ya pasó el margen de arranque (P-08).
				let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
				let age = -(attributes?[.modificationDate] as? Date ?? .distantPast).timeIntervalSinceNow
				if ServeLockStore.isStale(lock, pidAlive: false, age: age) {
					try? FileManager.default.removeItem(at: url)
				}
			}
			return LockSnapshot(pid: nil, port: fallbackPort, model: nil)
		}.value
	}

	/// §3.4: campos derivados de `status` calculados una vez por ciclo en el
	/// servicio, en lugar de navegar el árbol de opcionales en el cuerpo de
	/// cada vista con cada invalidación.
	private func updateStatusDerivedCaches() {
		guard let s = status else {
			ttftP50Ms = nil
			itlP50Ms = nil
			memoryDevice = nil
			thermalState = nil
			statusMemoryPressure = nil
			weights = nil
			aneFfn = nil
			requestsCompleted = nil
			requestsCancelled = nil
			requestsFailed = nil
			schedulerQueued = nil
			statusVision = nil
			return
		}
		ttftP50Ms = s.metrics?.ttftMs?.p50
		itlP50Ms = s.metrics?.itlMs?.p50
		memoryDevice = s.memoryPlan?.device
		thermalState = s.thermalState
		statusMemoryPressure = s.memoryPressure
		weights = s.weights
		aneFfn = s.aneFfn
		requestsCompleted = s.requests?.completed
		requestsCancelled = s.requests?.cancelled
		requestsFailed = s.requests?.failed
		schedulerQueued = s.scheduler?.queued
		statusVision = s.vision
	}

	/// Ficheros de bloqueo a considerar, priorizando el del puerto activo.
	func lockCandidateURLs() -> [URL] {
		let fm = FileManager.default
		var urls = lockFileURLs(port: activePort)
		if let entries = try? fm.contentsOfDirectory(at: runtimeDirectory,
													 includingPropertiesForKeys: nil,
													 options: [.skipsHiddenFiles]) {
			let discovered = entries
				.filter { $0.lastPathComponent.hasPrefix("serve") && $0.pathExtension == "lock" }
				.sorted { $0.lastPathComponent > $1.lastPathComponent }
			for url in discovered where !urls.contains(url) {
				urls.append(url)
			}
		}
		return urls
	}

	private func scanAndConnectPort() async {
		let portsToTry = [activePort, Preferences.lastUsedPort, 8000, 8001, 8005, 8008, 8080, 8088, 8888, 9000, 9005]
		var seen = Set<Int>()
		let uniquePorts = portsToTry.filter { seen.insert($0).inserted }

		for port in uniquePorts {
			guard let decoded = await transport.fetchStatus(port: port, timeout: 0.8) else { continue }
			self.activePort = port
			Preferences.lastUsedPort = port
			self.syncShellEnvironment(port: port)
			// §3.1: escrituras condicionales, mismo criterio que en checkServerStatus.
			if self.status != decoded {
				self.status = decoded
			}
			let running = decoded.ready ?? true
			if self.isRunning != running {
				self.isRunning = running
			}
			if let instanceModel = decoded.instance?.model, instanceModel != self.activeModel {
				self.activeModel = instanceModel
			}
			if let pid = decoded.instance?.pid {
				self.activePid = pid
			}
			return
		}
	}

	// MARK: - Local Installed Models

	func refreshInstalledModels() {
		// §7: el recorrido completo del árbol (215 ficheros, ~7,5 ms de E/S) ya no
		// bloquea al actor principal: se captura por valor y se publica al terminar.
		Task { await self.refreshInstalledModelsAsync() }
	}

	/// Núcleo awaitable del reescaneo del catálogo; el bucle de sondeo lo lanza
	/// sin bloquear (`refreshInstalledModels`) y las pruebas lo esperan directamente.
	func refreshInstalledModelsAsync() async {
		let directory = modelsDirectory
		let currentModel = activeModel
		let currentlyRunning = isRunning
		let cache = sizeCache
		let selection = selectedModelForLaunch
		let (results, updatedCache) = await Self.scanInstalledModels(
			directory: directory,
			activeModel: currentModel,
			isRunning: currentlyRunning,
			cache: cache
		)
		self.sizeCache = updatedCache
		self.installedModels = results
		if currentlyRunning && !currentModel.isEmpty && currentModel != "Ninguno" {
			self.selectedModelForLaunch = currentModel
		} else if (selection.isEmpty || !results.contains(where: { $0.repoId == selection })),
				  let first = results.first {
			self.selectedModelForLaunch = first.repoId
		}
	}

	/// Recorrido del directorio de modelos fuera del actor principal (§7).
	nonisolated static func scanInstalledModels(directory: URL,
												activeModel: String,
												isRunning: Bool,
												cache: ModelSizeCache) async -> ([InstalledSplashModel], ModelSizeCache) {
		var results: [InstalledSplashModel] = []
		var sizeCache = cache
		let fm = FileManager.default

		guard fm.fileExists(atPath: directory.path) else {
			return ([], sizeCache)
		}

		do {
			let owners = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
			for ownerURL in owners where ownerURL.hasDirectoryPath {
				let owner = ownerURL.lastPathComponent
				let modelURLs = try fm.contentsOfDirectory(at: ownerURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
				for modelURL in modelURLs {
					let modelName = modelURL.lastPathComponent
					let repoId = "\(owner)/\(modelName)"
					let isActive = (repoId == activeModel && isRunning)

					// Tamaño real resolviendo symlinks, con caché por modelo (P-12).
					// La clave incluye la fecha de modificación del enlace: al reinstalar
					// o actualizar un modelo el valor se recalcula solo.
					let stamp = (try? modelURL.resourceValues(forKeys: [.contentModificationDateKey]))?
						.contentModificationDate
					let size = sizeCache.size(repoId: repoId, stamp: stamp) {
						Self.directorySize(url: modelURL)
					}

					results.append(InstalledSplashModel(
						repoId: repoId,
						localPath: modelURL,
						diskSizeBytes: size,
						isCurrentlyActive: isActive
					))
				}
			}

			// Escanear también el directorio .resolved de Splash
			// Splash guarda en .resolved los modelos preparados/instalados (incluyendo los que tienen opciones como --language-only o GGUFs)
			let resolvedDirectory = directory.appendingPathComponent(".resolved")
			if fm.fileExists(atPath: resolvedDirectory.path),
			   let resolvedDirs = try? fm.contentsOfDirectory(at: resolvedDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
				for resolvedURL in resolvedDirs where resolvedURL.hasDirectoryPath {
					let modelJsonURL = resolvedURL.appendingPathComponent("model.json")
					guard fm.fileExists(atPath: modelJsonURL.path),
						  let data = try? Data(contentsOf: modelJsonURL),
						  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
						  let modelId = json["model"] as? String,
						  !modelId.isEmpty else {
						continue
					}

					// Si ya fue encontrado por el escaneo directo de carpetas, continuar
					if results.contains(where: { $0.repoId == modelId }) {
						continue
					}

					// Crear enlace simbólico de cortesía en models/OWNER/MODEL_NAME si no existe
					let parts = modelId.split(separator: "/", maxSplits: 1).map { String($0) }
					if parts.count == 2 {
						let owner = parts[0]
						let modelName = parts[1]
						let ownerDir = directory.appendingPathComponent(owner)
						let targetSymlink = ownerDir.appendingPathComponent(modelName)
						if !fm.fileExists(atPath: targetSymlink.path) {
							try? fm.createDirectory(at: ownerDir, withIntermediateDirectories: true)
							try? fm.createSymbolicLink(at: targetSymlink, withDestinationURL: resolvedURL)
						}
					}

					let isActive = (modelId == activeModel && isRunning)
					let stamp = (try? resolvedURL.resourceValues(forKeys: [.contentModificationDateKey]))?
						.contentModificationDate
					let size = sizeCache.size(repoId: modelId, stamp: stamp) {
						Self.directorySize(url: resolvedURL)
					}

					results.append(InstalledSplashModel(
						repoId: modelId,
						localPath: resolvedURL,
						diskSizeBytes: size,
						isCurrentlyActive: isActive
					))
				}
			}
		} catch {
			// §7: os.Logger en lugar de print (el trabajo ya corre fuera del actor).
			let scanLogger = Logger(subsystem: "do.jmgrep.splashmonitor", category: "SplashService")
			scanLogger.error("Error scanning installed models: \(error.localizedDescription)")
		}

		return (results, sizeCache)
	}

	/// Suma el tamaño real de un árbol resolviendo enlaces simbólicos.
	/// `nonisolated` para poder invocarse desde trabajo en segundo plano.
	nonisolated static func directorySize(url: URL) -> Int64 {
		let fm = FileManager.default
		var total: Int64 = 0
		let resolvedRoot = url.resolvingSymlinksInPath()

		guard let enumerator = fm.enumerator(at: resolvedRoot, includingPropertiesForKeys: [.fileSizeKey]) else {
			return 0
		}
		for case let fileURL as URL in enumerator {
			let resolved = fileURL.resolvingSymlinksInPath()
			if let attrs = try? fm.attributesOfItem(atPath: resolved.path),
			   let size = attrs[.size] as? Int64 {
				total += size
			}
		}
		return total
	}

	func deleteModel(repoId: String) {
		// El identificador llega de la interfaz y se usa como ruta: sin validar,
		// un valor como `../../..` borraba fuera del directorio de modelos.
		guard ModelIDValidator.isValid(repoId) else {
			self.lastError = "Identificador de modelo no válido: \(repoId)"
			return
		}

		let fm = FileManager.default
		let baseRepo = ModelIDValidator.components(from: repoId).map { "\($0.owner)/\($0.repository)" } ?? repoId

		if (repoId == activeModel || baseRepo == activeModel) && isRunning {
			stopServer()
		}

		// 1. Eliminar symlinks o carpetas en models/OWNER/REPO y models/OWNER/REPO:VARIANT
		let directURL = modelsDirectory.appendingPathComponent(repoId)
		if fm.fileExists(atPath: directURL.path) {
			try? fm.removeItem(at: directURL)
		}
		let baseURL = modelsDirectory.appendingPathComponent(baseRepo)
		if fm.fileExists(atPath: baseURL.path) {
			try? fm.removeItem(at: baseURL)
		}

		// 2. Eliminar de models/.resolved cualquier descriptor cuyo model.json apunte a este repoId o baseRepo
		let resolvedDir = modelsDirectory.appendingPathComponent(".resolved")
		if fm.fileExists(atPath: resolvedDir.path),
		   let resolvedEntries = try? fm.contentsOfDirectory(at: resolvedDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
			for dir in resolvedEntries where dir.hasDirectoryPath {
				let jsonURL = dir.appendingPathComponent("model.json")
				if let data = try? Data(contentsOf: jsonURL),
				   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				   let mid = json["model"] as? String {
					if mid == repoId || mid == baseRepo {
						try? fm.removeItem(at: dir)
					}
				}
			}
		}

		// 3. Limpiar enlaces muertos o asociados en models/.selections
		let selectionsDir = modelsDirectory.appendingPathComponent(".selections")
		if fm.fileExists(atPath: selectionsDir.path),
		   let selectionEntries = try? fm.contentsOfDirectory(at: selectionsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
			for sel in selectionEntries {
				let dest = (try? fm.destinationOfSymbolicLink(atPath: sel.path)) ?? ""
				if !fm.fileExists(atPath: sel.resolvingSymlinksInPath().path) || dest.isEmpty {
					try? fm.removeItem(at: sel)
				}
			}
		}

		// 4. Eliminar del caché de Hugging Face si existe (~/.cache/huggingface/hub/models--owner--repo)
		if let comps = ModelIDValidator.components(from: repoId) {
			let hfCacheDir = FileManager.default.homeDirectoryForCurrentUser
				.appendingPathComponent(".cache/huggingface/hub")
				.appendingPathComponent("models--\(comps.owner)--\(comps.repository)")
			if fm.fileExists(atPath: hfCacheDir.path) {
				try? fm.removeItem(at: hfCacheDir)
			}
		}

		// 5. Limpiar carpeta de owner si quedó vacía (ej. models/HauhauCS/)
		if let comps = ModelIDValidator.components(from: repoId) {
			let ownerDir = modelsDirectory.appendingPathComponent(comps.owner)
			if let contents = try? fm.contentsOfDirectory(at: ownerDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]),
			   contents.isEmpty {
				try? fm.removeItem(at: ownerDir)
			}
		}

		sizeCache.invalidate(repoId: repoId)
		sizeCache.invalidate(repoId: baseRepo)
		refreshInstalledModels()
	}

	func openModelInFinder(repoId: String) {
		if let installed = installedModels.first(where: { $0.repoId == repoId }) {
			let target = installed.localPath.resolvingSymlinksInPath()
			if FileManager.default.fileExists(atPath: target.path) {
				NSWorkspace.shared.selectFile(target.path, inFileViewerRootedAtPath: "")
				return
			}
		}
		let symlinkURL = modelsDirectory.appendingPathComponent(repoId)
		let resolved = symlinkURL.resolvingSymlinksInPath()
		if FileManager.default.fileExists(atPath: resolved.path) {
			NSWorkspace.shared.selectFile(resolved.path, inFileViewerRootedAtPath: "")
		} else if FileManager.default.fileExists(atPath: symlinkURL.path) {
			NSWorkspace.shared.selectFile(symlinkURL.path, inFileViewerRootedAtPath: "")
		} else {
			NSWorkspace.shared.open(modelsDirectory)
		}
	}

	// MARK: - Update Checks (Splash Monitor App & Splash CLI Engine)

	func checkForUpdate() async {
		// 1. Splash Monitor App Update
		if let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") {
			var request = URLRequest(url: url)
			request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
			request.timeoutInterval = 5.0

			if let (data, _) = try? await URLSession.shared.data(for: request),
			   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			   let tagName = json["tag_name"] as? String {
				let latest = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
				if SemanticVersion.isNewer(latest, than: currentVersion) {
					self.hasUpdate = true
					self.latestVersion = tagName
					self.latestReleaseURL = json["html_url"] as? String ?? "https://github.com/\(githubRepo)/releases/latest"
				} else {
					self.hasUpdate = false
					self.latestVersion = tagName
				}
			}
		}

		// 2. Splash CLI Engine Update (incoai/splash)
		await checkSplashCliUpdate()
	}

	/// Detecta la versión actualmente instalada del motor Splash CLI en el sistema (ej. "1.3.1").
	@discardableResult
	func detectInstalledSplashVersion() -> String {
		guard isSplashInstalled else { return "" }
		let path = splashExecutablePath
		guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else { return "" }

		let res = CommandRunner.run(path, ["--version"])
		let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
		var detected = trimmed
		if trimmed.lowercased().hasPrefix("splash ") {
			detected = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
		}
		if !detected.isEmpty {
			self.installedSplashCliVersion = detected
		}
		return detected
	}

	/// Comprueba si existe una versión más reciente del motor oficial Splash CLI en GitHub (incoai/splash).
	func checkSplashCliUpdate() async {
		guard isSplashInstalled else { return }
		self.isCheckingSplashCliUpdate = true

		// 1. Detectar versión local
		let localVersion = detectInstalledSplashVersion()
		if !localVersion.isEmpty {
			self.installedSplashCliVersion = localVersion
		}

		// 2. Consultar releases de incoai/splash
		guard let url = URL(string: "https://api.github.com/repos/incoai/splash/releases/latest") else {
			self.isCheckingSplashCliUpdate = false
			return
		}
		var request = URLRequest(url: url)
		request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
		request.timeoutInterval = 5.0

		guard let (data, _) = try? await URLSession.shared.data(for: request),
			  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let tagName = json["tag_name"] as? String else {
			self.isCheckingSplashCliUpdate = false
			return
		}

		let latestClean = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
		self.latestSplashCliVersion = latestClean
		if let htmlUrl = json["html_url"] as? String {
			self.latestSplashCliReleaseURL = htmlUrl
		}

		// 3. Comparar semánticamente
		if !self.installedSplashCliVersion.isEmpty && SemanticVersion.isNewer(latestClean, than: self.installedSplashCliVersion) {
			self.hasSplashCliUpdate = true
		} else {
			self.hasSplashCliUpdate = false
		}
		self.isCheckingSplashCliUpdate = false
	}

	// MARK: - Online Models Catalog (Hugging Face)

	func fetchOnlineModels() async {
		// §7: guarda en vuelo — antes dos pulsaciones solapadas lanzaban dos
		// oleadas de peticiones en paralelo (la bandera solo se seteaba).
		guard !isLoadingOnlineModels else { return }
		self.isLoadingOnlineModels = true
		var allItems: [String: HuggingFaceModelItem] = [:]

		// 1. Fetch official MLX community models (Splash 1.3.1+)
		if let mlxUrl = URL(string: "https://huggingface.co/api/models?author=mlx-community&search=Qwen3") {
			if let (data, _) = try? await URLSession.shared.data(from: mlxUrl),
			   let items = try? JSONDecoder().decode([HuggingFaceModelItem].self, from: data) {
				for item in items {
					let lower = item.id.lowercased()
					if (lower.contains("27b") || lower.contains("35b")) && (lower.contains("4bit") || lower.contains("8bit") || lower.contains("optiq") || lower.contains("nvfp4") || lower.contains("fp8")) {
						allItems[item.id] = item
					}
				}
			}
		}

		// 2. Fetch NVIDIA official NVFP4/FP8 models (Splash 1.3.2+)
		if let nvidiaUrl = URL(string: "https://huggingface.co/api/models?author=nvidia&search=Qwen") {
			if let (data, _) = try? await URLSession.shared.data(from: nvidiaUrl),
			   let items = try? JSONDecoder().decode([HuggingFaceModelItem].self, from: data) {
				for item in items {
					let lower = item.id.lowercased()
					if (lower.contains("27b") || lower.contains("35b")) && (lower.contains("nvfp4") || lower.contains("fp8") || lower.contains("4bit")) {
						allItems[item.id] = item
					}
				}
			}
		}

		// 3. Fetch models with tag "splash" (excluyendo paquetes viejos y discontinuados -Splash)
		if let splashTagUrl = URL(string: "https://huggingface.co/api/models?filter=splash") {
			if let (data, _) = try? await URLSession.shared.data(from: splashTagUrl),
			   let items = try? JSONDecoder().decode([HuggingFaceModelItem].self, from: data) {
				for item in items {
					if !item.id.hasSuffix("-Splash") {
						allItems[item.id] = item
					}
				}
			}
		}

		// 4. Fetch Flash-Next models (Splash 1.4.0+)
		// En Splash 1.4.0, Flash-Next solo puede cargarse desde GGUF (con tag de cuantización :VARIANT).
		let officialFlashNextQ2 = HuggingFaceModelItem(
			id: "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:Q2_0",
			likes: 999,
			downloads: 50000,
			tags: ["splash", "flash-next", "gguf", "q2_0"],
			pipelineTag: "text-generation",
			createdAt: "2026-10-18T00:00:00.000Z"
		)
		allItems[officialFlashNextQ2.id] = officialFlashNextQ2

		let officialFlashNextIQ3 = HuggingFaceModelItem(
			id: "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:IQ3_S",
			likes: 850,
			downloads: 32000,
			tags: ["splash", "flash-next", "gguf", "iq3_s"],
			pipelineTag: "text-generation",
			createdAt: "2026-10-18T00:00:00.000Z"
		)
		allItems[officialFlashNextIQ3.id] = officialFlashNextIQ3

		if let flashNextUrl = URL(string: "https://huggingface.co/api/models?search=Flash-Next&sort=downloads") {
			if let (data, _) = try? await URLSession.shared.data(from: flashNextUrl),
			   let items = try? JSONDecoder().decode([HuggingFaceModelItem].self, from: data) {
				for item in items {
					let lower = item.id.lowercased()
					// Descartar repositorio base de pesos crudos que Splash rechaza explícitamente ("loads from a GGUF only")
					if lower == "qwen/qwen3.8-flash-next" {
						continue
					}
					if lower.contains("flash-next") && (lower.contains("gguf") || lower.contains("gsq")) {
						allItems[item.id] = item
					}
				}
			}
		}

		// 5. Modelos Splash 1.4.1: Ornith-1.5-122B y Flint
		let ornithGGUF = HuggingFaceModelItem(
			id: "unsloth/Ornith-1.5-122B-GGUF:UD-Q4_K_XL",
			likes: 1200,
			downloads: 60000,
			tags: ["splash", "ornith", "gguf", "vision", "q4_k_xl"],
			pipelineTag: "text-generation",
			createdAt: "2026-10-26T00:00:00.000Z"
		)
		allItems[ornithGGUF.id] = ornithGGUF

		let ornithMLX = HuggingFaceModelItem(
			id: "ornith-ai/Ornith-1.5-122B-MLX-4bit",
			likes: 900,
			downloads: 40000,
			tags: ["splash", "ornith", "mlx", "vision", "4bit"],
			pipelineTag: "text-generation",
			createdAt: "2026-10-26T00:00:00.000Z"
		)
		allItems[ornithMLX.id] = ornithMLX

		let flintGGUF = HuggingFaceModelItem(
			id: "unsloth/flint-GGUF:UD-Q4_K_XL",
			likes: 800,
			downloads: 35000,
			tags: ["splash", "flint", "gguf", "moe", "q4_k_xl"],
			pipelineTag: "text-generation",
			createdAt: "2026-10-26T00:00:00.000Z"
		)
		allItems[flintGGUF.id] = flintGGUF

		// Fetch dinámico de Ornith y Flint desde HuggingFace
		for searchTerm in ["Ornith-1.5-122B", "flint-GGUF"] {
			let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
			if let url = URL(string: "https://huggingface.co/api/models?search=\(encoded)&sort=downloads") {
				if let (data, _) = try? await URLSession.shared.data(from: url),
				   let items = try? JSONDecoder().decode([HuggingFaceModelItem].self, from: data) {
					for item in items {
						let lower = item.id.lowercased()
						if lower.contains("ornith") || lower.contains("flint") {
							allItems[item.id] = item
						}
					}
				}
			}
		}

		// Sort: Official first, then likes/name
		let sorted = allItems.values.sorted { m1, m2 in
			if m1.isOfficial != m2.isOfficial {
				return m1.isOfficial && !m2.isOfficial
			}
			return (m1.likes ?? 0) > (m2.likes ?? 0)
		}

		self.availableOnlineModels = Array(sorted)
		self.isLoadingOnlineModels = false
	}

	func installModel(repoId: String, languageOnly: Bool? = nil) {
		guard !isInstalling else { return }
		guard ModelIDValidator.isValid(repoId) else {
			self.lastError = ModelIDValidator.rejectionReason(repoId) ?? "Identificador de modelo no válido."
			return
		}

		// Soporte y mapeo de Flash-Next: Splash 1.4.0 solo permite cargar Flash-Next desde GGUF con variante (e.g. :Q2_0).
		// Si el usuario solicita el repositorio base de pesos crudos 'Qwen/Qwen3.8-Flash-Next', mapear a la cuantización GGUF oficial.
		let effectiveRepoId: String
		let trimmedRepo = repoId.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmedRepo.lowercased() == "qwen/qwen3.8-flash-next" || trimmedRepo.lowercased() == "qwen3.8-flash-next" {
			effectiveRepoId = "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:Q2_0"
		} else {
			effectiveRepoId = trimmedRepo
		}

		isInstalling = true
		isInstallCancelled = false
		installingModelId = effectiveRepoId
		downloadSpeedMBs = 0.0
		downloadedBytes = 0
		totalExpectedBytes = 0
		downloadProgressFraction = nil
		downloadPhase = "Iniciando descarga y preparación..."

		let textOnlyKeywords = ["coder", "magicoder", "starcoder", "codellama"]
		let autoLangOnly = textOnlyKeywords.contains { effectiveRepoId.lowercased().contains($0) }
		let initialLangOnly = languageOnly ?? autoLangOnly

		if effectiveRepoId != repoId {
			installLogs = [
				"Iniciando descarga y preparación para \(effectiveRepoId)...",
				"ℹ️ Qwen3.8-Flash-Next requiere formato GGUF en Splash 1.4.0.",
				"🔄 Mapeando automáticamente a la versión oficial cuantizada: \(effectiveRepoId)"
			]
		} else {
			installLogs = ["Iniciando descarga y preparación para \(repoId)..."]
		}
		if initialLangOnly {
			installLogs.append("ℹ️ Modo solo lenguaje (--language-only) activado.")
		}
		installSuccess = nil

		let modelsPath = modelsDirectory.path
		let scriptPath = splashModelsScriptPath
		let pythonPath = splashPythonPath

		Task.detached(priority: .userInitiated) {
			guard !scriptPath.isEmpty, FileManager.default.fileExists(atPath: scriptPath) else {
				await MainActor.run {
					self.installLogs.append("Error: No se encontró script de instalación en \(scriptPath).")
					self.installLogs.append("Asegúrate de que Splash esté instalado vía: brew install incoai/tap/splash")
					self.isInstalling = false
					self.installSuccess = false
					self.downloadSpeedMBs = 0.0
					self.downloadPhase = "Fallo en la instalación"
				}
				return
			}

			func runPrepareProcess(withLanguageOnly: Bool) -> (success: Bool, logs: [String]) {
				let process = Process()
				process.executableURL = URL(fileURLWithPath: pythonPath)
				var args = ["-u", scriptPath, "--models", modelsPath, "--model", effectiveRepoId]
				if withLanguageOnly {
					args.append("--language-only")
				}
				args.append("prepare")
				process.arguments = args

				var env = ProcessInfo.processInfo.environment
				env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
				if env["HF_TOKEN"] == nil || env["HF_TOKEN"]?.isEmpty == true {
					let hfTokenURL = FileManager.default.homeDirectoryForCurrentUser
						.appendingPathComponent(".cache/huggingface/token")
					if let token = try? String(contentsOf: hfTokenURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
						env["HF_TOKEN"] = token
					}
				}
				process.environment = env

				let pipe = Pipe()
				process.standardOutput = pipe
				process.standardError = pipe

				final class LogCollector: @unchecked Sendable {
					private let lock = NSLock()
					private var logs: [String] = []
					func append(_ lines: [String]) {
						lock.lock()
						logs.append(contentsOf: lines)
						lock.unlock()
					}
					func getLogs() -> [String] {
						lock.lock()
						defer { lock.unlock() }
						return logs
					}
				}

				let collector = LogCollector()

				let outHandle = pipe.fileHandleForReading
				outHandle.readabilityHandler = { handle in
					let data = handle.availableData
					guard !data.isEmpty else { return }
					let rawText = String(decoding: data, as: UTF8.self)
					let rawLines = rawText.components(separatedBy: CharacterSet.newlines)
						.map { $0.trimmingCharacters(in: .whitespaces) }
						.filter { !$0.isEmpty }

					guard !rawLines.isEmpty else { return }
					collector.append(rawLines)

					Task { @MainActor in
						for line in rawLines {
							let clean = line.replacingOccurrences(of: "\\x1b\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
							if clean.isEmpty { continue }

							if clean.contains("Fetching ") && clean.contains("GB") {
								self.installLogs.append("ℹ️ \(clean)")
								self.installLogs.append("⏳ Conectando y transfiriendo archivos grandes en paralelo...")

								if let match = clean.range(of: "[0-9.]+\\s*GB", options: .regularExpression) {
									let gbSubstring = clean[match].replacingOccurrences(of: "GB", with: "").trimmingCharacters(in: .whitespaces)
									if let gbVal = Double(gbSubstring) {
										self.totalExpectedBytes += Int64(gbVal * 1_073_741_824.0)
									}
								}

								if clean.contains("DFlash2") {
									self.downloadPhase = "Descargando acelerador DFlash2..."
								} else {
									self.downloadPhase = "Descargando pesos del modelo..."
								}
								continue
							}

							if clean.contains("Installing ") && clean.contains("as ") {
								self.downloadPhase = "Ensamblando y verificando en Splash..."
								self.downloadProgressFraction = 0.99
							}

							let isFileCounter = clean.contains("Fetching ") && clean.contains("%|")
							let isByteCounter = clean.contains("Downloading bytes") || clean.contains("it/s")

							if isFileCounter {
								if let last = self.installLogs.last, last.contains("Fetching ") && last.contains("%|") {
									self.installLogs[self.installLogs.count - 1] = clean
								} else {
									self.installLogs.append(clean)
								}
							} else if isByteCounter {
								if let last = self.installLogs.last, (last.contains("Downloading bytes") || last.contains("it/s")) {
									self.installLogs[self.installLogs.count - 1] = clean
								} else {
									self.installLogs.append(clean)
								}
							} else {
								self.installLogs.append(clean)
							}
						}
					}
				}

				Task { @MainActor in
					self.installProcess = process
				}

				let hubDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub")

				func currentHubSize() -> Int64 {
					guard let enumerator = FileManager.default.enumerator(at: hubDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
					var total: Int64 = 0
					while let fileURL = enumerator.nextObject() as? URL {
						if let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
							total += Int64(res.fileSize ?? 0)
						}
					}
					return total
				}

				let initialHubSize = currentHubSize()

				final class SpeedTracker: @unchecked Sendable {
					private let lock = NSLock()
					private var lastBytes: Int64 = 0
					private var lastTime = Date()
					private var smoothedSpeed: Double = 0.0

					func update(current: Int64) -> Double {
						lock.lock()
						defer { lock.unlock() }
						let now = Date()
						let dt = now.timeIntervalSince(lastTime)
						guard dt >= 0.5 else { return smoothedSpeed }
						let delta = max(0, current - lastBytes)
						let instantSpeed = Double(delta) / (dt * 1_048_576.0)
						smoothedSpeed = smoothedSpeed == 0.0 ? instantSpeed : (smoothedSpeed * 0.4 + instantSpeed * 0.6)
						lastBytes = current
						lastTime = now
						return smoothedSpeed
					}
				}

				let speedTracker = SpeedTracker()

				let monitorTask = Task.detached(priority: .utility) {
					while !Task.isCancelled {
						try? await Task.sleep(nanoseconds: 800_000_000)
						if Task.isCancelled { break }
						let currentSize = currentHubSize()
						let downloaded = max(0, currentSize - initialHubSize)
						let speed = speedTracker.update(current: downloaded)

						await MainActor.run {
							self.downloadedBytes = downloaded
							self.downloadSpeedMBs = speed
							if self.totalExpectedBytes > 0 {
								self.downloadProgressFraction = min(0.99, max(0.01, Double(downloaded) / Double(self.totalExpectedBytes)))
							}
						}
					}
				}

				do {
					try process.run()
					process.waitUntilExit()
					monitorTask.cancel()
					outHandle.readabilityHandler = nil
					return (process.terminationStatus == 0, collector.getLogs())
				} catch {
					monitorTask.cancel()
					outHandle.readabilityHandler = nil
					return (false, collector.getLogs())
				}
			}

			var (success, logs) = runPrepareProcess(withLanguageOnly: initialLangOnly)

			// Auto-fallback: Si falló porque no tiene proyector mmproj y no se había usado languageOnly, reintentar con --language-only
			if !success && !initialLangOnly {
				let joinedLogs = logs.joined(separator: " ").lowercased()
				if joinedLogs.contains("vision projector") || joinedLogs.contains("mmproj") || joinedLogs.contains("--language-only") {
					await MainActor.run {
						self.installLogs.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
						self.installLogs.append("ℹ️ Detectado modelo sin componentes de visión (mmproj).")
						self.installLogs.append("🔄 Reintentando preparación automáticamente con --language-only...")
						self.installLogs.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
					}
					let secondPass = runPrepareProcess(withLanguageOnly: true)
					success = secondPass.success
				}
			}

			let finalSuccess = success
			await MainActor.run {
				if self.isInstallCancelled {
					return
				}
				self.installProcess = nil
				self.isInstalling = false
				self.installSuccess = finalSuccess
				self.downloadSpeedMBs = 0.0
				if finalSuccess {
					self.downloadProgressFraction = 1.0
					self.downloadPhase = "Instalación completada con éxito"
					self.installLogs.append("✅ Instalación y verificación de \(effectiveRepoId) completada con éxito.")
					self.refreshInstalledModels()
				} else {
					self.downloadPhase = "Fallo en la instalación"
					self.installLogs.append("❌ Error al instalar \(effectiveRepoId).")
					if self.installLogs.contains(where: { $0.contains("loads from a GGUF only") }) {
						self.installLogs.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
						self.installLogs.append("💡 La arquitectura Qwen3.8-Flash-Next en Splash requiere formato GGUF.")
						self.installLogs.append("👉 El repositorio base 'Qwen/Qwen3.8-Flash-Next' contiene pesos safetensors incompatibles con Splash.")
						self.installLogs.append("👉 Instala la cuantización oficial compatible con Splash:")
						self.installLogs.append("   ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:Q2_0")
						self.installLogs.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
					} else if self.installLogs.contains(where: { $0.contains("gated repo") || $0.contains("Access to model") || $0.contains("403") }) {
						self.installLogs.append("🔒 Este modelo tiene acceso restringido ('Gated') en Hugging Face.")
						self.installLogs.append("💡 Muchos modelos protegidos tienen aprobación instantánea ('auto').")
						self.installLogs.append("👉 Pasos para habilitar la descarga:")
						self.installLogs.append("   1. Inicia sesión en Hugging Face con tu cuenta.")
						self.installLogs.append("   2. Visita: https://huggingface.co/\(effectiveRepoId)")
						self.installLogs.append("   3. Pulsa 'Agree and access repository' (o Aceptar términos).")
						self.installLogs.append("   4. Regresa a Splash Monitor y haz clic nuevamente en Descargar.")
					} else if self.installLogs.contains(where: { $0.contains("HTTP Error 500") || $0.contains("Error 502") || $0.contains("Error 503") || $0.contains("Error 504") || $0.contains("check your connection") }) {
						self.installLogs.append("⚠️ Interrupción temporal en los servidores de Hugging Face o en la red (Error 500 / Timeout).")
						self.installLogs.append("💾 ¡Los archivos ya transferidos están a salvo en la caché local (~17 GB guardados)!")
						self.installLogs.append("👉 Solo pulsa 'Descargar' de nuevo; el proceso reanudará al instante solo lo que falta.")
					}
				}
			}
		}
	}

	func cancelModelInstall() {
		isInstallCancelled = true
		installProcess?.terminate()
		installProcess = nil
		isInstalling = false
		installSuccess = false
		downloadSpeedMBs = 0.0
		downloadProgressFraction = nil
		downloadPhase = "Descarga cancelada por el usuario"
		installLogs.append("⚠️ Descarga cancelada por el usuario.")
	}

	// MARK: - Server Control

	func stopServerAsync() async {
		previousRunningState = false
		await terminator.stopEngine(port: activePort, candidatePids: candidateStopPIDs())
		self.isRunning = false
		self.status = nil
		self.activePid = nil
		self.speedHistory.removeAll()
		timer?.invalidate()
		// P-02: el sondeo no puede quedar muerto. Se deja un vigía lento que detecta
		// cualquier motor que arranque después (desde la app, la terminal o un agente).
		ensureWatchdog()
		cleanStaleLocks()
		// §3.4: `status` quedó nulo; limpiar también las cachés derivadas.
		updateStatusDerivedCaches()
	}

	func stopServer() {
		Task {
			await stopServerAsync()
		}
	}

	/// Detención síncrona para `applicationWillTerminate` (sin async, sin Task).
	/// Solo señaliza procesos verificados como motor (P-01): antes ejecutaba
	/// `pkill -INT -f "splash serve"`, que alcanza cualquier proceso cuya línea de
	/// comandos contenga esa cadena, y después aplicaba `SIGKILL` a todo lo que
	/// `lsof -ti :<puerto>` devolviese, incluidos los clientes conectados.
	func stopServerSync() {
		terminator.stopEngineSynchronously(port: activePort, candidatePids: candidateStopPIDs())
		for url in lockFileURLs(port: activePort) where FileManager.default.fileExists(atPath: url.path) {
			try? FileManager.default.removeItem(at: url)
		}
	}

	/// Reset all published state — releases memory
	func resetState() {
		speedHistory.removeAll()
		status = nil
		isRunning = false
		activePid = nil
		installedModels.removeAll()
		availableOnlineModels.removeAll()
		installedAgents.removeAll()
		connectedApps.removeAll()
		knownClientsSession.removeAll()
		lastError = nil
		isStartingServer = false
		startingModelId = nil
		isInstalling = false
		installingModelId = nil
		installLogs.removeAll()
		installSuccess = nil
		isInstallingDependency = false
		dependencyInstallLogs.removeAll()
		dependencyInstallSuccess = nil
		portConflict = nil
		timer?.invalidate()
		watchdog?.invalidate()
		watchdog = nil
		sizeCache.invalidateAll()
		ticksSinceModelRefresh = 0
		// §3.4: cachés derivadas de `status` y contadores de clientes.
		updateStatusDerivedCaches()
		activeClientCount = 0
		totalSockets = 0
	}

	/// Detiene el motor del puerto indicado. Delega en el terminador endurecido:
	/// solo escuchas verificadas del motor y escalada INT → TERM → KILL.
	func killSplashProcesses(port: Int) async {
		await terminator.stopEngine(port: port, candidatePids: candidateStopPIDs())
	}

	/// PIDs candidatos a detener: el proceso activo y los declarados por bloqueos vivos.
	/// Nunca se amplía con «todo lo que escuche en el puerto».
	func candidateStopPIDs() -> [Int32] {
		var pids: [Int32] = []
		if let pid = activePid, pid > 0 { pids.append(Int32(pid)) }
		for url in lockCandidateURLs() {
			guard let lock = ServeLockStore.decode(try? Data(contentsOf: url)), lock.pid > 0 else { continue }
			pids.append(Int32(lock.pid))
		}
		return pids
	}

	/// PID declarado por el bloqueo vivo del motor, si existe (P-08).
	func readLockPid() -> Int? {
		for url in lockCandidateURLs() {
			guard let lock = ServeLockStore.decode(try? Data(contentsOf: url)), lock.pid > 0 else { continue }
			if kill(Int32(lock.pid), 0) == 0 { return lock.pid }
		}
		return nil
	}

	func isPortListening(port: Int) -> Bool {
		var addr = sockaddr_in()
		addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
		addr.sin_family = sa_family_t(AF_INET)
		addr.sin_port = in_port_t(port).bigEndian
		inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

		let sock = socket(AF_INET, SOCK_STREAM, 0)
		guard sock >= 0 else { return false }
		defer { close(sock) }

		var yes: Int32 = 1
		setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

		let result = withUnsafePointer(to: &addr) {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
				Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.stride))
			}
		}
		return result != 0
	}

	func findSuggestedFreePort(preferred: Int? = nil) -> Int {
		var candidates: [Int] = []
		if let pref = preferred, pref > 1024, pref <= 65535 {
			candidates.append(pref)
		}
		for p in [8000, 8001, 8005, 8008, 8080, 8088, 8888, 9000, 9005] {
			if !candidates.contains(p) {
				candidates.append(p)
			}
		}
		for port in candidates {
			if !isPortListening(port: port) {
				return port
			}
		}
		for p in 8001...8100 {
			if !isPortListening(port: p) {
				return p
			}
		}
		return 8000
	}

	/// §7: `lsof`/`ps` corren fuera del actor principal (antes eran `Process`
	/// síncronos con `waitUntilExit` en la ruta de arranque de la UI).
	func detectPortConflict(port: Int) async -> PortConflictInfo? {
		guard isPortListening(port: port) else { return nil }
		let currentSplashPid = activePid
		let lockPid = readLockPid()

		let found: (pid: Int32, comm: String)? = await Task.detached(priority: .userInitiated) {
			let lsof = CommandRunner.run("/usr/sbin/lsof", ["-iTCP:\(port)", "-sTCP:LISTEN", "-t"])
			let output = lsof.output.trimmingCharacters(in: .whitespacesAndNewlines)
			guard let firstLine = output.components(separatedBy: .newlines).first,
				  let pid = Int32(firstLine), pid > 0 else {
				return nil
			}
			let ps = CommandRunner.run("/bin/ps", ["-p", "\(pid)", "-o", "comm="])
			return (pid: pid,
					comm: ps.output.trimmingCharacters(in: .whitespacesAndNewlines))
		}.value

		guard let conflict = found else { return nil }
		let pid = conflict.pid
		if let currentSplashPid, Int32(currentSplashPid) == pid {
			return nil
		}
		if let lockPid, Int32(lockPid) == pid {
			return nil
		}
		let rawComm = conflict.comm
		if rawComm.localizedCaseInsensitiveContains("splash") {
			return nil
		}

		var friendlyName = (rawComm as NSString).lastPathComponent
		if friendlyName.isEmpty { friendlyName = "Proceso desconocido" }

		let suggested = findSuggestedFreePort(preferred: port == 8000 ? 8001 : port + 1)
		return PortConflictInfo(port: port, processName: friendlyName, pid: pid, suggestedPort: suggested)
	}

	func resolvePortConflict(killProcess: Bool) {
		guard let conflict = portConflict else { return }
		let targetPort = conflict.port
		self.portConflict = nil
		if killProcess {
			// Reverificación de identidad antes de señalizar: entre la detección y la
			// confirmación del usuario el PID puede haberse reciclado por otro proceso
			// (incluido el propio motor). `SIGTERM` primero; `SIGKILL` solo si persiste.
			let comm = CommandRunner.run("/bin/ps", ["-p", "\(conflict.pid)", "-o", "comm="])
				.output.trimmingCharacters(in: .whitespacesAndNewlines)
			if !SplashEngineIdentity.isEngineCommand(comm) {
				kill(conflict.pid, SIGTERM)
				usleep(250_000)
				if kill(conflict.pid, 0) == 0 {
					kill(conflict.pid, SIGKILL)
				}
			}
			startServer(model: selectedModelForLaunch, port: targetPort)
		} else {
			self.isStartingServer = false
			self.startingModelId = nil
		}
	}

	func useSuggestedPort(_ newPort: Int) {
		self.portConflict = nil
		self.activePort = newPort
		startServer(model: selectedModelForLaunch, port: newPort)
	}

	func startServer(model: String, port: Int = 8000) {
		guard isSplashInstalled else {
			installSplashDependency()
			return
		}

		// P-03: el identificador de modelo se interpola dentro de un script de shell.
		// Sin validación, un valor con comillas cerraba el entrecomillado y ejecutaba
		// comandos arbitrarios (verificado en la auditoría con un fichero testigo).
		guard let validatedModel = ModelIDValidator.normalized(model) else {
			self.lastError = ModelIDValidator.rejectionReason(model) ?? "Identificador de modelo no válido."
			self.isStartingServer = false
			self.startingModelId = nil
			return
		}
		guard (1...65535).contains(port) else {
			self.lastError = "Puerto fuera de rango: \(port)"
			self.isStartingServer = false
			self.startingModelId = nil
			return
		}

		self.activePort = port
		Preferences.lastUsedPort = port
		self.selectedModelForLaunch = model

		// 1. Pre-flight check for port conflict with third-party software.
		// §7: lsof/ps fuera del actor principal; el arranque continúa por la
		// misma ruta asíncrona (un conflicto aborta antes de crear el proceso).
		if !skipPortConflictCheck {
			let checkPort = port
			Task { [weak self] in
				guard let self else { return }
				if let conflict = await self.detectPortConflict(port: checkPort) {
					self.portConflict = conflict
					self.isStartingServer = false
					self.startingModelId = nil
					return
				}
				self.launchServerProcess(model: validatedModel, port: checkPort)
			}
		} else {
			self.launchServerProcess(model: validatedModel, port: port)
		}
	}

	/// Proceso de arranque tras superar el pre-flight de conflicto de puerto.
	private func launchServerProcess(model: String, port: Int) {
		let validatedModel = model
		self.isStartingServer = true
		self.startingModelId = model

		Task {
			// Limpieza de bloqueos muertos antes de arrancar (P-08).
			self.cleanStaleLocks()

			// Ensure any existing splash process on this port is cleared
			await killSplashProcesses(port: port)

			let splashPath = self.splashExecutablePath

			// Aliases de modelos Anthropic, OpenAI y de la familia Splash/IncoAI
			let baseModelAliases = [
				// Familia Oficial Splash 1.3.1 / 1.3.2 (NVFP4, FP8, MLX Community y modelos base)
				"nvidia/Qwen3.8-27B-NVFP4",
				"mlx-community/Qwen3.6-35B-A3B-nvfp4",
				"mlx-community/Qwen3.8-27B-nvfp4",
				"Qwen3.8-27B-NVFP4",
				"Qwen3.6-35B-A3B-nvfp4",
				"mlx-community/Qwen3.8-27B-4bit",
				"mlx-community/Qwen3.6-35B-A3B-4bit",
				"mlx-community/Qwen3.8-27B-8bit",
				"Qwen3.8-27B-4bit",
				"Qwen3.6-35B-A3B-4bit",
				// Familia Splash 1.4.0 (Qwen3.8-Flash-Next)
				"ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:Q2_0",
				"ISTA-DASLab/Qwen3.8-Flash-Next",
				"Qwen3.8-Flash-Next",
				"Qwen3.8-Flash-Next-GGUF",
				// Familia Splash 1.4.1 — Ornith-1.5-122B (GGUF con visión + MLX)
				"unsloth/Ornith-1.5-122B-GGUF:UD-Q4_K_XL",
				"ornith-ai/Ornith-1.5-122B-MLX-4bit",
				"Ornith-1.5-122B",
				// Familia Splash 1.4.1 — Flint 40B-A2.5B MoE (GGUF, 262K tokens)
				"unsloth/flint-GGUF:UD-Q4_K_XL",
				"incoai/Flint-DFlash2",
				"RecursiveSI/Flint",
				"Flint",
				// Familia IncoAI / Splash (resuelve clientes configurados con modelos nativos de Splash heredados)
				"incoai/Qwen3.6-35B-A3B-Splash",
				"incoai/Qwen3.8-27B-Splash",
				"incoai/Qwen3.5-35B-A3B-Splash",
				"incoai/Qwen2.5-Coder-32B-Instruct",
				"Qwen3.6-35B-A3B-Splash",
				"Qwen3.8-27B-Splash",
				// Familia OpenAI & ChatGPT (Desktop Codex / OWL, Chatbox, Cursor)
				"gpt-4o",
				"gpt-4o-mini",
				"gpt-4",
				"gpt-4-turbo",
				"gpt-3.5-turbo",
				"o1",
				"o1-preview",
				"o1-mini",
				"o3-mini",
				"codex",
				"chatgpt",
				"default",
				// Familia Sonnet (Pestaña Code / CCD y Cowork)
				"claude-sonnet-4-6",
				"claude-sonnet-5",
				"claude-sonnet-5-5",
				"claude-sonnet-4-5",
				"claude-3-7-sonnet-latest",
				"claude-3-7-sonnet-20250219",
				"claude-3-5-sonnet-latest",
				"claude-3-5-sonnet-20241022",
				"claude-3-5-sonnet-20240620",
				// Familia Haiku
				"claude-haiku-4-5",
				"claude-haiku-4-5-20251001",
				"claude-3-5-haiku-latest",
				"claude-3-5-haiku-20241022",
				"claude-3-haiku-20240307",
				// Familia Opus
				"claude-opus-4-7",
				"claude-opus-5",
				"claude-opus-5-5",
				"claude-3-opus-latest",
				"claude-3-opus-20240229",
				// Familia Fable
				"claude-fable-5",
				"claude-fable-5-1"
			]

			var allAliases = Set(baseModelAliases)

			// Agregar TODOS los modelos instalados localmente para que cualquier cliente pueda solicitar cualquiera de ellos sin 404
			for installed in self.installedModels {
				allAliases.insert(installed.repoId)
			}

			let codexConfigURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/config.toml")
			if let configData = try? String(contentsOf: codexConfigURL, encoding: .utf8) {
				for line in configData.components(separatedBy: .newlines) {
					let trimmed = line.trimmingCharacters(in: .whitespaces)
					if trimmed.hasPrefix("model") && trimmed.contains("=") && !trimmed.hasPrefix("model_") {
						let parts = trimmed.split(separator: "=", maxSplits: 1).map { String($0) }
						if parts.count == 2 {
							let val = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
							if !val.isEmpty {
								allAliases.insert(val)
							}
						}
					}
				}
			}

			let aliasFlags = allAliases
				.filter { $0 != validatedModel }
				.sorted()
				.map { "--served-model-name \"\($0)\"" }
				.joined(separator: " ")

			// Opciones de red, allowed-hosts y contexto (--host, --allowed-host y --max-context)
			let hostFlag = Preferences.listenOnAllInterfaces ? "--host \"0.0.0.0\"" : "--host \"127.0.0.1\""

			var allowedHostFlags = ""
			var parsedAllowedHosts: [String] = []
			if Preferences.listenOnAllInterfaces {
				let userHosts = Preferences.allowedHosts
					.components(separatedBy: CharacterSet(charactersIn: ",; \n\t"))
					.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
					.filter { !$0.isEmpty }

				let hostAllowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-_")
				for host in userHosts where host.unicodeScalars.allSatisfy({ hostAllowedChars.contains($0) }) {
					if !parsedAllowedHosts.contains(host) {
						parsedAllowedHosts.append(host)
					}
				}

				if !parsedAllowedHosts.isEmpty {
					allowedHostFlags = parsedAllowedHosts.map { "--allowed-host \"\($0)\"" }.joined(separator: " ")
				}
			}

			// Orígenes permitidos (CORS para extensiones de Chrome, web local y webviews: --allowed-origin "*")
			var allowedOriginFlags = ""
			let trimmedOrigin = Preferences.allowedOrigins.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmedOrigin.isEmpty {
				if trimmedOrigin == "*" {
					allowedOriginFlags = "--allowed-origin \"*\""
				} else {
					let originTokens = trimmedOrigin
						.components(separatedBy: CharacterSet(charactersIn: ",; \n\t"))
						.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
						.filter { !$0.isEmpty }
					let originAllowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:/-_*")
					var validOrigins: [String] = []
					for origin in originTokens where origin.unicodeScalars.allSatisfy({ originAllowedChars.contains($0) }) {
						if !validOrigins.contains(origin) {
							validOrigins.append(origin)
						}
					}
					if !validOrigins.isEmpty {
						allowedOriginFlags = validOrigins.map { "--allowed-origin \"\($0)\"" }.joined(separator: " ")
					}
				}
			} else {
				allowedOriginFlags = "--allowed-origin \"*\""
			}

			var contextFlag = ""
			let trimmedContext = Preferences.maxContext.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmedContext.isEmpty && trimmedContext.lowercased() != "auto" {
				let allowedChars = CharacterSet(charactersIn: "0123456789kmKM")
				if trimmedContext.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) {
					contextFlag = "--max-context \"\(trimmedContext.uppercased())\""
				}
			}

			var idleReleaseFlag = ""
			let trimmedIdle = Preferences.idleRelease.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmedIdle.isEmpty {
				if let validIdle = ServerCLIValidator.validateIdleRelease(trimmedIdle) {
					idleReleaseFlag = "--idle-release \"\(validIdle)\""
				}
			}

			var maxMemoryFlag = ""
			let trimmedMaxMem = Preferences.maxMemory.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmedMaxMem.isEmpty && trimmedMaxMem.lowercased() != "auto" {
				if let validMem = ServerCLIValidator.validateMaxMemory(trimmedMaxMem) {
					maxMemoryFlag = "--max-memory \"\(validMem)\""
				}
			}

			let languageFlag = Preferences.languageOnly ? "--language-only" : ""

			var stateFormatFlag = ""
			let trimmedState = Preferences.stateFormat.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			if trimmedState == "bf16" {
				stateFormatFlag = "--state-format \"bf16\""
			}

			var thinkingBudgetFlag = ""
			let trimmedThinking = Preferences.thinkingTokenBudget.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			if trimmedThinking == "off" || trimmedThinking == "-1" {
				thinkingBudgetFlag = "--thinking-token-budget \"-1\""
			} else if !trimmedThinking.isEmpty && trimmedThinking != "auto" {
				let clean = trimmedThinking.replacingOccurrences(of: "k", with: "000")
				if let num = Int(clean), num > 0 {
					thinkingBudgetFlag = "--thinking-token-budget \"\(num)\""
				}
			}

			let persistentCacheFlag = Preferences.persistentCache ? "--persistent-cache" : ""

			var verifyRowsFlag = ""
			let trimmedVerifyRows = Preferences.verifyRows.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			if trimmedVerifyRows == "all" {
				verifyRowsFlag = "--verify-rows \"all\""
			}

			var expertMemoryFlag = ""
			let trimmedExpertMem = Preferences.expertMemory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			if !trimmedExpertMem.isEmpty && trimmedExpertMem != "auto" {
				if trimmedExpertMem == "off" || ServerCLIValidator.validateMaxMemory(trimmedExpertMem.uppercased()) != nil {
					expertMemoryFlag = "--expert-memory \"\(trimmedExpertMem)\""
				}
			}

			// Flags CLI adicionales proporcionados por el usuario (ej. --no-webui --max-cache-disk 50GB)
			let (customTokens, customError) = ServerCLIValidator.validateAndTokenize(Preferences.customServerFlags)
			if let err = customError {
				logger.warning("Flags CLI adicionales ignorados por seguridad: \(err, privacy: .public)")
			}
			let customFlagsString = customTokens.joined(separator: " ")
			let customFlagsEcho = customTokens.isEmpty ? "" : "\necho \"🛠️ Flags CLI:  \(customFlagsString)\""

			let extraOptions = [hostFlag, allowedHostFlags, allowedOriginFlags, contextFlag, idleReleaseFlag, maxMemoryFlag, languageFlag, stateFormatFlag, thinkingBudgetFlag, persistentCacheFlag, verifyRowsFlag, expertMemoryFlag, customFlagsString].filter { !$0.isEmpty }.joined(separator: " ")
			let trimmedStartModel = validatedModel.trimmingCharacters(in: .whitespacesAndNewlines)
			let effectiveLaunchModel: String
			if trimmedStartModel.lowercased() == "qwen/qwen3.8-flash-next" || trimmedStartModel.lowercased() == "qwen3.8-flash-next" {
				effectiveLaunchModel = "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:Q2_0"
			} else {
				effectiveLaunchModel = trimmedStartModel
			}
			let runCmd = "\"\(splashPath)\" serve --model \"\(effectiveLaunchModel)\" --port \"\(port)\" \(extraOptions) \(aliasFlags)"

			let hostLabel = Preferences.listenOnAllInterfaces ? "0.0.0.0 (Toda la red local / LAN)" : "127.0.0.1 (Solo localhost)"
			let contextLabel = (trimmedContext.isEmpty || trimmedContext.lowercased() == "auto") ? "Automático (por memoria)" : trimmedContext.uppercased()
			let idleLabel = (trimmedIdle.isEmpty || trimmedIdle == "10m") ? "10m (Por defecto)" : (trimmedIdle.lowercased() == "off" ? "Desactivado (Siempre en RAM)" : trimmedIdle)
			let memoryLabel = (trimmedMaxMem.isEmpty || trimmedMaxMem.lowercased() == "auto") ? "Automático (sin límite)" : trimmedMaxMem.uppercased()
			let modalityLabel = Preferences.languageOnly ? "Solo Texto / Código (--language-only)" : "Multimodal (Texto y Visión)"
			let allowedHostsEcho = parsedAllowedHosts.isEmpty ? "" : "\necho \"🛡️ Dominios: \(parsedAllowedHosts.joined(separator: ", "))\""
			let originEcho = !allowedOriginFlags.isEmpty ? "\necho \"🌍 Orígenes:  \(trimmedOrigin.isEmpty ? "*" : trimmedOrigin) (--allowed-origin)\"" : ""
			let stateEcho = (trimmedState == "bf16") ? "\necho \"⚡️ Estado GDN: BF16 (-50% RAM)\"" : ""
			let thinkingEcho = (trimmedThinking != "auto" && !trimmedThinking.isEmpty) ? "\necho \"💭 Thinking:  \(Preferences.thinkingTokenBudget)\"" : ""
			let cacheEcho = Preferences.persistentCache ? "\necho \"💾 Caché SSD:  Persistente activada\"" : ""
			let verifyEcho = (trimmedVerifyRows == "all") ? "\necho \"🎯 Verificación: Todas las filas (--verify-rows all)\"" : ""
			let expertMemEcho = (!expertMemoryFlag.isEmpty) ? "\necho \"🧠 Memoria Expertos MoE: \(trimmedExpertMem)\"" : ""

			let cmd = """
			echo "🌊 ==============================================="
			echo "🚀 Iniciando Servidor Splash..."
			echo "📦 Modelo:   \(validatedModel)"
			echo "🔌 Puerto:   \(port)"
			echo "🌐 Red/Host: \(hostLabel)"\(allowedHostsEcho)\(originEcho)
			echo "🧠 Contexto: \(contextLabel)"
			echo "⏳ Inactividad: \(idleLabel)"
			echo "💾 Límite RAM: \(memoryLabel)"
			echo "👁️ Modalidad: \(modalityLabel)"\(stateEcho)\(thinkingEcho)\(cacheEcho)\(verifyEcho)\(expertMemEcho)\(customFlagsEcho)
			echo "⚡️ Motor:    \(splashPath)"
			echo "==============================================="
			echo "Presiona Ctrl+C en esta ventana para detener el servidor."
			echo ""
			\(runCmd)
			EXIT_CODE=$?
			if [ $EXIT_CODE -ne 0 ]; then
				echo ""
				echo "⚠️ Splash finalizó con código de salida: $EXIT_CODE"
				echo "Presiona Enter para cerrar esta ventana..."
				read -r
			fi
			"""

			if let override = self.serverLaunchOverride {
				let logURL = Preferences.runInBackground ? self.serverLogURL : nil
				override(cmd, logURL, Preferences.runInBackground)
			} else if Preferences.runInBackground {
				let logsDir = self.dataDirectory.appendingPathComponent("logs")
				try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
				let logFileURL = self.serverLogURL

				let scriptURL = self.dataDirectory.appendingPathComponent("start_splash.command")
				let fullScript = """
				#!/bin/bash
				\(cmd)
				"""
				try? fullScript.write(to: scriptURL, atomically: true, encoding: .utf8)
				try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

				let proc = Process()
				proc.executableURL = URL(fileURLWithPath: "/bin/bash")
				proc.arguments = ["-c", "\"\(scriptURL.path)\" > \"\(logFileURL.path)\" 2>&1 &"]
				try? proc.run()
				proc.waitUntilExit()
			} else {
				self.runInTerminal(
					command: cmd,
					title: "Splash Server - \(validatedModel)",
					scriptFileName: "start_splash.command"
				)
			}

			// Poll for up to 30 intervals (24 seconds) to detect server startup
			for _ in 0..<30 {
				try? await Task.sleep(nanoseconds: 800_000_000)
				await self.checkServerStatus()
				if self.isRunning { break }
			}

			// P-13: política única de entorno — se sincroniza SIEMPRE, también en 8000,
			// porque los agentes de terminal necesitan SPLASH_PORT/ANTHROPIC_BASE_URL.
			// Antes esta ruta borraba el entorno en 8000 mientras checkServerStatus() lo
			// escribía para el mismo puerto: dos reglas opuestas.
			if self.isRunning {
				self.syncShellEnvironment(port: port)
				self.restorePollingAfterDetection()
			} else {
				// El motor no confirmó: mantener la app sensible a un arranque tardío (P-02).
				self.ensureWatchdog()
			}

			self.isStartingServer = false
			self.startingModelId = nil
		}
	}

	func switchModel(to model: String) {
		// Si el modelo y puerto son los mismos, solo reiniciar
		// Si el puerto cambió, reiniciar con el nuevo puerto
		startServer(model: model, port: activePort)
	}

	// MARK: - Shell Environment Sync

	/// Escribe `SPLASH_PORT` y las URL base del motor en `~/.splash_monitor_env` y añade
	/// el `source` a `~/.zshrc`.
	///
	/// P-09: escribir fuera del directorio de datos exige consentimiento explícito.
	/// Antes la app modificaba `~/.zshrc` sin avisar y solo se podía deshacer a mano.
	/// P-13: política única — el entorno se sincroniza siempre (también en 8000).
	var pendingShellConfigPort: Int?

	func syncShellEnvironment(port: Int) {
		guard ShellEnvironment.shouldSync(port: port) else { return }
		let home = shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
		let envFile = home.appendingPathComponent(ShellEnvironment.fileName)
		try? ShellEnvironment.fileContents(port: port).write(to: envFile, atomically: true, encoding: .utf8)

		let targetModel = !self.activeModel.isEmpty && self.activeModel != "Ninguno" ? self.activeModel : self.selectedModelForLaunch
		syncCodexEnvironment(model: targetModel, port: port)

		switch ShellConsent.decide(hasConsent: Preferences.shellConfigConsent, userDeclined: Preferences.shellConfigDeclined) {
		case .write:
			injectShellSource(envFile: envFile)
		case .askUser:
			// La interfaz muestra el aviso; el fichero de entorno ya está escrito.
			if pendingShellConfigPort != port { pendingShellConfigPort = port }
		case .skip:
			break
		}
	}

	/// Añade la línea `source` a `~/.zshrc` si no está ya (idempotente).
	func injectShellSource(envFile: URL) {
		let home = shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
		let zshrc = home.appendingPathComponent(".zshrc")
		let contents = (try? String(contentsOf: zshrc, encoding: .utf8)) ?? ""
		guard ShellEnvironment.needsInjection(into: contents) else { return }
		let updated = contents + ShellEnvironment.injectionBlock(envFilePath: envFile.path)
		if let override = shellWriteOverride {
			override(updated, zshrc)
		} else {
			try? updated.write(to: zshrc, atomically: true, encoding: .utf8)
		}
	}

	/// Respuesta del usuario al aviso de configuración del shell (P-09).
	func resolveShellConfigPrompt(allow: Bool) {
		Preferences.shellConfigConsent = allow
		Preferences.shellConfigDeclined = !allow
		guard allow, let port = pendingShellConfigPort else {
			pendingShellConfigPort = nil
			return
		}
		pendingShellConfigPort = nil
		let envFile = (shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser)
			.appendingPathComponent(ShellEnvironment.fileName)
		try? ShellEnvironment.fileContents(port: port).write(to: envFile, atomically: true, encoding: .utf8)
		injectShellSource(envFile: envFile)
	}

	/// Revierte por completo el efecto de `syncShellEnvironment`: quita la inyección de
	/// `~/.zshrc` (reversión exacta, no heurística) y borra el fichero de entorno.
	func clearShellEnvironment() {
		let home = shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
		let envFile = home.appendingPathComponent(ShellEnvironment.fileName)
		let zshrc = home.appendingPathComponent(".zshrc")
		if let contents = try? String(contentsOf: zshrc, encoding: .utf8) {
			let cleaned = ShellEnvironment.removingInjection(from: contents)
			if cleaned != contents {
				if let override = shellWriteOverride {
					override(cleaned, zshrc)
				} else {
					try? cleaned.write(to: zshrc, atomically: true, encoding: .utf8)
				}
			}
		}
		try? FileManager.default.removeItem(at: envFile)
	}

	// MARK: - Sincronización de Codex & ChatGPT Config (~/.codex/config.toml)

	/// Sincroniza el modelo cargado y el puerto activo en ~/.codex/config.toml
	/// para que ChatGPT Desktop (Codex & OWL) trabaje automáticamente con el modelo activo.
	func syncCodexEnvironment(model: String, port: Int) {
		guard !model.isEmpty && model != "Ninguno" else { return }
		let home = shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
		let codexConfigURL = home.appendingPathComponent(".codex/config.toml")
		guard FileManager.default.fileExists(atPath: codexConfigURL.path),
			  let content = try? String(contentsOf: codexConfigURL, encoding: .utf8) else {
			return
		}

		var lines = content.components(separatedBy: .newlines)
		var updated = false
		for (i, line) in lines.enumerated() {
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			if trimmed.hasPrefix("model") && trimmed.contains("=") && !trimmed.hasPrefix("model_") {
				lines[i] = "model = \"\(model)\""
				updated = true
			} else if trimmed.hasPrefix("openai_base_url") && trimmed.contains("=") {
				lines[i] = "openai_base_url = \"http://127.0.0.1:\(port)/v1\""
				updated = true
			}
		}

		if updated {
			let newContent = lines.joined(separator: "\n")
			if let override = shellWriteOverride {
				override(newContent, codexConfigURL)
			} else {
				try? newContent.write(to: codexConfigURL, atomically: true, encoding: .utf8)
			}
		}
	}

	// MARK: - Agent Launcher Helpers

	/// Fast check against the `installedAgents` cache — no filesystem scan,
	/// no Process (§3.5). La detección completa (binarios + presencia de apps
	/// en `/Applications`) la hace `refreshAgentAvailability()` fuera del
	/// hilo principal; antes este método repetía 20–40 `stat` síncronos por
	/// cada evaluación del body de `ServerControlView`.
	func isAgentInstalled(agent: String) -> Bool {
		installedAgents.contains(agent)
	}

	/// Background check — safe to call from any thread
	func refreshAgentAvailability() {
		let agents = ["claude", "opencode", "codex", "hermes", "pi", "dsh"]
		let home = FileManager.default.homeDirectoryForCurrentUser.path

		Task.detached(priority: .utility) {
			var found = Set<String>()
			for agent in agents {
				let candidates = [
					"/opt/homebrew/bin/\(agent)",
					"/usr/local/bin/\(agent)",
					"/usr/bin/\(agent)",
					"\(home)/.npm-global/bin/\(agent)",
					"\(home)/.cargo/bin/\(agent)",
					"\(home)/.local/bin/\(agent)"
				]
				if candidates.contains(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
					found.insert(agent)
				}
			}
			// Detección de Claude Desktop / Cowork en macOS
			if FileManager.default.fileExists(atPath: "/Applications/Claude.app") ||
				FileManager.default.fileExists(atPath: "\(home)/Applications/Claude.app") {
				found.insert("claude-cowork")
			}
			// Detección de ChatGPT Desktop / Codex en macOS
			if FileManager.default.fileExists(atPath: "/Applications/ChatGPT.app") ||
				FileManager.default.fileExists(atPath: "\(home)/Applications/ChatGPT.app") {
				found.insert("chatgpt")
			}
			// Detección de DeepSeek Harness App en macOS
			if FileManager.default.fileExists(atPath: "/Applications/DeepSeek Harness.app") ||
				FileManager.default.fileExists(atPath: "\(home)/Applications/DeepSeek Harness.app") ||
				FileManager.default.fileExists(atPath: "/Applications/DeepSeekHarness.app") ||
				FileManager.default.fileExists(atPath: "\(home)/Applications/DeepSeekHarness.app") {
				found.insert("dsh")
			}
			let result = found
			await MainActor.run {
				self.installedAgents = result
			}
		}
	}

	func agentInstallURL(agent: String) -> URL {
		switch agent {
		case "claude":
			return URL(string: "https://code.claude.com/docs/en/overview")!
		case "claude-cowork":
			return URL(string: "https://claude.ai/download")!
		case "chatgpt":
			return URL(string: "https://openai.com/chatgpt/download/")!
		case "opencode":
			return URL(string: "https://opencode.ai/docs/")!
		case "codex":
			return URL(string: "https://developers.openai.com/codex/cli/")!
		case "hermes":
			return URL(string: "https://hermes-agent.nousresearch.com/docs/getting-started/installation/")!
		case "pi":
			return URL(string: "https://pi.dev/")!
		case "dsh":
			return URL(string: "https://github.com/deepseek-ai/deepseek-harness")!
		default:
			return URL(string: "https://github.com/incoai/splash")!
		}
	}

	/// Agentes que el motor sabe lanzar (`splash <agente>` o app nativa para cowork/chatgpt o dsh).
	static let supportedAgents = ["claude", "claude-cowork", "opencode", "codex", "hermes", "pi", "chatgpt", "dsh"]

	func launchAgent(agent: String) {
		guard isSplashInstalled else {
			installSplashDependency()
			return
		}
		// El nombre del agente se restringe a la lista soportada por el motor.
		guard Self.supportedAgents.contains(agent) else {
			self.lastError = "Agente no soportado: \(agent)"
			return
		}

		// Manejo específico para Claude Desktop / Cowork (App GUI macOS)
		if agent == "claude-cowork" {
			let home = FileManager.default.homeDirectoryForCurrentUser.path
			let appURL = [
				URL(fileURLWithPath: "/Applications/Claude.app"),
				URL(fileURLWithPath: "\(home)/Applications/Claude.app")
			].first(where: { FileManager.default.fileExists(atPath: $0.path) })

			if let targetURL = appURL {
				let config = NSWorkspace.OpenConfiguration()
				config.activates = true
				NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, error in
					if let error = error {
						Task { @MainActor in
							self.lastError = "Error al abrir Claude Cowork: \(error.localizedDescription)"
						}
					}
				}
			} else {
				_ = CommandRunner.run("/usr/bin/open", ["-a", "Claude"])
			}
			return
		}

		// Manejo específico para ChatGPT Desktop / Codex (App GUI macOS)
		if agent == "chatgpt" {
			let targetModel = !self.activeModel.isEmpty && self.activeModel != "Ninguno" ? self.activeModel : self.selectedModelForLaunch
			syncCodexEnvironment(model: targetModel, port: self.activePort)

			let home = FileManager.default.homeDirectoryForCurrentUser.path
			let appURL = [
				URL(fileURLWithPath: "/Applications/ChatGPT.app"),
				URL(fileURLWithPath: "\(home)/Applications/ChatGPT.app")
			].first(where: { FileManager.default.fileExists(atPath: $0.path) })

			if let targetURL = appURL {
				let config = NSWorkspace.OpenConfiguration()
				config.activates = true
				NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, error in
					if let error = error {
						Task { @MainActor in
							self.lastError = "Error al abrir ChatGPT: \(error.localizedDescription)"
						}
					}
				}
			} else {
				_ = CommandRunner.run("/usr/bin/open", ["-a", "ChatGPT"])
			}
			return
		}

		// Manejo específico para DeepSeek Harness (dsh / DeepSeek Harness.app)
		if agent == "dsh" {
			let port = self.activePort
			let home = FileManager.default.homeDirectoryForCurrentUser.path
			let appURL = [
				URL(fileURLWithPath: "/Applications/DeepSeek Harness.app"),
				URL(fileURLWithPath: "\(home)/Applications/DeepSeek Harness.app"),
				URL(fileURLWithPath: "/Applications/DeepSeekHarness.app"),
				URL(fileURLWithPath: "\(home)/Applications/DeepSeekHarness.app")
			].first(where: { FileManager.default.fileExists(atPath: $0.path) })

			if let targetURL = appURL {
				let config = NSWorkspace.OpenConfiguration()
				config.activates = true
				config.environment = [
					"SPLASH_PORT": "\(port)",
					"OPENAI_BASE_URL": "http://127.0.0.1:\(port)/v1",
					"OPENAI_API_KEY": "splash",
					"DEEPSEEK_BASE_URL": "http://127.0.0.1:\(port)/v1",
					"DSH_BASE_URL": "http://127.0.0.1:\(port)/v1"
				]
				NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, error in
					if let error = error {
						Task { @MainActor in
							self.lastError = "Error al abrir DeepSeek Harness: \(error.localizedDescription)"
						}
					}
				}
				return
			}

			// Fallback a CLI / entorno web en Terminal si la app nativa no está presente
			let dshCandidates = [
				"/opt/homebrew/bin/dsh",
				"/usr/local/bin/dsh",
				"\(home)/.npm-global/bin/dsh",
				"\(home)/.local/bin/dsh"
			]
			let dshExec = dshCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })

			let runDshCommand: String
			if let exec = dshExec {
				runDshCommand = "exec \"\(exec)\" web --port 3080"
			} else {
				runDshCommand = "exec npx -y @deepseek-ai/dsh web --port 3080"
			}

			let cmd = """
			echo "🤖 ==============================================="
			echo "⚡️ Conectando DeepSeek Harness (dsh) a Splash..."
			echo "🔌 Puerto Splash: \(port)"
			echo "🌐 Endpoint OpenAI: http://127.0.0.1:\(port)/v1"
			echo "==============================================="
			echo ""
			export SPLASH_PORT="\(port)"
			export OPENAI_BASE_URL="http://127.0.0.1:\(port)/v1"
			export OPENAI_API_KEY="splash"
			export DEEPSEEK_BASE_URL="http://127.0.0.1:\(port)/v1"
			export DSH_BASE_URL="http://127.0.0.1:\(port)/v1"
			\(runDshCommand)
			"""

			runInTerminal(
				command: cmd,
				title: "DeepSeek Harness - Splash",
				scriptFileName: "launch_dsh.command"
			)
			return
		}

		let splashPath = splashExecutablePath
		let port = self.activePort
		// SIEMPRE configurar env vars con el puerto activo y pasar --port nativo si el motor lo soporta (Splash 1.3.0+)
		let agentRunCommand = """
		export SPLASH_PORT="\(port)"
		export ANTHROPIC_BASE_URL="http://127.0.0.1:\(port)"
		export OPENAI_BASE_URL="http://127.0.0.1:\(port)/v1"
		export CUSTOM_BASE_URL="http://127.0.0.1:\(port)/v1"
		exec "\(splashPath)" "\(agent)" --port "\(port)"
		"""

		let cmd = """
		echo "🤖 ==============================================="
		echo "⚡️ Conectando agente \(agent) al servidor Splash..."
		echo "🔌 Puerto: \(port)"
		echo "==============================================="
		echo ""
		\(agentRunCommand)
		"""
		runInTerminal(
			command: cmd,
			title: "Splash Agent - \(agent)",
			scriptFileName: "launch_\(agent).command"
		)
	}

	// MARK: - Formatting Helpers

	var formattedTokensDecode: String {
		guard let tokens = status?.metrics?.decodeOutputTokens else { return "0" }
		return formatNumber(tokens)
	}

	var formattedTokensPrefill: String {
		guard let tokens = status?.metrics?.prefillInputTokens else { return "0" }
		return formatNumber(tokens)
	}

	var formattedTokensReused: String {
		guard let tokens = status?.cache?.reusedTokens else { return "0" }
		return formatNumber(tokens)
	}

	var formattedDecodeSpeed: String {
		guard let speed = status?.metrics?.decodeTokensPerSecond else { return "0.0" }
		return String(format: "%.1f", speed)
	}

	var formattedPrefillSpeed: String {
		guard let speed = status?.metrics?.prefillTokensPerSecond else { return "0.0" }
		return String(format: "%.1f", speed)
	}

	var formattedDraftAcceptanceRate: String {
		guard let rate = status?.metrics?.draftAcceptanceRate else { return "0.0%" }
		return String(format: "%.1f%%", rate * 100.0)
	}

	var formattedCacheHitRate: String {
		guard let rate = status?.cache?.hitRate else { return "0.0%" }
		return String(format: "%.1f%%", rate * 100.0)
	}

	var formattedMemoryUsed: String {
		guard let bytes = status?.memoryActual?.currentBytes else { return "0 GB" }
		let gb = Double(bytes) / 1_073_741_824.0
		return String(format: "%.1f GB", gb)
	}

	var formattedMemoryLimit: String {
		guard let bytes = status?.memoryGovernor?.limitBytes ?? status?.memoryPlan?.device?.recommendedMaxWorkingSetBytes else { return "0 GB" }
		let gb = Double(bytes) / 1_073_741_824.0
		return String(format: "%.1f GB", gb)
	}

	var memoryUsageRatio: Double {
		guard let current = status?.memoryActual?.currentBytes,
			  let limit = status?.memoryGovernor?.limitBytes ?? status?.memoryPlan?.device?.recommendedMaxWorkingSetBytes,
			  limit > 0 else { return 0.0 }
		return min(1.0, Double(current) / Double(limit))
	}

	private func formatNumber(_ num: Int64) -> String {
		if num >= 1_000_000 {
			return String(format: "%.1fM", Double(num) / 1_000_000.0)
		} else if num >= 1_000 {
			return String(format: "%.1fK", Double(num) / 1_000.0)
		}
		return "\(num)"
	}

	// MARK: - Active Request Lifecycle (Issue #6)

	enum ActiveRequestStage: String, CaseIterable {
		case idle
		case queued
		case prefilling
		case decoding
		case offline

		var title: LocalizedStringResource {
			switch self {
			case .idle: return LocalizedStringResource("Idle (Ready)")
			case .queued: return LocalizedStringResource("In Queue")
			case .prefilling: return LocalizedStringResource("Prefilling (Prompt Intake)")
			case .decoding: return LocalizedStringResource("Decoding (Token Generation)")
			case .offline: return LocalizedStringResource("Server Stopped")
			}
		}

		var icon: String {
			switch self {
			case .idle: return "checkmark.circle.fill"
			case .queued: return "hourglass"
			case .prefilling: return "arrow.down.forward.circle.fill"
			case .decoding: return "bolt.fill"
			case .offline: return "pause.circle"
			}
		}
	}

	var activeRequestStage: ActiveRequestStage {
		guard isRunning else { return .offline }
		let prefilling = status?.scheduler?.prefilling ?? 0
		let decoding = status?.scheduler?.decoding ?? 0
		let queued = status?.scheduler?.queued ?? 0

		if prefilling > 0 {
			return .prefilling
		} else if decoding > 0 {
			return .decoding
		} else if queued > 0 {
			return .queued
		} else {
			return .idle
		}
	}

	var isRequestActive: Bool {
		let stage = activeRequestStage
		return stage == .prefilling || stage == .decoding
	}

	// MARK: - Connected Apps / Client Detection

	func scanConnectedClients() async {
		guard isRunning else {
			if !connectedApps.isEmpty {
				self.connectedApps = []
				self.knownClientsSession.removeAll()
			}
			// §3.4: ceros también los contadores derivados.
			if activeClientCount != 0 {
				activeClientCount = 0
			}
			if totalSockets != 0 {
				totalSockets = 0
			}
			return
		}

		let port = self.activePort
		let serverPid = self.activePid

		// Solo la inspección de sockets sale del actor principal y devuelve texto
		// (`String` es Sendable). La consulta a AppKit (`NSRunningApplication`) se hace
		// después, ya en el actor principal: Swift 6 exige Sendable para cruzar actores y
		// las API de AppKit no deben usarse desde hilos en segundo plano.
		let listing = await Task.detached(priority: .utility) {
			await CommandRunner.run("/usr/sbin/lsof",
									["-iTCP:\(port)", "-sTCP:ESTABLISHED", "-n", "-P"]).output
		}.value

		var pidConnections: [Int32: (name: String, count: Int, remote: String)] = [:]
		var lanConnections: [String: (count: Int, remote: String)] = [:]
		let localLANIP = self.localNetworkIP

		// Parser puro y comprobado (`ListerOutput`) en lugar del bucle en línea.
		for connection in ListerOutput.establishedConnections(listing) {
			let pid = connection.pid
			let comm = connection.command

			let isServer = (serverPid != nil && Int32(serverPid!) == pid) || SplashEngineIdentity.isEngineCommand(comm)

			// Si la conexión pertenece al proceso del servidor Splash, inspeccionar si proviene de un cliente remoto de la LAN
			if isServer {
				let parts = connection.remoteAddress.components(separatedBy: "->")
				let remoteTarget = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
				let remoteIP = remoteTarget.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

				if !remoteIP.isEmpty &&
					remoteIP != "127.0.0.1" &&
					remoteIP != "::1" &&
					remoteIP != "localhost" &&
					remoteIP != localLANIP {
					if let existing = lanConnections[remoteIP] {
						lanConnections[remoteIP] = (count: existing.count + 1, remote: remoteTarget)
					} else {
						lanConnections[remoteIP] = (count: 1, remote: remoteTarget)
					}
				}
				continue
			}

			// Filter out Splash's internal engine or python if under a different PID
			if comm.localizedCaseInsensitiveContains("splash") && !comm.localizedCaseInsensitiveContains("claude") {
				continue
			}

			if let existing = pidConnections[pid] {
				pidConnections[pid] = (name: existing.name, count: existing.count + 1, remote: existing.remote)
			} else {
				pidConnections[pid] = (name: comm, count: 1, remote: connection.remoteAddress)
			}
		}

		var detected: [ConnectedApp] = []

		// Clientes remotos conectados a través de la red de área local (LAN)
		for (remoteIP, info) in lanConnections {
			let syntheticPid = Int32(abs(remoteIP.hashValue % 100000) + 900000)
			let app = ConnectedApp(
				pid: syntheticPid,
				name: "Cliente LAN (\(remoteIP))",
				bundleId: nil,
				executablePath: nil,
				category: .lanClient,
				icon: NSImage(systemSymbolName: "network", accessibilityDescription: "LAN"),
				connectionCount: info.count,
				status: .active,
				firstConnected: Date(),
				lastSeen: Date(),
				remoteAddress: info.remote
			)
			detected.append(app)
		}

		for (pid, info) in pidConnections {
			let runningApp = NSRunningApplication(processIdentifier: pid)
			var appName = runningApp?.localizedName ?? info.name
			let bundleId = runningApp?.bundleIdentifier
			let icon = runningApp?.icon
			let execPath = runningApp?.executableURL?.path

			let lowerName = appName.lowercased()
			let lowerComm = info.name.lowercased()
			let category: AppCategory

			if bundleId == "com.anthropic.claudefordesktop" || (lowerName == "claude" && execPath?.contains("Claude.app") == true) {
				appName = "Claude Desktop / Cowork"
				category = .codingAgent
			} else if bundleId == "com.openai.codex" || bundleId == "com.openai.chat" || lowerName == "chatgpt" || execPath?.contains("ChatGPT.app") == true {
				appName = "ChatGPT Desktop (Codex)"
				category = .codingAgent
			} else if bundleId == "com.deepseek.dsh" || (lowerName.contains("deepseek") && execPath?.contains("DeepSeek Harness.app") == true) {
				appName = "DeepSeek Harness"
				category = .codingAgent
			} else if lowerName.contains("cursor") || lowerName.contains("code") || lowerName.contains("xcode") || lowerName.contains("zed") || lowerName.contains("studio") || lowerName.contains("intellij") || lowerName.contains("pycharm") {
				category = .ide
			} else if lowerComm.contains("claude") || lowerComm.contains("opencode") || lowerComm.contains("hermes") || lowerComm.contains("codex") || lowerComm.contains("aider") || lowerComm.contains("dsh") || lowerComm.contains("deepseek") || lowerComm.contains("harness") {
				if lowerComm.contains("dsh") || lowerComm.contains("deepseek") || lowerComm.contains("harness") {
					appName = "DeepSeek Harness (dsh)"
				} else if lowerComm.contains("hermes") {
					appName = "Hermes Agent"
				}
				category = .codingAgent
			} else if lowerName.contains("chat") || lowerName.contains("webui") || lowerName.contains("lmstudio") || lowerName.contains("ollama") || lowerName.contains("nextchat") {
				category = .chatbot
			} else if lowerName.contains("terminal") || lowerName.contains("iterm") || lowerName.contains("warp") || lowerName.contains("kitty") || lowerName.contains("alacritty") {
				category = .terminal
			} else {
				category = .customScript
			}

			let app = ConnectedApp(
				pid: pid,
				name: appName,
				bundleId: bundleId,
				executablePath: execPath,
				category: category,
				icon: icon,
				connectionCount: info.count,
				status: .active,
				firstConnected: Date(),
				lastSeen: Date(),
				remoteAddress: info.remote
			)
			detected.append(app)
		}

		let now = Date()
		var updatedList: [ConnectedApp] = []
		var activePids = Set<Int32>()

		for var detectedApp in detected {
			activePids.insert(detectedApp.pid)
			if let existing = knownClientsSession[detectedApp.pid] {
				detectedApp.firstConnected = existing.firstConnected
			}
			detectedApp.lastSeen = now
			detectedApp.status = .active
			knownClientsSession[detectedApp.pid] = detectedApp
			updatedList.append(detectedApp)
		}

		for (pid, var cachedApp) in knownClientsSession {
			if !activePids.contains(pid) {
				let elapsed = now.timeIntervalSince(cachedApp.lastSeen)
				if elapsed < 60.0 {
					cachedApp.status = .recent
					cachedApp.connectionCount = 0
					updatedList.append(cachedApp)
				} else {
					knownClientsSession.removeValue(forKey: pid)
				}
			}
		}

		let sorted = updatedList.sorted {
			if $0.status == .active && $1.status != .active { return true }
			if $0.status != .active && $1.status == .active { return false }
			return $0.lastSeen > $1.lastSeen
		}

		// §3.4: los contadores se calculan una vez por ciclo en lugar de derivarse
		// (filter/reduce) en el cuerpo de la vista con cada invalidación.
		let clients = sorted.filter { $0.status == .active || $0.status == .idle }.count
		let sockets = sorted.reduce(0) { $0 + $1.connectionCount }
		if activeClientCount != clients {
			activeClientCount = clients
		}
		if totalSockets != sockets {
			totalSockets = sockets
		}
		if self.connectedApps != sorted {
			self.connectedApps = sorted
		}
	}

	func activateApp(app: ConnectedApp) {
		if let running = NSRunningApplication(processIdentifier: app.pid) {
			running.activate(options: .activateIgnoringOtherApps)
		}
	}

	func revealAppInFinder(app: ConnectedApp) {
		if let path = app.executablePath, FileManager.default.fileExists(atPath: path) {
			NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
		} else if let bundle = app.bundleId,
				  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
			NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
		}
	}

	/// Termina la aplicación cliente indicada.
	///
	/// P-04 / H-05: la interfaz pide confirmación y aquí se reverifica la identidad
	/// antes de señalizar. Antes se enviaba `SIGTERM` al PID registrado sin comprobar
	/// que siguiera siendo la misma aplicación (un PID reciclado apuntaba a otro
	/// proceso) y sin distinguir las apps del propio monitor.
	/// - Returns: `true` si la aplicación fue terminada.
	@discardableResult
	func terminateApp(app: ConnectedApp) -> Bool {
		let running = NSRunningApplication(processIdentifier: app.pid)
		let allowed = ClientTerminationPolicy.canTerminate(
			pid: app.pid,
			recordedBundleID: app.bundleId,
			currentBundleID: running?.bundleIdentifier,
			currentName: running?.localizedName,
			isRunning: running != nil,
			ownBundleID: Bundle.main.bundleIdentifier
		)
		knownClientsSession.removeValue(forKey: app.pid)
		guard allowed, let running else { return false }
		running.terminate()
		self.connectedApps.removeAll(where: { $0.pid == app.pid })
		return true
	}

	/// Libera la memoria del servidor de inmediato usando el endpoint nativo POST /v1/memory/release (Splash 1.3.2+)
	/// o deteniendo el servidor si no está respondiendo.
	func releaseMemoryNow() {
		guard isRunning else { return }
		memoryReliefNotice = "Memoria liberada manualmente por el usuario."

		let port = activePort
		Task {
			guard let url = URL(string: "http://127.0.0.1:\(port)/v1/memory/release") else {
				await MainActor.run { self.stopServer() }
				return
			}
			var request = URLRequest(url: url)
			request.httpMethod = "POST"
			request.timeoutInterval = 2.0

			do {
				let (_, response) = try await URLSession.shared.data(for: request)
				if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
					await MainActor.run {
						self.memoryReliefNotice = "Pesos del modelo liberados de la memoria unificada (Caché preservada en Splash 1.3.2)."
					}
					return
				}
			} catch {
				// Fallback a detención segura si el servidor no soporta el endpoint nativo
			}

			await MainActor.run {
				self.stopServer()
			}
		}
	}
}

// MARK: - Centinela de Presión de Memoria del Kernel de macOS
extension SplashService: SystemMemoryPressureSentinelDelegate {
	func memoryPressureDidChange(to level: SystemMemoryPressureLevel) {
		self.systemMemoryPressure = level

		guard Preferences.autoReleaseOnMemoryPressure else { return }

		if level == .critical && isRunning {
			let queued = status?.scheduler?.queued ?? 0
			let prefilling = status?.scheduler?.prefilling ?? 0
			let decoding = status?.scheduler?.decoding ?? 0
			let isBusy = (queued + prefilling + decoding) > 0
			if !isBusy {
				logger.info("Presión de memoria del sistema CRÍTICA detectada y servidor inactivo. Liberando memoria...")
				self.memoryReliefNotice = String(localized: "The Splash engine was put to sleep to protect macOS system memory.")
				NotificationService.shared.notifyMemoryPressureCritical()
				self.stopServer()
			} else {
				logger.info("Presión de memoria CRÍTICA detectada, pero hay operaciones en curso (prefilling: \(prefilling), decoding: \(decoding))")
			}
		}
	}
}

