import Foundation
import Testing
import SwiftUI
import AppKit
@testable import Splash

// MARK: - Generador de capturas (aislado del CI: SPLASH_GENERATE_SCREENSHOTS=1)

@MainActor
@Suite(.serialized)
final class ScreenshotGeneratorTests {

	/// Instantánea de los campos de `SplashService.shared` que este generador
	/// sobreescribe, para restaurarlos al terminar cada test.
	private struct SharedSnapshot {
		var isRunning: Bool
		var activePort: Int
		var activeModel: String
		var selectedModelForLaunch: String
		var activePid: Int?
		var status: SplashStatus?
		var isSplashInstalled: Bool
		var installedAgents: Set<String>
		var speedHistory: [Double]
		var installedModels: [InstalledSplashModel]
		var connectedApps: [ConnectedApp]
		var isInstalling: Bool
		var installingModelId: String?
		var installLogs: [String]
		var downloadSpeedMBs: Double
		var downloadedBytes: Int64
		var totalExpectedBytes: Int64
		var downloadProgressFraction: Double?
		var downloadPhase: String
		var languageOnly: Bool
		var pressureDelegate: SystemMemoryPressureSentinelDelegate?

		@MainActor
		static func capture(_ s: SplashService) -> SharedSnapshot {
			SharedSnapshot(
				isRunning: s.isRunning,
				activePort: s.activePort,
				activeModel: s.activeModel,
				selectedModelForLaunch: s.selectedModelForLaunch,
				activePid: s.activePid,
				status: s.status,
				isSplashInstalled: s.isSplashInstalled,
				installedAgents: s.installedAgents,
				speedHistory: s.speedHistory,
				installedModels: s.installedModels,
				connectedApps: s.connectedApps,
				isInstalling: s.isInstalling,
				installingModelId: s.installingModelId,
				installLogs: s.installLogs,
				downloadSpeedMBs: s.downloadSpeedMBs,
				downloadedBytes: s.downloadedBytes,
				totalExpectedBytes: s.totalExpectedBytes,
				downloadProgressFraction: s.downloadProgressFraction,
				downloadPhase: s.downloadPhase,
				languageOnly: Preferences.languageOnly,
				pressureDelegate: SystemMemoryPressureSentinel.shared.delegate
			)
		}
	}

	private let saved: SharedSnapshot

	init() {
		saved = .capture(SplashService.shared)
	}

	isolated deinit {
		let s = SplashService.shared
		s.isRunning = saved.isRunning
		s.activePort = saved.activePort
		s.activeModel = saved.activeModel
		s.selectedModelForLaunch = saved.selectedModelForLaunch
		s.activePid = saved.activePid
		s.status = saved.status
		s.isSplashInstalled = saved.isSplashInstalled
		s.installedAgents = saved.installedAgents
		s.speedHistory = saved.speedHistory
		s.installedModels = saved.installedModels
		s.connectedApps = saved.connectedApps
		s.isInstalling = saved.isInstalling
		s.installingModelId = saved.installingModelId
		s.installLogs = saved.installLogs
		s.downloadSpeedMBs = saved.downloadSpeedMBs
		s.downloadedBytes = saved.downloadedBytes
		s.totalExpectedBytes = saved.totalExpectedBytes
		s.downloadProgressFraction = saved.downloadProgressFraction
		s.downloadPhase = saved.downloadPhase
		Preferences.languageOnly = saved.languageOnly
		SystemMemoryPressureSentinel.shared.delegate = saved.pressureDelegate
	}

	@Test(.enabled(if: ProcessInfo.processInfo.environment["SPLASH_GENERATE_SCREENSHOTS"] == "1"))
	func testGenerateAllModuleScreenshots() throws {
		// Salida en un directorio temporal (nada se escribe dentro del repo).
		let outDir = try TempDirectory()
		let baseDir = outDir.file("screenshots")

		// Servicio dedicado construido a través de la costura de inyección
		// (StubStatusTransport, sin red). Las vistas leen `SplashService.shared`
		// directamente —no son inyectables—, así que el estado simulado se aplica
		// al singleton y se restaura en el `deinit` de la suite.
		let dedicated = makeTestService(pollInterval: 60, directory: outDir.url)

		let service = SplashService.shared
		service.isRunning = true
		service.activePort = 8005
		service.activeModel = "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q4_K"
		service.selectedModelForLaunch = "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q4_K"
		service.activePid = 4242
		// Se reutiliza la fixture auditada de TestSupport en lugar de duplicar el JSON.
		// (El mock original tenía números de memoria propios de una M4 Max; la fixture
		// V-4 es el contrato de referencia y las vistas no dependen de esos valores.)
		service.status = Fixtures.status(port: 8005,
										 model: "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q4_K")
		service.isSplashInstalled = true
		service.installedAgents = Set(["claude", "claude-cowork", "opencode", "codex", "hermes", "pi", "dsh"])
		service.speedHistory = [82.0, 89.4, 95.1, 101.5, 104.3, 107.0, 108.5, 109.0]
		Preferences.languageOnly = false

		service.installedModels = [
			InstalledSplashModel(
				repoId: "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q4_K",
				localPath: URL(fileURLWithPath: "/tmp/qwen36"),
				diskSizeBytes: 21_474_836_480,
				isCurrentlyActive: true
			),
			InstalledSplashModel(
				repoId: "unsloth/Ornith-1.5-122B-GGUF:UD-Q4_K_XL",
				localPath: URL(fileURLWithPath: "/tmp/ornith"),
				diskSizeBytes: 68_719_476_736,
				isCurrentlyActive: false
			),
			InstalledSplashModel(
				repoId: "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:IQ3_S",
				localPath: URL(fileURLWithPath: "/tmp/flashnext"),
				diskSizeBytes: 12_884_901_888,
				isCurrentlyActive: false
			),
			InstalledSplashModel(
				repoId: "unsloth/Flint-40B-A2.5B-GGUF:Q4_K_M",
				localPath: URL(fileURLWithPath: "/tmp/flint"),
				diskSizeBytes: 24_696_061_952,
				isCurrentlyActive: false
			)
		]

		service.connectedApps = [
			ConnectedApp(
				pid: 1234,
				name: "Claude Desktop / Cowork",
				bundleId: "com.anthropic.claudefordesktop",
				category: .codingAgent,
				icon: FileManager.default.fileExists(atPath: "/Applications/Claude.app") ? NSWorkspace.shared.icon(forFile: "/Applications/Claude.app") : nil,
				connectionCount: 3,
				status: .active,
				remoteAddress: "127.0.0.1"
			),
			ConnectedApp(
				pid: 5678,
				name: "Cursor IDE",
				bundleId: "com.todesktop.230313mzl4w4u92",
				category: .ide,
				icon: nil,
				connectionCount: 2,
				status: .active,
				remoteAddress: "127.0.0.1"
			)
		]
		#expect(dedicated.skipPortConflictCheck, "El servicio dedicado debe estar aislado de puertos reales")

		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.appearance = NSAppearance(named: .darkAqua)

		// El bucle de idiomas se conserva estructuralmente del original.
		for lang in ["es", "en"] {
			let langDir = baseDir.appendingPathComponent(lang)
			try FileManager.default.createDirectory(at: langDir, withIntermediateDirectories: true)

			for item in SidebarItem.allCases {
				let view = MainWindowView(initialTab: item)
					.frame(width: 1000, height: 700)
					.preferredColorScheme(.dark)

				let filename = "module-\(item.rawValue).png"
				try renderPNG(view, in: window, name: filename, into: langDir,
							  rootCopy: lang == "es" ? baseDir : nil, lang: lang)
			}

			// Captura de Guía de Conexión
			let guideView = NavigationSplitView {
				VStack { Spacer() }
					.frame(minWidth: 220, idealWidth: 240)
			} detail: {
				ScrollView {
					ConnectedAppsView(initialTab: .quickConnect)
						.padding(20)
				}
			}
			.frame(width: 1000, height: 700)
			.preferredColorScheme(.dark)

			try renderPNG(guideView, in: window, name: "module-connectedApps-guide.png",
						  into: langDir, rootCopy: lang == "es" ? baseDir : nil, lang: lang)

			// Captura de Descarga en Vivo
			service.isInstalling = true
			service.installingModelId = "mlx-community/Qwen3.8-27B-Uncensored-OptiQ-4bit"
			service.downloadSpeedMBs = 34.8
			service.downloadedBytes = 1_426_063_360
			service.totalExpectedBytes = 4_133_879_808
			service.downloadProgressFraction = 0.35

			if lang == "es" {
				service.downloadPhase = "Descargando acelerador DFlash2 (especulativo)..."
				service.installLogs = [
					"Iniciando descarga y preparación para mlx-community/Qwen3.8-27B-Uncensored-OptiQ-4bit...",
					"ℹ️ Modo solo lenguaje (--language-only) activado.",
					"ℹ️ Fetching 1 file(s), 3.85 GB, from incoai/Qwen3.8-27B-DFlash2@015e795645c7; cached files are reused.",
					"⏳ Conectando y transfiriendo archivos grandes en paralelo...",
					"Fetching 2 files:   0%|          | 0/2 [00:00<?, ?it/s]",
					"📥 Descargando paquete: 1.33 GB recibidos..."
				]
			} else {
				service.downloadPhase = "Downloading DFlash2 speculative accelerator..."
				service.installLogs = [
					"Starting download and preparation for mlx-community/Qwen3.8-27B-Uncensored-OptiQ-4bit...",
					"ℹ️ Language-only mode (--language-only) enabled.",
					"ℹ️ Fetching 1 file(s), 3.85 GB, from incoai/Qwen3.8-27B-DFlash2@015e795645c7; cached files are reused.",
					"⏳ Connecting and streaming large model shards in parallel...",
					"Fetching 2 files:   0%|          | 0/2 [00:00<?, ?it/s]",
					"📥 Downloading package: 1.33 GB received..."
				]
			}

			let downloadView = MainWindowView(initialTab: .models)
				.frame(width: 1000, height: 700)
				.preferredColorScheme(.dark)

			try renderPNG(downloadView, in: window, name: "module-modelDownload.png",
						  into: langDir, rootCopy: lang == "es" ? baseDir : nil, lang: lang)
		}
	}

	/// Renderiza una vista en la ventana compartida y escribe el PNG (y una copia
	/// en la raíz, para el español) con `#require` en lugar de `XCTFail`/`continue`.
	private func renderPNG(_ view: some View, in window: NSWindow, name: String,
						   into langDir: URL, rootCopy: URL?, lang: String) throws {
		let hosting = NSHostingView(rootView: view)
		hosting.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
		window.contentView = hosting
		hosting.layoutSubtreeIfNeeded()

		let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) as? NSBitmapImageRep,
							   "No se pudo crear bitmapImageRep para \(name)")
		hosting.cacheDisplay(in: hosting.bounds, to: rep)
		let pngData = try #require(rep.representation(using: .png, properties: [:]),
								   "No se pudo obtener representación PNG para \(name)")

		try pngData.write(to: langDir.appendingPathComponent(name))
		if let rootCopy {
			try pngData.write(to: rootCopy.appendingPathComponent(name))
		}
		print("📸 Captura [\(lang)] generada con éxito: \(name)")
	}
}
