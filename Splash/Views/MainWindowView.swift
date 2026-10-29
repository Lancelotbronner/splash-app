import SwiftUI
import AppKit

struct MainWindowView: View {
	@State private var diagnosticService = ModelDiagnosticService()
	@State private var selectedSidebarItem: SidebarItem

	init(initialTab: SidebarItem = .dashboard) {
		self.selectedSidebarItem = initialTab
	}

	var body: some View {
		NavigationSplitView {
			// Sidebar
			VStack(alignment: .leading, spacing: 0) {
				// App Branding Header
				HStack(spacing: 10) {
					AppIconView(size: 28)

					VStack(alignment: .leading, spacing: 2) {
						HStack(spacing: 5) {
							Text("Splash Monitor")
								.font(.system(size: 15, weight: .bold))

							Text("BETA")
								.font(.system(size: 8, weight: .bold, design: .rounded))
								.foregroundColor(.white)
								.padding(.horizontal, 5)
								.padding(.vertical, 1)
								.background(Color.orange)
								.cornerRadius(3)
						}

						HStack(spacing: 4) {
							Circle()
								.fill(SplashService.shared.isRunning ? Color.green : Color.red)
								.frame(width: 7, height: 7)
							Text(SplashService.shared.isRunning ? (LocalizedStringResource("Online")) : (LocalizedStringResource("Stopped")))
								.font(.system(size: 11))
								.foregroundColor(.secondary)
						}
					}

					Spacer()
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 16)

				Divider()

				// Navigation items
				VStack(spacing: 3) {
					ForEach(SidebarItem.allCases) { item in
						Button {
							selectedSidebarItem = item
						} label: {
							HStack(spacing: 10) {
								Image(systemName: item.icon)
									.font(.system(size: 13, weight: .semibold))
									.foregroundColor(selectedSidebarItem == item ? .accentColor : .secondary)
									.frame(width: 20, alignment: .center)

								Text(item.title)
									.font(.system(size: 13, weight: selectedSidebarItem == item ? .semibold : .regular))
									.foregroundColor(selectedSidebarItem == item ? .primary : .secondary)

								Spacer()

								if item == .connectedApps {
									let count = SplashService.shared.connectedApps.filter { $0.status == .active }.count
									if count > 0 {
										Text("\(count)")
											.font(.system(size: 10, weight: .bold))
											.foregroundColor(.white)
											.padding(.horizontal, 6)
											.padding(.vertical, 1)
											.background(Color.green)
											.clipShape(Capsule())
									}
								}
							}
							.padding(.horizontal, 10)
							.padding(.vertical, 7)
							.background(
								RoundedRectangle(cornerRadius: 7)
									.fill(selectedSidebarItem == item ? Color.accentColor.opacity(0.15) : Color.clear)
							)
							.contentShape(Rectangle())
						}
						.buttonStyle(.plain)
					}
				}
				.padding(.horizontal, 10)
				.padding(.top, 10)

				Spacer()

				Divider()

				// Bottom Sidebar Controls (Language toggle & Status)
				HStack {
					Spacer()

					Button {
						Preferences.showMenuBarIcon.toggle()
					} label: {
						HStack(spacing: 4) {
							Image(systemName: Preferences.showMenuBarIcon ? "menubar.rectangle" : "rectangle.slash")
								.foregroundColor(Preferences.showMenuBarIcon ? .accentColor : .secondary)
							Text(Preferences.showMenuBarIcon ? (LocalizedStringResource("Menu: ON")) : (LocalizedStringResource("Menu: OFF")))
								.font(.system(size: 10, weight: .medium))
						}
					}
					.buttonStyle(.borderless)
					.help("Toggle icon in top menu bar")
				}
				.padding(12)
			}
			.frame(minWidth: 220, idealWidth: 240)
		} detail: {
			VStack(spacing: 0) {
				// Dependency missing banner / wizard
				if !SplashService.shared.isSplashInstalled {
					DependencyInstallView()
						.padding(16)
				}

				// Splash CLI engine update banner
				if SplashService.shared.hasSplashCliUpdate {
					splashCliUpdateBanner
				}

				// Update available banner
				if SplashService.shared.hasUpdate {
					updateBanner
				}

				// First-launch or pending prompt to place icon in top menu bar
				if !Preferences.hasAskedAboutMenuBar {
					menuBarPromptBanner
				}

				// Main Content View
				ScrollView {
					VStack(alignment: .leading, spacing: 18) {
						switch selectedSidebarItem {
						case .dashboard:
							dashboardDetailView
						case .connectedApps:
							ConnectedAppsView()
						case .models:
							ModelManagerView()
						case .server:
							ServerControlView()
						case .modelTesting:
							ModelTestingView()
						case .settings:
							settingsDetailView
						case .about:
							AboutView()
						}
					}
					.padding(24)
				}
			}
			.frame(minWidth: 560, minHeight: 480)
			.background(Color(nsColor: .windowBackgroundColor))
			.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAboutView"))) { _ in
				selectedSidebarItem = .about
			}
		}
		.environment(diagnosticService)
	}

	// MARK: - Splash CLI Engine Update Available Banner
	private var splashCliUpdateBanner: some View {
		HStack(spacing: 12) {
			Image(systemName: "flame.circle.fill")
				.font(.system(size: 22))
				.foregroundColor(.orange)

			VStack(alignment: .leading, spacing: 2) {
				Text("New Splash engine version available")
					.font(.system(size: 12, weight: .semibold))
				Text("Splash CLI \(SplashService.shared.latestSplashCliVersion.isEmpty ? String(localized: "new version") : SplashService.shared.latestSplashCliVersion) is available (installed: \(SplashService.shared.installedSplashCliVersion.isEmpty ? String(localized: "unknown") : SplashService.shared.installedSplashCliVersion))."
				)
				.font(.system(size: 11))
				.foregroundColor(.secondary)
			}

			Spacer()

			Button("Upgrade Splash") {
				SplashService.shared.upgradeSplashInTerminal()
			}
			.buttonStyle(.borderedProminent)
			.tint(.orange)
			.controlSize(.small)

			if !SplashService.shared.latestSplashCliReleaseURL.isEmpty, let url = URL(string: SplashService.shared.latestSplashCliReleaseURL) {
				Button("View notes") {
					NSWorkspace.shared.open(url)
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
			}

			Button("Skip") {
				SplashService.shared.hasSplashCliUpdate = false
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.background(Color.orange.opacity(0.12))
		.overlay(
			Rectangle()
				.frame(height: 1)
				.foregroundColor(Color.orange.opacity(0.2)),
			alignment: .bottom
		)
	}

	// MARK: - Update Available Banner
	private var updateBanner: some View {
		HStack(spacing: 12) {
			Image(systemName: "arrow.down.circle.fill")
				.font(.system(size: 22))
				.foregroundColor(.green)

			VStack(alignment: .leading, spacing: 2) {
				Text("Update available")
					.font(.system(size: 12, weight: .semibold))
				Text("Splash Monitor \(SplashService.shared.latestVersion ?? String(localized: "new version")) is available for download.")
					.font(.system(size: 11))
					.foregroundColor(.secondary)
			}

			Spacer()

			Button("Download") {
				if let url = URL(string: SplashService.shared.latestReleaseURL ?? "https://github.com/hometrix/SplashMonitor/releases/latest") {
					NSWorkspace.shared.open(url)
				}
			}
			.buttonStyle(.borderedProminent)
			.tint(.green)
			.controlSize(.small)

			Button("Skip") {
				SplashService.shared.hasUpdate = false
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.background(Color.green.opacity(0.12))
		.overlay(
			Rectangle()
				.frame(height: 1)
				.foregroundColor(Color.green.opacity(0.2)),
			alignment: .bottom
		)
	}

	// MARK: - Menu Bar Prompt Banner
	private var menuBarPromptBanner: some View {
		HStack(spacing: 12) {
			Image(systemName: "menubar.arrow.up.rectangle")
				.font(.system(size: 22))
				.foregroundColor(.accentColor)

			VStack(alignment: .leading, spacing: 2) {
				Text("Would you like to place the monitor in the top menu bar?")
					.font(.system(size: 12, weight: .semibold))
				Text("You'll be able to see token speed in tok/s and token usage next to Bluetooth and Wi-Fi.")
					.font(.system(size: 11))
					.foregroundColor(.secondary)
			}

			Spacer()

			Button("Yes, place in menu bar") {
				Preferences.showMenuBarIcon = true
				Preferences.hasAskedAboutMenuBar = true
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.small)

			Button("Not now") {
				Preferences.showMenuBarIcon = false
				Preferences.hasAskedAboutMenuBar = true
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.background(Color.accentColor.opacity(0.12))
		.overlay(
			Rectangle()
				.frame(height: 1)
				.foregroundColor(Color.accentColor.opacity(0.2)),
			alignment: .bottom
		)
	}

	// MARK: - Dashboard Detail View
	private var dashboardDetailView: some View {
		VStack(alignment: .leading, spacing: 18) {
			HStack {
				VStack(alignment: .leading, spacing: 4) {
					Text("Splash Local Inference Monitor")
						.font(.system(size: 20, weight: .bold))
					Text("Real-time token metrics, throughput, and Metal memory")
						.font(.system(size: 12))
						.foregroundColor(.secondary)
				}

				Spacer()

				HStack(spacing: 8) {
					Button {
						Task { await SplashService.shared.checkServerStatus() }
					} label: {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}
			}

			// MARK: Modelo activo
			activeModelCard

			Divider()

			// Embed the token metrics view
			TokenMetricsView()
		}
	}

	/// Tarjeta compacta que muestra el modelo en ejecución, puerto y versión de Splash.
	@ViewBuilder
	private var activeModelCard: some View {
		let isRunning = SplashService.shared.isRunning
		let modelRaw  = SplashService.shared.activeModel
		let modelShort = modelRaw.components(separatedBy: "/").last ?? modelRaw
		let modelClean = modelShort
			.replacingOccurrences(of: "-Splash", with: "")
			.replacingOccurrences(of: "-GGUF", with: "")

		HStack(spacing: 12) {
			// Estado indicator
			Circle()
				.fill(isRunning ? Color.green : Color.secondary.opacity(0.4))
				.frame(width: 10, height: 10)
				.shadow(color: isRunning ? .green.opacity(0.6) : .clear, radius: 4)

			// Nombre del modelo
			VStack(alignment: .leading, spacing: 2) {
				// §9: literal ya en mayúsculas; el .textCase no afectaba al catálogo.
				Text("RUNNING MODEL")
					.font(.system(size: 10, weight: .medium))
					.foregroundColor(.secondary)

				if isRunning {
					Text(modelClean)
						.font(.system(size: 13, weight: .semibold, design: .monospaced))
						.lineLimit(1)
						.truncationMode(.middle)

					Text(modelRaw)
						.font(.system(size: 10))
						.foregroundColor(.secondary)
						.lineLimit(1)
						.truncationMode(.middle)
				} else {
					Text("Server Stopped")
						.font(.system(size: 13, weight: .semibold))
						.foregroundColor(.secondary)
				}
			}

			Spacer()

			// Puerto y versión Splash
			VStack(alignment: .trailing, spacing: 4) {
				if isRunning {
					HStack(spacing: 4) {
						Image(systemName: "network")
							.font(.system(size: 10))
							.foregroundColor(.secondary)
						Text(":\(SplashService.shared.activePort)")
							.font(.system(size: 12, weight: .medium, design: .monospaced))
					}
				}

				if let splashVer = SplashService.shared.splashVersion {
					HStack(spacing: 4) {
						Image(systemName: "cpu")
							.font(.system(size: 10))
							.foregroundColor(.secondary)
						Text("Splash \(splashVer)")
							.font(.system(size: 11))
							.foregroundColor(.secondary)
					}
				}
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.background(
			RoundedRectangle(cornerRadius: 10)
				.fill(Color(nsColor: .controlBackgroundColor))
				.overlay(
					RoundedRectangle(cornerRadius: 10)
						.strokeBorder(
							isRunning ? Color.green.opacity(0.35) : Color.secondary.opacity(0.15),
							lineWidth: 1
						)
				)
		)
	}


	// MARK: - Settings Detail View
	private var settingsDetailView: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Splash Monitor Settings")
				.font(.system(size: 18, weight: .bold))

			Divider()

			// Perfil de Rendimiento Óptimo (Apple Silicon M4 Max / 64 GB)
			SettingsOptimalProfileCard()

			// Menu bar icon toggle
			SettingsMenuBarCard()

			// Inicio Automático al Encender el Mac (Launch at Login)
			SettingsStartupCard()

			// Notificaciones de macOS
			SettingsNotificationsCard()

			// Shell integration (P-09)
			SettingsShellCard()

			// Refresh rate
			SettingsRefreshCard()

			// Server Network & Context Options
			SettingsEngineCard()

			// Check for updates
			SettingsUpdatesCard()

			// Dependencies & CLI System Info
			SettingsCLIInfoCard()
		}
	}
}

// MARK: - Tarjetas de Configuración (§3.2)
//
// Antes, `settingsDetailView` era un único cuerpo de ~470 líneas: cualquier
// cambio de estado (un toggle, el slider, un check-for-update) re-evaluaba
// las nueve secciones a la vez. Cada tarjeta es ahora un struct independiente
// que solo depende de sus propias preferencias.

/// Perfil de rendimiento óptimo (M4 Max / 64 GB).
private struct SettingsOptimalProfileCard: View {
	@State private var showOptimalAppliedFeedback = false

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 10) {
				Image(systemName: "bolt.fill")
					.font(.system(size: 18, weight: .semibold))
					.foregroundColor(.orange)

				VStack(alignment: .leading, spacing: 2) {
					HStack(spacing: 6) {
						Text("Optimal Performance Profile")
							.font(.system(size: 13, weight: .bold))

						Text("M4 MAX / 64 GB")
							.font(.system(size: 9, weight: .bold, design: .rounded))
							.foregroundColor(.white)
							.padding(.horizontal, 5)
							.padding(.vertical, 1)
							.background(Color.blue)
							.cornerRadius(3)
					}

					Text("Restores recommended high-speed and capacity settings for Apple Silicon: GDN BF16 (-50% RAM), Thinking Budget 8K, Persistent SSD cache, Context 128K, Idle off (Always in RAM), Port 8005, LAN 0.0.0.0, and open CORS (*).")
						.font(.system(size: 11))
						.foregroundColor(.secondary)
				}

				Spacer()

				Button {
					SplashService.shared.restoreOptimalProfile()
					Preferences.showMenuBarIcon = true
					withAnimation {
						showOptimalAppliedFeedback = true
					}
					// §7: Task cancelable en lugar de asyncAfter sin gestión.
					Task {
						try? await Task.sleep(for: .seconds(4))
						withAnimation {
							showOptimalAppliedFeedback = false
						}
					}
				} label: {
					HStack(spacing: 5) {
						Image(systemName: "sparkles")
						Text("Restore Optimal Configuration")
					}
					.font(.system(size: 11, weight: .semibold))
				}
				.buttonStyle(.borderedProminent)
				.tint(.blue)
				.controlSize(.regular)
			}

			if showOptimalAppliedFeedback {
				HStack(spacing: 6) {
					Image(systemName: "checkmark.circle.fill")
						.foregroundColor(.green)
						.font(.system(size: 12))
					Text("Optimal configuration restored and saved successfully in UserDefaults (M4 Max / 64 GB)!")
						.font(.system(size: 11, weight: .medium))
						.foregroundColor(.green)
					Spacer()
				}
				.padding(8)
				.background(Color.green.opacity(0.12))
				.cornerRadius(6)
				.transition(.opacity)
			}
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
		.overlay(
			RoundedRectangle(cornerRadius: 10)
				.stroke(Color.blue.opacity(0.25), lineWidth: 1)
		)
	}
}

/// Icono de barra de menú superior y modo solo-menú.
private struct SettingsMenuBarCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Top Menu Bar (macOS Status Bar)")
				.font(.system(size: 13, weight: .semibold))

			Toggle("Show icon and metrics in the top bar next to Bluetooth", isOn: Preferences.$showMenuBarIcon)
				.font(.system(size: 12))

			if Preferences.showMenuBarIcon {
				Text("Information in menu bar:")
					.font(.system(size: 11))
					.foregroundColor(.secondary)

				// §5.4: etiqueta con significado (antes `Picker("empty", …)`).
				Picker("Menu bar display mode", selection: Preferences.$menuBarDisplayMode) {
					Text("Icon Only").tag("icon")
					Text("Icon + Speed (tok/s)").tag("speed")
					Text("Icon + Tokens Used").tag("tokens")
					Text("Icon + Model").tag("model")
				}
				.pickerStyle(.radioGroup)
				.font(.system(size: 11))

				Divider()
					.padding(.vertical, 4)

				// Modo Solo Barra de Menú
				Toggle(isOn: Preferences.$menuBarOnlyMode) {
					VStack(alignment: .leading, spacing: 2) {
						Text("Menu Bar Only Mode")
							.font(.system(size: 12))
						Text("Cmd+Q hides the app from the Dock and task list instead of quitting. Use Cmd+Shift+Q to quit completely.")
							.font(.system(size: 10))
							.foregroundColor(.secondary)
					}
				}
				.font(.system(size: 12))
			}
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
	}
}

/// Arranque automático con el sistema.
private struct SettingsStartupCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("System Startup")
				.font(.system(size: 13, weight: .semibold))

			Toggle(isOn: AutoLaunchService.$shared.isEnabled) {
				VStack(alignment: .leading, spacing: 2) {
					Text("Launch Splash Monitor at startup")
						.font(.system(size: 12))
					Text("Automatically launch the app in background when logging in to macOS.")
						.font(.system(size: 10))
						.foregroundColor(.secondary)
				}
			}
			.font(.system(size: 12))
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
	}
}

/// Notificaciones del sistema.
private struct SettingsNotificationsCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("macOS Notifications")
				.font(.system(size: 13, weight: .semibold))

			Toggle(isOn: NotificationService.$shared.isNotificationsEnabled) {
				VStack(alignment: .leading, spacing: 2) {
					Text("System alerts and notifications")
						.font(.system(size: 12))
					Text("Receive alerts when the server starts, stops unexpectedly, or if unified memory enters critical pressure.")
						.font(.system(size: 10))
						.foregroundColor(.secondary)
				}
			}
			.font(.system(size: 12))
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
	}
}

/// Consentimiento de integración con el shell (P-09).
private struct SettingsShellCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Shell Integration")
				.font(.system(size: 13, weight: .semibold))

			Toggle("Allow Splash Monitor to add a line to your ~/.zshrc",
				   isOn: Binding(
				get: { Preferences.shellConfigConsent },
				set: { allowed in
					Preferences.shellConfigConsent = allowed
					Preferences.shellConfigDeclined = !allowed
					if allowed {
						SplashService.shared.syncShellEnvironment(port: SplashService.shared.activePort)
					} else {
						SplashService.shared.clearShellEnvironment()
					}
				}
				   ))
			.font(.system(size: 12))

			Text("Without this line, agents launched from an external terminal do not inherit the active port. The ~/.splash_monitor_env file is always written, with or without permission.")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			if Preferences.shellConfigConsent {
				Button("Undo changes to ~/.zshrc") {
					SplashService.shared.clearShellEnvironment()
					Preferences.shellConfigConsent = false
					Preferences.shellConfigDeclined = true
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.font(.system(size: 11))
			}
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
	}
}

/// Intervalo de sondeo.
private struct SettingsRefreshCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Refresh Interval")
				.font(.system(size: 13, weight: .semibold))

			HStack {
				// §5.1: el reinicio del sondeo se hace al soltar el slider
				// (onEditingChanged), no en cada paso del onChange.
				Slider(value: Preferences.$refreshInterval, in: 0.5...5.0, step: 0.5,
					   onEditingChanged: { editing in
						   guard !editing else { return }
						   SplashService.shared.startPolling()
					   }) {
					Text("Refresh Interval")
				}
				.labelsHidden()
				Text("\(Preferences.refreshInterval, format: .number.precision(.fractionLength(1))) s")
					.font(.system(size: 12, design: .monospaced))
					.frame(width: 50)
			}
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
	}
}

/// Opciones del motor de inferencia (red, contexto, memoria, flags).
private struct SettingsEngineCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Inference Engine Options")
				.font(.system(size: 13, weight: .semibold))

			Toggle("Allow incoming connections from local network (bind to 0.0.0.0)",
				   isOn: Preferences.$listenOnAllInterfaces)
			.font(.system(size: 12))

			Text("By default, Splash only listens on 127.0.0.1 (localhost). Enable this option to let other devices, servers, or agents on your local network (LAN) run inference on this Mac.")
				.font(.system(size: 10))
			if Preferences.listenOnAllInterfaces {
				VStack(alignment: .leading, spacing: 4) {
					Text("Allowed Domains or Hosts (--allowed-host):")
						.font(.system(size: 11, weight: .medium))

					TextField("e.g. mydomain.duckdns.org, mymac.local", text: Preferences.$allowedHosts)
						.textFieldStyle(.roundedBorder)
						.font(.system(size: 11, design: .monospaced))

					Text("Splash blocks requests with unknown Host headers for security (DNS Rebinding protection). Enter your DDNS domains or hostnames separated by commas.")
						.font(.system(size: 10))
						.foregroundColor(.secondary)
				}
				.padding(.top, 4)
			}

			VStack(alignment: .leading, spacing: 4) {
				Text("Allowed Web Origins & Extensions (--allowed-origin):")
					.font(.system(size: 11, weight: .medium))

				TextField("e.g. * (for Chrome extension and local web)", text: Preferences.$allowedOrigins)
					.textFieldStyle(.roundedBorder)
					.font(.system(size: 11, design: .monospaced))

				Text("Allows browser extensions (Chrome, Arc, Brave), local web apps, and Tauri to interact with Splash via CORS. Default '*' allows any local origin or extension.")
					.font(.system(size: 10))
					.foregroundColor(.secondary)
			}
			.padding(.top, 4)

			Divider()

			HStack {
				Text("Context window limit:")
					.font(.system(size: 12))

				Spacer()

				// §5.4: etiquetas con significado + labelsHidden (antes `Picker("empty", …)`).
				Picker("Context window limit", selection: Preferences.$maxContext) {
					Text("Automatic (managed by Splash)").tag("auto")
					Text("16K (16,384 tokens)").tag("16K")
					Text("32K (32,768 tokens)").tag("32K")
					Text("64K (65,536 tokens)").tag("64K")
					Text("128K (131,072 tokens)").tag("128K")
					Text("256K (262,144 tokens)").tag("256K")
					Text("512K (524,288 tokens)").tag("512K")
					Text("1M (1,000,000 tokens · YaRN)").tag("1M")
				}
				.labelsHidden()
				.frame(width: 250)
			}

			Text("Configures the --max-context flag to limit or expand memory reserved for token history (Splash 1.4.0+ supports up to 1M with YaRN).")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			Divider()

			HStack {
				Text("Idle memory release timeout:")
					.font(.system(size: 12))
				Spacer()
				Picker("Idle memory release timeout", selection: Preferences.$idleRelease) {
					Text("1 min (Fast saving)").tag("1m")
					Text("2 min (Aggressive)").tag("2m")
					Text("5 min (Balanced)").tag("5m")
					Text("10 min (Splash default)").tag("10m")
					Text("30 min (Extended)").tag("30m")
					Text("Disabled (Always in RAM)").tag("off")
				}
				.labelsHidden()
				.frame(width: 250)
			}

			Text("Flag --idle-release: unwires and frees VRAM model weights when idle, restoring them on-the-fly when new queries arrive.")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			Divider()

			HStack {
				Text("Max Metal memory budget:")
					.font(.system(size: 12))
				Spacer()
				Picker("Max Metal memory budget", selection: Preferences.$maxMemory) {
					Text("Automatic (unlimited)").tag("auto")
					Text("16 GB").tag("16G")
					Text("24 GB").tag("24G")
					Text("28 GB").tag("28G")
					Text("32 GB").tag("32G")
					Text("40 GB").tag("40G")
					Text("48 GB").tag("48G")
					Text("64 GB").tag("64G")
				}
				.labelsHidden()
				.frame(width: 250)
			}

			Text("Flag --max-memory: limits the Metal unified memory budget to avoid exhausting Mac RAM.")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			Divider()

			Toggle("Automatic protection under macOS critical memory pressure",
				   isOn: Preferences.$autoReleaseOnMemoryPressure)
			.font(.system(size: 12))

			Text("Monitors macOS kernel events. If the system enters critical memory pressure and Splash is idle, frees resources to prevent system freezing.")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			Divider()

			Toggle("Language / Code Only mode (--language-only)",
				   isOn: Preferences.$languageOnly)
			.font(.system(size: 12))

			Text("Disables vision projector (mmproj) loading. Required for GGUF coder models (like Tiel-Coder, Qwopus, Cyber-Tiel) that lack image weights.")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			Divider()

			HStack {
				Text("MoE Draft Verification (--verify-rows):")
					.font(.system(size: 12))
				Spacer()
				Picker("MoE draft verification", selection: Preferences.$verifyRows) {
					Text("Auto (Adaptive, +13–42% speed)").tag("auto")
					Text("All (All rows, Deterministic)").tag("all")
				}
				.labelsHidden()
				.frame(width: 250)
			}

			Text("Flag --verify-rows (Splash 1.4.0+): 'auto' adapts speculative draft token verification for faster decode. 'all' ensures deterministic output reproducibility.")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			Divider()

			HStack {
				Text("MoE Experts RAM Budget (--expert-memory):")
					.font(.system(size: 12))
				Spacer()
				Picker("MoE experts RAM budget", selection: Preferences.$expertMemory) {
					Text("Automatic (managed by Splash)").tag("auto")
					Text("Disabled (All resident in RAM)").tag("off")
					Text("4 GB (Streaming SSD)").tag("4G")
					Text("8 GB (Streaming SSD)").tag("8G")
					Text("12 GB (Streaming SSD)").tag("12G")
					Text("16 GB (Streaming SSD)").tag("16G")
					Text("24 GB (Streaming SSD)").tag("24G")
				}
				.labelsHidden()
				.frame(width: 250)
			}

			Text("Flag --expert-memory (Splash 1.4.0+): retains active MoE experts in RAM and streams the rest on-the-fly from the high-speed SSD.")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			Divider()

			VStack(alignment: .leading, spacing: 4) {
				Text("Additional Splash CLI Flags:")
					.font(.system(size: 11, weight: .medium))

				TextField("e.g. --no-webui --max-cache-disk 50GB", text: Preferences.$customServerFlags)
					.textFieldStyle(.roundedBorder)
					.font(.system(size: 11, design: .monospaced))

				Text("Arbitrary additional flags passed directly to 'splash serve'. Automatically sanitized to prevent command injection.")
					.font(.system(size: 10))
					.foregroundColor(.secondary)
			}
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
	}
}

/// Actualizaciones de Splash Monitor.
private struct SettingsUpdatesCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text("Splash Monitor Updates")
					.font(.system(size: 13, weight: .semibold))
				Spacer()
				if SplashService.shared.hasUpdate {
					Text("New version: \(SplashService.shared.latestVersion ?? "")!")
						.font(.system(size: 10, weight: .medium))
						.foregroundColor(.green)
				} else {
					Text("You're up to date")
						.font(.system(size: 10))
						.foregroundColor(.secondary)
				}
			}

			HStack(spacing: 8) {
				Button {
					Task { await SplashService.shared.checkForUpdate() }
				} label: {
					Label("Check for updates", systemImage: "arrow.clockwise")
						.font(.system(size: 11))
				}
				.buttonStyle(.bordered)
				.controlSize(.small)

				if SplashService.shared.hasUpdate, let url = SplashService.shared.latestReleaseURL {
					Button {
						if let releaseURL = URL(string: url) {
							NSWorkspace.shared.open(releaseURL)
						}
					} label: {
						Label("Download new version", systemImage: "arrow.down.circle")
							.font(.system(size: 11))
					}
					.buttonStyle(.borderedProminent)
					.tint(.green)
					.controlSize(.small)
				}
			}
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
	}
}

/// Estado del motor Splash CLI y atajos de instalación/actualización.
private struct SettingsCLIInfoCard: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Text("Splash CLI Inference Engine")
					.font(.system(size: 13, weight: .semibold))
				Spacer()
				if SplashService.shared.hasSplashCliUpdate {
					Text("New version: \(SplashService.shared.latestSplashCliVersion)!")
						.font(.system(size: 10, weight: .bold))
						.foregroundColor(.orange)
				}
				HStack(spacing: 4) {
					Circle()
						.fill(SplashService.shared.isSplashInstalled ? Color.green : Color.orange)
						.frame(width: 7, height: 7)
					Text(SplashService.shared.isSplashInstalled
						 ? (!SplashService.shared.installedSplashCliVersion.isEmpty ? "v\(SplashService.shared.installedSplashCliVersion)" : (SplashService.shared.splashVersion ?? ("Installed")))
						 : ("Not installed"))
					.font(.system(size: 11, weight: .medium))
					.foregroundColor(SplashService.shared.isSplashInstalled ? .green : .orange)
				}
			}

			VStack(alignment: .leading, spacing: 4) {
				Text("Splash CLI: \(SplashService.shared.splashExecutablePath)")
					.font(.system(size: 10, design: .monospaced))
					.foregroundColor(.secondary)

				Text("Python Backend: \(SplashService.shared.splashPythonPath)")
					.font(.system(size: 10, design: .monospaced))
					.foregroundColor(.secondary)

				Text("Models Directory: \(SplashService.shared.modelsDirectory.path)")
					.font(.system(size: 10, design: .monospaced))
					.foregroundColor(.secondary)
			}

			Divider()

			HStack(spacing: 8) {
				if SplashService.shared.isSplashInstalled {
					if SplashService.shared.hasSplashCliUpdate {
						Button {
							SplashService.shared.upgradeSplashInTerminal()
						} label: {
							Label("Upgrade Splash (brew upgrade)", systemImage: "arrow.up.circle")
								.font(.system(size: 11))
						}
						.buttonStyle(.borderedProminent)
						.tint(.orange)
						.controlSize(.small)
					} else {
						Button {
							SplashService.shared.upgradeSplashInTerminal()
						} label: {
							Label("Upgrade Splash (brew upgrade)", systemImage: "arrow.up.circle")
								.font(.system(size: 11))
						}
						.buttonStyle(.bordered)
						.controlSize(.small)
					}
				} else {
					Button {
						SplashService.shared.installSplashDependency()
					} label: {
						Label("Install Splash (brew install)", systemImage: "arrow.down.circle.fill")
							.font(.system(size: 11, weight: .bold))
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
				}

				Button {
					Task {
						SplashService.shared.checkDependencies()
						SplashService.shared.refreshInstalledModels()
						await SplashService.shared.checkSplashCliUpdate()
					}
				} label: {
					if SplashService.shared.isCheckingSplashCliUpdate {
						ProgressView()
							.controlSize(.small)
					} else {
						Label("Check update", systemImage: "arrow.clockwise")
							.font(.system(size: 11))
					}
				}
				.buttonStyle(.bordered)
				.controlSize(.small)

				Spacer()

				Link(destination: URL(string: "https://github.com/incoai/splash")!) {
					HStack(spacing: 3) {
						Text("GitHub incoai/splash")
						Image(systemName: "arrow.up.right.square")
					}
					.font(.system(size: 10))
				}
			}
		}
		.padding(14)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
	}
}

enum SidebarItem: String, CaseIterable, Identifiable {
	case dashboard
	case connectedApps
	case models
	case server
	case modelTesting
	case settings
	case about

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
		case .dashboard: return LocalizedStringResource("Token Dashboard")
		case .connectedApps: return LocalizedStringResource("Connected Apps")
		case .models: return LocalizedStringResource("Model Manager")
		case .server: return LocalizedStringResource("Server & Agents")
		case .modelTesting: return LocalizedStringResource("Model Testing")
		case .settings: return LocalizedStringResource("Configuration")
		case .about: return LocalizedStringResource("About")
		}
	}

	var icon: String {
		switch self {
		case .dashboard: return "speedometer"
		case .connectedApps: return "app.connected.to.app.below.fill"
		case .models: return "shippingbox"
		case .server: return "server.rack"
		case .modelTesting: return "testtube.2"
		case .settings: return "gearshape"
		case .about: return "info.circle"
		}
	}
}
