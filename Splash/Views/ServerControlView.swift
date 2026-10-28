import SwiftUI
import AppKit

public struct ServerControlView: View {
	@State private var portString: String = "8000"
	@State private var isCustomModel: Bool = false
	@State private var customModelText: String = ""
	@State private var copiedMessage: String? = nil
	@State private var showOptimalAppliedBanner: Bool = false

	// Agent alert state
	@State private var showingAgentOfflineAlert: Bool = false
	@State private var showingAgentNotInstalledAlert: Bool = false
	@State private var showingLogsSheet: Bool = false
	@State private var pendingAgentName: String = ""
	@State private var pendingAgentCommand: String = ""

	/// Error de validación del identificador personalizado (P-03).
	/// `nil` = válido o campo no utilizado. Misma regla que aplica el servicio.
	private var customModelError: LocalizedStringResource? {
		guard isCustomModel else { return nil }
		let value = customModelText.trimmingCharacters(in: .whitespacesAndNewlines)
		if value.isEmpty {
			return "Enter an owner/repo or owner/repo:variant identifier."
		}
		return ModelIDValidator.rejectionReason(value)
	}

	/// Error de validación de flags CLI adicionales (P-03).
	private var customFlagsError: String? {
		let (_, err) = ServerCLIValidator.validateAndTokenize(Preferences.customServerFlags)
		return err
	}

	public var body: some View {
		VStack(spacing: 12) {
			// 0. Dependency missing alert if needed
			if !SplashService.shared.isSplashInstalled {
				dependencyWarningBanner
			}

			// 1. Current Status Banner
			statusBannerView

			// 2. Model Selection & Launch Section (FEATURED)
			modelSelectionAndLaunchView

			// 3. Coding Agents Launcher
			agentsLauncherView

			// 4. API Endpoints & Copy Helpers
			apiEndpointsView
		}
		.onAppear {
			portString = "\(SplashService.shared.activePort)"
		}
		.onChange(of: SplashService.shared.activePort) { _, newPort in
			portString = "\(newPort)"
		}
		.alert(
			"Splash Server Offline",
			isPresented: $showingAgentOfflineAlert
		) {
			Button("Start Server First") {
				let targetModel = isCustomModel ? customModelText.trimmingCharacters(in: .whitespacesAndNewlines) : SplashService.shared.selectedModelForLaunch
				let targetPort = Int(portString) ?? SplashService.shared.activePort
				SplashService.shared.startServer(model: targetModel, port: targetPort)
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("To connect \(pendingAgentName), the local Splash inference server must be running. Start the server first.")
		}
		.alert(
			"\(pendingAgentName) Not Found",
			isPresented: $showingAgentNotInstalledAlert
		) {
			Button("Open Installation Guide") {
				let url = SplashService.shared.agentInstallURL(agent: pendingAgentCommand)
				NSWorkspace.shared.open(url)
			}

			Button(
				pendingAgentCommand == "claude-cowork" ? LocalizedStringResource("Open Claude Anyway") : (pendingAgentCommand == "chatgpt" ? LocalizedStringResource("Open ChatGPT Anyway") : (pendingAgentCommand == "dsh" ? LocalizedStringResource("Open DeepSeek Harness Anyway") : LocalizedStringResource("Launch in Terminal Anyway")))
			) {
				SplashService.shared.launchAgent(agent: pendingAgentCommand)
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text(
				pendingAgentCommand == "claude-cowork" ? "Claude for Mac application was not detected on your system (/Applications/Claude.app). You can download it from the official Claude website." : (pendingAgentCommand == "chatgpt" ? "ChatGPT for Mac application was not detected on your system (/Applications/ChatGPT.app). You can download it from the official OpenAI website." : (pendingAgentCommand == "dsh" ? "DeepSeek Harness app (/Applications/DeepSeek Harness.app) or binary 'dsh' was not detected on your system. You can download the official app or install the CLI via 'npm i -g @deepseek-ai/dsh'." : "Command '\(pendingAgentCommand)' was not detected on your system. You can install it following the official guide."))
			)
		}
		.alert(
			item: SplashService.$shared.portConflict
		) { conflict in
			Alert(
				title: Text("⚠️ Port \(conflict.port) In Use"),
				message: Text("Process '\(conflict.processName)' (PID \(conflict.pid)) is currently using port \(conflict.port).\n\nWould you like to switch to suggested free port \(conflict.suggestedPort) or free port \(conflict.port)?"),
				primaryButton: .default(Text("Use port \(conflict.suggestedPort)")) {
					portString = "\(conflict.suggestedPort)"
					SplashService.shared.useSuggestedPort(conflict.suggestedPort)
				},
				secondaryButton: .destructive(Text("Free port \(conflict.port)")) {
					SplashService.shared.resolvePortConflict(killProcess: true)
				}
			)
		}
		.alert(
			"Configure your shell",
			isPresented: Binding(
				get: { SplashService.shared.pendingShellConfigPort != nil },
				set: { presented in
					if !presented { SplashService.shared.pendingShellConfigPort = nil }
				}
			)
		) {
			Button("Allow and configure") {
				SplashService.shared.resolveShellConfigPrompt(allow: true)
			}
			Button("No thanks", role: .cancel) {
				SplashService.shared.resolveShellConfigPrompt(allow: false)
			}
		} message: {
			Text("Splash Monitor can add a line to your ~/.zshrc so agents launched from a terminal inherit port \(SplashService.shared.pendingShellConfigPort ?? SplashService.shared.activePort). This writes to your personal configuration; you can undo it from Settings. The ~/.splash_monitor_env file is always written.")
		}
		.sheet(isPresented: $showingLogsSheet) {
			VStack(alignment: .leading, spacing: 10) {
				HStack {
					Label("Splash Server Logs", systemImage: "terminal.fill")
						.font(.system(size: 13, weight: .bold))
					Spacer()
					Button("Close") {
						showingLogsSheet = false
					}
					.buttonStyle(.bordered)
				}

				let logs = SplashService.shared.readRecentServerLogs(lines: 100)
				ScrollView {
					Text(logs.isEmpty ? String(localized: "No logs available yet.") : logs)
						.font(.system(size: 10, design: .monospaced))
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(10)
						.background(Color(nsColor: .textBackgroundColor))
						.cornerRadius(6)
				}
				.frame(minHeight: 280, maxHeight: 420)
			}
			.padding(16)
			.frame(width: 580)
		}
	}

	// MARK: - 0. Dependency Warning Banner
	private var dependencyWarningBanner: some View {
		HStack(spacing: 10) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundColor(.orange)
				.font(.system(size: 14))

			VStack(alignment: .leading, spacing: 1) {
				Text("Splash CLI is not installed on this Mac")
					.font(.system(size: 11, weight: .bold))
				Text("brew install incoai/tap/splash")
					.font(.system(size: 9, design: .monospaced))
					.foregroundColor(.secondary)
			}

			Spacer()

			Button {
				SplashService.shared.installSplashDependency()
			} label: {
				Text("Install Now")
					.font(.system(size: 10, weight: .bold))
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.small)
		}
		.padding(8)
		.background(Color.orange.opacity(0.15))
		.cornerRadius(8)
	}

	// MARK: - 1. Status Banner
	private var statusBannerView: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Circle()
					.fill(SplashService.shared.isRunning ? Color.green : Color.red)
					.frame(width: 9, height: 9)

				Text("Splash Server Active")
					.font(.system(size: 12, weight: .bold))

				Spacer()

				if let pid = SplashService.shared.activePid {
					Text("PID: \(pid)")
						.font(.system(size: 10, design: .monospaced))
						.foregroundColor(.secondary)
				}
			}

			HStack(spacing: 16) {
				VStack(alignment: .leading, spacing: 2) {
					Text("Running Model")
						.font(.system(size: 9))
						.foregroundColor(.secondary)
					Text(SplashService.shared.isRunning ? SplashService.shared.activeModel : String(localized: "None (server stopped)"))
						.font(.system(size: 11, weight: .semibold))
						.lineLimit(1)
				}

				Spacer()

				VStack(alignment: .trailing, spacing: 2) {
					Text("Active Port")
						.font(.system(size: 9))
						.foregroundColor(.secondary)
					HStack(spacing: 4) {
						Text("\(SplashService.shared.activePort)")
							.font(.system(size: 11, weight: .semibold, design: .monospaced))
						if Preferences.listenOnAllInterfaces, let ip = SplashService.shared.localNetworkIP {
							Text("(LAN: \(ip))")
								.font(.system(size: 10, weight: .medium, design: .monospaced))
								.foregroundColor(.blue)
						}
					}
				}
			}

			if SplashService.shared.isRunning {
				HStack(spacing: 8) {
					Button(role: .destructive) {
						SplashService.shared.stopServer()
					} label: {
						Label("Stop Server", systemImage: "stop.fill")
							.font(.system(size: 11))
					}
					.buttonStyle(.bordered)
					.controlSize(.small)

					Button {
						SplashService.shared.switchModel(to: SplashService.shared.activeModel)
					} label: {
						Label("Restart", systemImage: "arrow.clockwise")
							.font(.system(size: 11))
					}
					.buttonStyle(.bordered)
					.controlSize(.small)

					Button {
						if let url = URL(string: "http://127.0.0.1:\(SplashService.shared.activePort)") {
							NSWorkspace.shared.open(url)
						}
					} label: {
						Label("WebUI", systemImage: "safari")
							.font(.system(size: 11))
					}
					.buttonStyle(.bordered)
					.controlSize(.small)

					if let vision = SplashService.shared.status?.vision {
						HStack(spacing: 4) {
							Image(systemName: vision ? "eye.fill" : "doc.text.fill")
								.font(.system(size: 9))
							Text("Vision Active")
								.font(.system(size: 9, weight: .semibold))
						}
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.background(vision ? Color.purple.opacity(0.15) : Color.orange.opacity(0.15))
						.foregroundColor(vision ? .purple : .orange)
						.cornerRadius(4)
						.help(vision
							  ? LocalizedStringResource("Model supports vision modalities (images and PDF).")
							  : LocalizedStringResource("Model is running in text/code only mode (--language-only)."))
					}
				}
				.padding(.top, 2)
			}
		}
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
	}

	// MARK: - 2. Model Selection & Launch Section
	private var modelSelectionAndLaunchView: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Image(systemName: "cpu")
					.font(.system(size: 12, weight: .semibold))
					.foregroundColor(.accentColor)
				Text(SplashService.shared.isRunning ? "Switch Model or Restart" : "Start Server with Model")
					.font(.system(size: 11, weight: .semibold))

				Spacer()

				Button {
					SplashService.shared.restoreOptimalProfile()
					portString = "\(Preferences.lastUsedPort)"
					withAnimation {
						showOptimalAppliedBanner = true
					}
					DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
						withAnimation {
							showOptimalAppliedBanner = false
						}
					}
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "sparkles")
							.foregroundColor(.orange)
						Text("Optimal Profile")
					}
					.font(.system(size: 10, weight: .semibold))
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.help("Restores high-performance recommended configuration for Apple M4 Max (64 GB): GDN BF16, Thinking 8K, SSD Cache, Context 128K, Port 8005, and LAN 0.0.0.0.")

				Toggle("Custom", isOn: $isCustomModel)
					.toggleStyle(.checkbox)
					.font(.system(size: 10))
			}

			if showOptimalAppliedBanner {
				HStack(spacing: 5) {
					Image(systemName: "checkmark.circle.fill")
						.foregroundColor(.green)
						.font(.system(size: 11))
					Text("Optimal M4 Max (64 GB) profile restored: Port 8005, GDN BF16, Thinking 8K, Ctx 128K, SSD Cache!")
						.font(.system(size: 10, weight: .medium))
						.foregroundColor(.green)
					Spacer()
				}
				.padding(6)
				.background(Color.green.opacity(0.12))
				.cornerRadius(6)
				.transition(.opacity)
			}

			if isCustomModel {
				VStack(alignment: .leading, spacing: 4) {
					Text("Hugging Face Identifier (owner/repo):")
						.font(.system(size: 10))
						.foregroundColor(.secondary)
					TextField("e.g. mlx-community/Qwen3.8-27B-4bit", text: $customModelText)
						.textFieldStyle(.roundedBorder)
						.font(.system(size: 11, design: .monospaced))

					// P-03: aviso inmediato; el botón de arranque queda bloqueado mientras
					// el identificador no sea válido, así el usuario no descubre el error
					// después de intentar arrancar el motor.
					if let error = customModelError {
						HStack(spacing: 4) {
							Image(systemName: "exclamationmark.triangle.fill")
								.font(.system(size: 9))
							Text(error)
								.font(.system(size: 10))
						}
						.foregroundColor(.orange)
					}
				}
			} else {
				VStack(alignment: .leading, spacing: 4) {
					Text("Select model for inference:")
						.font(.system(size: 10))
						.foregroundColor(.secondary)

					if SplashService.shared.installedModels.isEmpty {
						HStack {
							Text("No models installed.")
								.font(.system(size: 11))
								.foregroundColor(.secondary)
							Spacer()
							Text("Use 'Models' tab to download")
								.font(.system(size: 9))
								.foregroundColor(.orange)
						}
						.padding(6)
						.background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
						.cornerRadius(6)
					} else {
						Picker("empty", selection: SplashService.$shared.selectedModelForLaunch) {
							ForEach(SplashService.shared.installedModels) { model in
								HStack {
									Text(model.shortName)
									Text("(\(model.formattedSize))")
										.foregroundColor(.secondary)
								}
								.tag(model.repoId)
							}
						}
						.labelsHidden()
						.pickerStyle(.menu)
					}
				}
			}

			// Configuration Rows: Row 1 (Network & Port) & Row 2 (Inference Options & Action)
			VStack(spacing: 9) {
				// Fila 1: Puerto y Configuración de Red / Host
				HStack(spacing: 8) {
					Text("Port:")
						.font(.system(size: 11, weight: .medium))
						.foregroundColor(.secondary)
						.lineLimit(1)
						.fixedSize()

					TextField("8000", text: $portString)
						.textFieldStyle(.roundedBorder)
						.font(.system(size: 11, design: .monospaced))
						.frame(width: 65)

					Button {
						let suggested = SplashService.shared.findSuggestedFreePort()
						portString = "\(suggested)"
					} label: {
						HStack(spacing: 4) {
							Image(systemName: "sparkles")
							Text("Suggest free")
								.lineLimit(1)
						}
						.font(.system(size: 11))
					}
					.buttonStyle(.borderless)
					.foregroundColor(.blue)
					.fixedSize()
					.help("Scan and automatically suggest a free port on your system")

					if let p = Int(portString) {
						if SplashService.shared.isPortListening(port: p) && (!SplashService.shared.isRunning || p != SplashService.shared.activePort) {
							HStack(spacing: 3) {
								Image(systemName: "exclamationmark.circle.fill")
									.font(.system(size: 9))
									.foregroundColor(.orange)
								Text("In use")
									.font(.system(size: 10, weight: .semibold))
									.foregroundColor(.orange)
									.lineLimit(1)
							}
							.fixedSize()
						} else {
							HStack(spacing: 3) {
								Image(systemName: "checkmark.circle.fill")
									.font(.system(size: 9))
									.foregroundColor(.green)
								Text("Free")
									.font(.system(size: 10, weight: .semibold))
									.foregroundColor(.green)
									.lineLimit(1)
							}
							.fixedSize()
						}
					}

					Spacer()

					// Selector de Host / Red (127.0.0.1 vs 0.0.0.0)
					Menu {
						Button {
							Preferences.listenOnAllInterfaces = false
						} label: {
							HStack {
								Text("127.0.0.1 (Localhost)")
								if !Preferences.listenOnAllInterfaces {
									Image(systemName: "checkmark")
								}
							}
						}
						Button {
							Preferences.listenOnAllInterfaces = true
						} label: {
							HStack {
								let label: LocalizedStringResource = SplashService.shared.localNetworkIP != nil
								? LocalizedStringResource("0.0.0.0 (LAN: \(SplashService.shared.localNetworkIP!))")
								: LocalizedStringResource("0.0.0.0 (LAN Access)")
								Text(label)
								if Preferences.listenOnAllInterfaces {
									Image(systemName: "checkmark")
								}
							}
						}
					} label: {
						HStack(spacing: 4) {
							Image(systemName: Preferences.listenOnAllInterfaces ? "network" : "lock.laptopcomputer")
								.font(.system(size: 10))
								.foregroundColor(Preferences.listenOnAllInterfaces ? .blue : .secondary)
							let hostText: LocalizedStringResource = {
								if Preferences.listenOnAllInterfaces {
									if let ip = SplashService.shared.localNetworkIP {
										return LocalizedStringResource("0.0.0.0 (\(ip))")
									}
									return LocalizedStringResource("0.0.0.0 (LAN)")
								}
								return "127.0.0.1 (Localhost)"
							}()
							Text(hostText)
								.font(.system(size: 10, design: .monospaced))
								.lineLimit(1)
						}
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.background(Color.secondary.opacity(0.08))
						.cornerRadius(5)
					}
					.menuStyle(.borderlessButton)
					.fixedSize()
					.help("127.0.0.1 only accepts connections from this Mac. 0.0.0.0 exposes the server to your local network (LAN) for other devices to connect.")
				}

				// Fila 2: Modalidad, Contexto Máximo y Botón de Acción Principal
				HStack(spacing: 8) {
					// Selector de Contexto Máximo (--max-context)
					Menu {
						Button {
							Preferences.maxContext = "auto"
						} label: {
							HStack {
								Text("Auto (by memory)")
								if Preferences.maxContext == "auto" {
									Image(systemName: "checkmark")
								}
							}
						}
						Divider()
						ForEach(["16K", "32K", "64K", "128K", "256K", "512K", "1M"], id: \.self) { ctx in
							Button {
								Preferences.maxContext = ctx
							} label: {
								HStack {
									Text("1M tokens (YaRN)")
									if Preferences.maxContext == ctx {
										Image(systemName: "checkmark")
									}
								}
							}
						}
					} label: {
						HStack(spacing: 4) {
							Image(systemName: "brain.head.profile")
								.font(.system(size: 10))
								.foregroundColor(.purple)
							Text("Ctx: \(Preferences.maxContext)")
								.font(.system(size: 10, design: .monospaced))
								.lineLimit(1)
						}
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.background(Color.secondary.opacity(0.08))
						.cornerRadius(5)
					}
					.menuStyle(.borderlessButton)
					.fixedSize()
					.help("Maximum context token limit (--max-context) for Splash inference.")

					Divider()
						.frame(height: 14)

					// Selector de Modalidad (Visión vs Solo Texto / --language-only)
					Menu {
						Button {
							Preferences.languageOnly = false
						} label: {
							HStack {
								Text("👁️ Vision + Text (Standard)")
								if !Preferences.languageOnly {
									Image(systemName: "checkmark")
								}
							}
						}
						Button {
							Preferences.languageOnly = true
						} label: {
							HStack {
								Text("📝 Text / Code Only (--language-only)")
								if Preferences.languageOnly {
									Image(systemName: "checkmark")
								}
							}
						}
					} label: {
						HStack(spacing: 4) {
							Image(systemName: Preferences.languageOnly ? "doc.text" : "eye")
								.font(.system(size: 10))
								.foregroundColor(Preferences.languageOnly ? .orange : .teal)
							Text("Text Only")
								.font(.system(size: 10, design: .monospaced))
								.lineLimit(1)
						}
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.background(Color.secondary.opacity(0.08))
						.cornerRadius(5)
					}
					.menuStyle(.borderlessButton)
					.fixedSize()
					.help("Configures whether Splash should initialize multimodal image support or text-only mode (--language-only, required for Coder models without mmproj projectors).")

					Divider()
						.frame(height: 14)

					// Selector de Liberación de Memoria por Inactividad (--idle-release)
					Menu {
						ForEach([
							("1m", "1 min (Fast saving)"),
							("2m", "2 min (Aggressive)"),
							("5m", "5 min (Balanced)"),
							("10m", "10 min (Default)"),
							("30m", "30 min (Extended)"),
							("off", "Disabled (Always in RAM)")
						], id: \.0) { item in
							Button {
								Preferences.idleRelease = item.0
							} label: {
								HStack {
									Text(item.1)
									if Preferences.idleRelease == item.0 {
										Image(systemName: "checkmark")
									}
								}
							}
						}
					} label: {
						HStack(spacing: 4) {
							Image(systemName: "timer")
								.font(.system(size: 10))
								.foregroundColor(.cyan)
							Text("Idle: \(Preferences.idleRelease)")
								.font(.system(size: 10, design: .monospaced))
								.lineLimit(1)
						}
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.background(Color.secondary.opacity(0.08))
						.cornerRadius(5)
					}
					.menuStyle(.borderlessButton)
					.fixedSize()
					.help("Idle time before unwiring and releasing Metal unified memory weights (--idle-release). Weights are restored automatically on incoming requests.")

					Divider()
						.frame(height: 14)

					// Selector de Límite de Memoria (--max-memory)
					Menu {
						Button {
							Preferences.maxMemory = "auto"
						} label: {
							HStack {
								Text("Auto (unlimited)")
								if Preferences.maxMemory == "auto" {
									Image(systemName: "checkmark")
								}
							}
						}
						Divider()
						ForEach(["16G", "24G", "28G", "32G", "40G", "48G", "64G"], id: \.self) { mem in
							Button {
								Preferences.maxMemory = mem
							} label: {
								HStack {
									Text("\(mem) Metal")
									if Preferences.maxMemory == mem {
										Image(systemName: "checkmark")
									}
								}
							}
						}
					} label: {
						HStack(spacing: 4) {
							Image(systemName: "memorychip")
								.font(.system(size: 10))
								.foregroundColor(.indigo)
							Text("RAM: \(Preferences.maxMemory)")
								.font(.system(size: 10, design: .monospaced))
								.lineLimit(1)
						}
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.background(Color.secondary.opacity(0.08))
						.cornerRadius(5)
					}
					.menuStyle(.borderlessButton)
					.fixedSize()
					.help("Maximum Metal memory budget (--max-memory) to prevent hogging all unified memory.")

					Spacer()

					let targetModel = isCustomModel ? customModelText.trimmingCharacters(in: .whitespacesAndNewlines) : SplashService.shared.selectedModelForLaunch
					let targetPort = Int(portString) ?? SplashService.shared.activePort
					let isSameAsActive = (targetModel == SplashService.shared.activeModel && SplashService.shared.isRunning)

					if SplashService.shared.isStartingServer {
						HStack(spacing: 6) {
							ProgressView()
								.controlSize(.small)
							Text("Starting Server...")
								.font(.system(size: 11, weight: .semibold))
								.lineLimit(1)
						}
						.padding(.horizontal, 10)
						.padding(.vertical, 5)
						.background(Color.green.opacity(0.15))
						.cornerRadius(6)
						.fixedSize()
					} else if SplashService.shared.isRunning {
						if isSameAsActive {
							Button {
								SplashService.shared.switchModel(to: targetModel)
							} label: {
								Label("Restart", systemImage: "arrow.clockwise")
									.font(.system(size: 11))
									.lineLimit(1)
							}
							.buttonStyle(.bordered)
							.controlSize(.regular)
							.fixedSize()
						} else {
							Button {
								SplashService.shared.startServer(model: targetModel, port: targetPort)
							} label: {
								Label("Switch Model", systemImage: "arrow.triangle.2.circlepath")
									.font(.system(size: 11, weight: .semibold))
									.lineLimit(1)
							}
							.buttonStyle(.borderedProminent)
							.tint(.purple)
							.controlSize(.regular)
							.disabled(targetModel.isEmpty || customModelError != nil || customFlagsError != nil)
							.fixedSize()
						}
					} else {
						Button {
							SplashService.shared.startServer(model: targetModel, port: targetPort)
						} label: {
							Label("Start Server", systemImage: "play.fill")
								.font(.system(size: 11, weight: .semibold))
								.lineLimit(1)
						}
						.buttonStyle(.borderedProminent)
						.tint(.green)
						.controlSize(.regular)
						.disabled(targetModel.isEmpty || customFlagsError != nil)
						.fixedSize()
					}
				}
			}

			// Fila 3: Optimizaciones Splash 1.3.2+ (Estado GDN BF16, Presupuesto Thinking y Caché SSD)
			HStack(spacing: 8) {
				// Selector de Formato de Estado Recurrente GDN (--state-format)
				Menu {
					Button {
						Preferences.stateFormat = "fp32"
					} label: {
						HStack {
							Text("FP32 (Standard, maximum fidelity)")
							if Preferences.stateFormat == "fp32" {
								Image(systemName: "checkmark")
							}
						}
					}
					Button {
						Preferences.stateFormat = "bf16"
					} label: {
						HStack {
							Text("BF16 (-50% RAM in GDN states)")
							if Preferences.stateFormat == "bf16" {
								Image(systemName: "checkmark")
							}
						}
					}
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "sparkles")
							.font(.system(size: 10))
							.foregroundColor(.pink)
						Text("GDN: BF16 (-50%)")
							.font(.system(size: 10, design: .monospaced))
							.lineLimit(1)
					}
					.padding(.horizontal, 6)
					.padding(.vertical, 3)
					.background(Color.secondary.opacity(0.08))
					.cornerRadius(5)
				}
				.menuStyle(.borderlessButton)
				.fixedSize()
				.help("Storage format for GDN recurrent states (--state-format). BF16 halves state memory in RAM (from 153 to 81 MiB on 27B) while keeping computation in FP32.")

				Divider()
					.frame(height: 14)

				// Selector de Presupuesto de Razonamiento (--thinking-token-budget)
				Menu {
					Button {
						Preferences.thinkingTokenBudget = "auto"
					} label: {
						HStack {
							Text("Uncapped (No limit)")
							if Preferences.thinkingTokenBudget == "auto" {
								Image(systemName: "checkmark")
							}
						}
					}
					Divider()
					ForEach(["2K", "4K", "8K", "16K", "32K"], id: \.self) { budget in
						Button {
							Preferences.thinkingTokenBudget = budget
						} label: {
							HStack {
								Text("\(budget) tokens")
								if Preferences.thinkingTokenBudget == budget {
									Image(systemName: "checkmark")
								}
							}
						}
					}
					Divider()
					Button {
						Preferences.thinkingTokenBudget = "off"
					} label: {
						HStack {
							Text("Disabled (-1)")
							if Preferences.thinkingTokenBudget == "off" {
								Image(systemName: "checkmark")
							}
						}
					}
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "lightbulb")
							.font(.system(size: 10))
							.foregroundColor(.yellow)
						Text("Thinking: \(Preferences.thinkingTokenBudget)")
							.font(.system(size: 10, design: .monospaced))
							.lineLimit(1)
					}
					.padding(.horizontal, 6)
					.padding(.vertical, 3)
					.background(Color.secondary.opacity(0.08))
					.cornerRadius(5)
				}
				.menuStyle(.borderlessButton)
				.fixedSize()
				.help("Maximum reasoning / thinking token budget (--thinking-token-budget) for chain-of-thought models.")

				Divider()
					.frame(height: 14)

				// Toggle Caché SSD Persistente (--persistent-cache)
				Toggle(isOn: Preferences.$persistentCache) {
					HStack(spacing: 4) {
						Image(systemName: Preferences.persistentCache ? "internaldrive.fill" : "internaldrive")
							.font(.system(size: 10))
							.foregroundColor(Preferences.persistentCache ? .green : .secondary)
						Text("Persistent SSD Cache")
							.font(.system(size: 10))
					}
				}
				.toggleStyle(.checkbox)
				.help("Keeps prefix cache on SSD across restarts (--persistent-cache). In Splash 1.3.2+ SSD cache is on by default in 'auto' mode and adjusts to disk space.")

				Divider()
					.frame(height: 14)

				// Selector de Verificación de Borrador MoE (--verify-rows)
				Menu {
					Button {
						Preferences.verifyRows = "auto"
					} label: {
						HStack {
							Text("Auto (Adaptive, +13–42% speed)")
							if Preferences.verifyRows == "auto" {
								Image(systemName: "checkmark")
							}
						}
					}
					Button {
						Preferences.verifyRows = "all"
					} label: {
						HStack {
							Text("All (All rows, Deterministic)")
							if Preferences.verifyRows == "all" {
								Image(systemName: "checkmark")
							}
						}
					}
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "gauge.with.needle")
							.font(.system(size: 10))
							.foregroundColor(.indigo)
						Text("Verify: Auto")
							.font(.system(size: 10, design: .monospaced))
							.lineLimit(1)
					}
					.padding(.horizontal, 6)
					.padding(.vertical, 3)
					.background(Color.secondary.opacity(0.08))
					.cornerRadius(5)
				}
				.menuStyle(.borderlessButton)
				.fixedSize()
				.help("Speculative draft verification mode (--verify-rows). 'auto' adapts verification boosting decode speed. 'all' verifies all rows for determinism.")

				Spacer()
			}
			.padding(.top, 2)

			// Flags CLI adicionales (ej. --no-webui --max-cache-disk 50GB)
			VStack(alignment: .leading, spacing: 3) {
				HStack(spacing: 4) {
					Image(systemName: "terminal")
						.font(.system(size: 9))
						.foregroundColor(.secondary)
					Text("Additional CLI flags:")
						.font(.system(size: 10, weight: .medium))
						.foregroundColor(.secondary)
					Spacer()
					if let err = customFlagsError {
						Text(err)
							.font(.system(size: 9))
							.foregroundColor(.red)
							.lineLimit(1)
					}
				}

				TextField(
					"Example: --no-webui --max-cache-disk 50GB",
					text: Preferences.$customServerFlags
				)
				.textFieldStyle(.roundedBorder)
				.font(.system(size: 10, design: .monospaced))
				.help("Additional flags and options passed directly at the end of the 'splash serve' command.")
			}
			.padding(.top, 2)

			// Background / Silent mode & logs options
			HStack {
				Toggle(isOn: Preferences.$runInBackground) {
					HStack(spacing: 4) {
						Image(systemName: Preferences.runInBackground ? "speaker.slash.fill" : "terminal")
							.font(.system(size: 10))
						Text("Run silently in background")
							.font(.system(size: 11))
					}
				}
				.toggleStyle(.checkbox)

				Spacer()

				Button {
					showingLogsSheet = true
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "doc.text.magnifyingglass")
						Text("View Logs")
					}
					.font(.system(size: 11))
				}
				.buttonStyle(.borderless)
				.foregroundColor(.blue)
			}
			.padding(.top, 4)
		}
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
		.onChange(of: portString) { _, newValue in
			guard let newPort = Int(newValue), newPort > 1024, newPort <= 65535 else { return }
			// If server is running on a different port, auto-restart on new port
			if SplashService.shared.isRunning && newPort != SplashService.shared.activePort {
				SplashService.shared.startServer(model: SplashService.shared.activeModel, port: newPort)
			}
		}
	}

	// MARK: - 3. Coding Agents Launcher
	private var agentsLauncherView: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				Text("Connect Coding Agents")
					.font(.system(size: 11, weight: .semibold))
					.foregroundColor(.secondary)

				Spacer()

				if !SplashService.shared.isRunning {
					HStack(spacing: 3) {
						Image(systemName: "info.circle")
						Text("Server offline")
					}
					.font(.system(size: 9))
					.foregroundColor(.orange)
				}
			}

			LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
				AgentButton(
					name: LocalizedStringResource("Claude Code"),
					icon: "brain.head.profile",
					command: "claude",
					isInstalled: SplashService.shared.isAgentInstalled(agent: "claude"),
					isServerRunning: SplashService.shared.isRunning
				) {
					handleAgentLaunch(name: "Claude Code", command: "claude")
				}

				AgentButton(
					name: LocalizedStringResource("Claude Cowork"),
					icon: "person.2.badge.gearshape",
					command: "claude-cowork",
					subtitle: LocalizedStringResource("Claude for Mac"),
					isInstalled: SplashService.shared.isAgentInstalled(agent: "claude-cowork"),
					isServerRunning: SplashService.shared.isRunning
				) {
					handleAgentLaunch(name: "Claude Cowork", command: "claude-cowork")
				}

				AgentButton(
					name: LocalizedStringResource("ChatGPT Desktop"),
					icon: "sparkles",
					command: "chatgpt",
					subtitle: LocalizedStringResource("Codex & OWL (macOS)"),
					isInstalled: SplashService.shared.isAgentInstalled(agent: "chatgpt"),
					isServerRunning: SplashService.shared.isRunning
				) {
					handleAgentLaunch(name: "ChatGPT Desktop", command: "chatgpt")
				}

				AgentButton(
					name: LocalizedStringResource("OpenCode"),
					icon: "chevron.left.forwardslash.chevron.right",
					command: "opencode",
					isInstalled: SplashService.shared.isAgentInstalled(agent: "opencode"),
					isServerRunning: SplashService.shared.isRunning
				) {
					handleAgentLaunch(name: "OpenCode", command: "opencode")
				}

				AgentButton(
					name: LocalizedStringResource("Codex"),
					icon: "terminal",
					command: "codex",
					isInstalled: SplashService.shared.isAgentInstalled(agent: "codex"),
					isServerRunning: SplashService.shared.isRunning
				) {
					handleAgentLaunch(name: "Codex", command: "codex")
				}

				AgentButton(
					name: LocalizedStringResource("Hermes"),
					icon: "bolt.horizontal",
					command: "hermes",
					isInstalled: SplashService.shared.isAgentInstalled(agent: "hermes"),
					isServerRunning: SplashService.shared.isRunning
				) {
					handleAgentLaunch(name: "Hermes", command: "hermes")
				}

				AgentButton(
					name: LocalizedStringResource("Pi Agent"),
					icon: "character.cursor.ibeam",
					command: "pi",
					subtitle: LocalizedStringResource("pi.dev (Splash 1.3+)"),
					isInstalled: SplashService.shared.isAgentInstalled(agent: "pi"),
					isServerRunning: SplashService.shared.isRunning
				) {
					handleAgentLaunch(name: "Pi Agent", command: "pi")
				}

				AgentButton(
					name: LocalizedStringResource("DeepSeek Harness"),
					icon: "cpu.fill",
					command: "dsh",
					subtitle: LocalizedStringResource("App / dsh (DeepSeek AI)"),
					isInstalled: SplashService.shared.isAgentInstalled(agent: "dsh"),
					isServerRunning: SplashService.shared.isRunning
				) {
					handleAgentLaunch(name: "DeepSeek Harness", command: "dsh")
				}
			}
		}
	}

	private func handleAgentLaunch(name: String, command: String) {
		pendingAgentName = name
		pendingAgentCommand = command

		guard SplashService.shared.isRunning else {
			showingAgentOfflineAlert = true
			return
		}

		if !SplashService.shared.isAgentInstalled(agent: command) {
			showingAgentNotInstalledAlert = true
			return
		}

		SplashService.shared.launchAgent(agent: command)
	}

	// MARK: - 4. API Endpoints & Copy Helpers
	private var apiEndpointsView: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				Text("Integration Endpoints")
					.font(.system(size: 11, weight: .semibold))
					.foregroundColor(.secondary)
				Spacer()
				if let msg = copiedMessage {
					Text(msg)
						.font(.system(size: 10, weight: .medium))
						.foregroundColor(.green)
						.transition(.opacity)
				}
			}

			HStack(spacing: 8) {
				Button {
					let host = SplashService.shared.preferredHostOrIP
					copyToClipboard("http://\(host):\(SplashService.shared.activePort)/v1")
					showCopied("OpenAI URL copied!")
				} label: {
					Label("Copy OpenAI URL", systemImage: "doc.on.doc")
						.font(.system(size: 10))
				}
				.buttonStyle(.bordered)
				.controlSize(.small)

				Button {
					let host = SplashService.shared.preferredHostOrIP
					copyToClipboard("export OPENAI_BASE_URL=http://\(host):\(SplashService.shared.activePort)/v1\nexport ANTHROPIC_BASE_URL=http://\(host):\(SplashService.shared.activePort)")
					showCopied("Env Vars copied!")
				} label: {
					Label("Copy Env Vars", systemImage: "terminal")
						.font(.system(size: 10))
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
			}
		}
	}

	private func copyToClipboard(_ string: String) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(string, forType: .string)
	}

	private func showCopied(_ message: LocalizedStringResource) {
		let message = String(localized: message)
		withAnimation {
			copiedMessage = message
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
			withAnimation {
				if copiedMessage == message {
					copiedMessage = nil
				}
			}
		}
	}
}

struct AgentButton: View {
	let name: LocalizedStringResource
	let icon: String
	let command: String
	var subtitle: LocalizedStringResource? = nil
	let isInstalled: Bool
	let isServerRunning: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 6) {
				Image(systemName: icon)
					.font(.system(size: 11))
					.foregroundColor(isServerRunning ? .accentColor : .secondary)

				VStack(alignment: .leading, spacing: 1) {
					HStack(spacing: 4) {
						Text(name)
							.font(.system(size: 11, weight: .medium))

						Circle()
							.fill(isInstalled ? Color.green : Color.secondary.opacity(0.4))
							.frame(width: 5, height: 5)
					}

					Text(subtitle ?? "splash \(command)")
						.font(.system(size: 9, design: .monospaced))
						.foregroundColor(.secondary)
				}

				Spacer()

				Image(systemName: "arrow.up.forward.app")
					.font(.system(size: 9))
					.foregroundColor(isServerRunning ? .secondary : .secondary.opacity(0.4))
			}
			.padding(6)
			.background(Color(nsColor: .controlBackgroundColor))
			.cornerRadius(6)
			.opacity(isServerRunning ? 1.0 : 0.75)
		}
		.buttonStyle(.plain)
	}
}
