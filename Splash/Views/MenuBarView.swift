import SwiftUI
import AppKit

struct MenuBarView: View {
	@Environment(\.openWindow) private var openWindow
	@State private var activeTab: AppTab = .metrics
	// §5.1: el slider escribe la preferencia al soltar (onEditingChanged), no en cada
	// paso; el reinicio del sondeo se hace entonces, una sola vez.
	@State private var refreshIntervalDraft: Double = Preferences.refreshInterval

	enum AppTab: String, CaseIterable, Identifiable {
		case metrics
		case models
		case server
		case settings
		case about

		var id: String { rawValue }

		var title: LocalizedStringResource {
			switch self {
			case .metrics: return LocalizedStringResource("Metrics")
			case .models: return LocalizedStringResource("Models")
			case .server: return LocalizedStringResource("Server")
			case .settings: return LocalizedStringResource("Settings")
			case .about: return LocalizedStringResource("About")
			}
		}

		var icon: String {
			switch self {
			case .metrics: return "speedometer"
			case .models: return "shippingbox"
			case .server: return "server.rack"
			case .settings: return "gearshape"
			case .about: return "info.circle"
			}
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			// Header — §3.2: estructura independiente con entradas de valor; el cuerpo
			// principal no vuelve a correr por isRunning/activeModel.
			MenuBarHeaderView(
				isSplashInstalled: SplashService.shared.isSplashInstalled,
				isRunning: SplashService.shared.isRunning,
				activeModel: SplashService.shared.activeModel,
				onOpenMainWindow: openMainWindow
			)
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
				.background(Color(nsColor: .windowBackgroundColor).opacity(0.8))

			Divider()

			// Tab Selector Bar
			tabSelectorBar
				.padding(.horizontal, 14)
				.padding(.vertical, 8)
				.background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

			Divider()

			// Main Content Area
			ScrollView {
				VStack(spacing: 12) {
					if !SplashService.shared.isSplashInstalled {
						DependencyInstallView()
					}

					switch activeTab {
					case .metrics:
						TokenMetricsView()
					case .models:
						ModelManagerView()
					case .server:
						ServerControlView()
					case .settings:
						settingsView
					case .about:
						AboutView()
					}
				}
				.padding(14)
			}
			.frame(maxHeight: 460)

			Divider()

			// Footer
			footerView
				.padding(.horizontal, 14)
				.padding(.vertical, 8)
				.background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
		}
		.frame(width: 440)
	}

	// MARK: - Header
	private struct MenuBarHeaderView: View {
		let isSplashInstalled: Bool
		let isRunning: Bool
		let activeModel: String
		let onOpenMainWindow: () -> Void

		var body: some View {
		HStack(spacing: 8) {
			AppIconView(size: 20)

			VStack(alignment: .leading, spacing: 1) {
				HStack(spacing: 5) {
					Text("Splash Monitor")
						.font(.system(size: 13, weight: .bold))

					Text("BETA")
						.font(.system(size: 8, weight: .bold, design: .rounded))
						.foregroundColor(.white)
						.padding(.horizontal, 4)
						.padding(.vertical, 1)
						.background(Color.orange)
						.cornerRadius(3)

					if !isSplashInstalled {
						// §9: literal ya en mayúsculas; el .textCase no afectaba al catálogo.
						Text("BREW")
							.font(.system(size: 7, weight: .bold, design: .monospaced))
							.foregroundColor(.white)
							.padding(.horizontal, 3)
							.padding(.vertical, 1)
							.background(Color.red)
							.cornerRadius(3)
					}
				}

				HStack(spacing: 4) {
					Circle()
						.fill(isRunning ? Color.green : (isSplashInstalled ? Color.red : Color.orange))
						.frame(width: 6, height: 6)

					if !isSplashInstalled {
						Text("Needs Splash")
							.font(.system(size: 10, weight: .medium))
							.foregroundColor(.orange)
					} else {
						Text(isRunning ? activeModel.components(separatedBy: "/").last ?? activeModel : String(localized: "Offline"))
							.font(.system(size: 10))
							.foregroundColor(.secondary)
							.lineLimit(1)
					}
				}
			}

			Spacer()

			// Free memory button if running — §10: etiqueta de accesibilidad en el botón.
			if isRunning {
				Button("Release memory", systemImage: "arrow.down.right.and.arrow.up.left") {
					SplashService.shared.releaseMemoryNow()
				}
				.labelStyle(.iconOnly)
				.font(.system(size: 11))
				.foregroundColor(.orange)
				.buttonStyle(.plain)
				.help("Release memory (Unload model weights)")
			}

			// Stop server button if running
			if isRunning {
				Button("Stop Splash server", systemImage: "stop.circle.fill") {
					SplashService.shared.stopServer()
				}
				.labelStyle(.iconOnly)
				.font(.system(size: 13))
				.foregroundColor(.red)
				.buttonStyle(.plain)
				.help("Stop Splash Server")
			}

			// Open full window button
			Button("Open full application window", systemImage: "macwindow") {
				onOpenMainWindow()
			}
			.labelStyle(.iconOnly)
			.font(.system(size: 11))
			.buttonStyle(.plain)
			.help("Open full application window")

			Button("Refresh now", systemImage: "arrow.clockwise") {
				Task {
					await SplashService.shared.checkServerStatus()
				}
			}
			.labelStyle(.iconOnly)
			.font(.system(size: 11))
			.buttonStyle(.plain)
			.help("Refresh now")

			Button("Quit Splash Monitor", systemImage: "power") {
				NSApplication.shared.terminate(nil)
			}
			.labelStyle(.iconOnly)
			.font(.system(size: 11))
			.foregroundColor(.secondary)
			.buttonStyle(.plain)
			.help("Quit Splash Monitor (Exit app)")
		}
		}
	}

	// MARK: - Tab Selector Bar
	private var tabSelectorBar: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 4) {
				ForEach(AppTab.allCases) { tab in
					Button {
						withAnimation(.easeInOut(duration: 0.15)) {
							activeTab = tab
						}
					} label: {
						HStack(spacing: 4) {
							Image(systemName: tab.icon)
								.font(.system(size: 10))
							Text(tab.title)
								.font(.system(size: 11, weight: activeTab == tab ? .semibold : .regular))
						}
						.padding(.horizontal, 8)
						.padding(.vertical, 4)
						.background(activeTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
						.foregroundColor(activeTab == tab ? .accentColor : .secondary)
						.cornerRadius(6)
					}
					.buttonStyle(.plain)
				}
			}
			.padding(.horizontal, 4)
		}
	}

	// MARK: - Refresh Interval Section
	private var refreshIntervalSection: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("Refresh Interval")
				.font(.system(size: 11, weight: .semibold))

			HStack {
				// §5.1: el reinicio del sondeo se hace al soltar el slider
				// (onEditingChanged), no en cada paso del onChange.
				Slider(value: $refreshIntervalDraft, in: 0.5...5.0, step: 0.5,
					   onEditingChanged: { editing in
						   guard !editing else { return }
						   Preferences.refreshInterval = refreshIntervalDraft
						   SplashService.shared.startPolling()
					   }) {
					Text("Refresh Interval")
				}
				.labelsHidden()
				Text("\(refreshIntervalDraft, format: .number.precision(.fractionLength(1))) s")
					.font(.system(size: 11, design: .monospaced))
					.frame(width: 45)
			}
		}
	}

	// MARK: - Settings View
	@ViewBuilder
	private var settingsView: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Menu Bar Configuration")
				.font(.system(size: 12, weight: .semibold))

			VStack(alignment: .leading, spacing: 6) {
				Text("Information shown in top bar:")
					.font(.system(size: 11))
					.foregroundColor(.secondary)

				Picker("Menu bar display mode", selection: Preferences.$menuBarDisplayMode) {
					Text("Icon Only").tag("icon")
					Text("Icon + Speed (tok/s)").tag("speed")
					Text("Icon + Tokens Used").tag("tokens")
					Text("Icon + Active Model").tag("model")
				}
				.pickerStyle(.radioGroup)
				.labelsHidden()
				.font(.system(size: 11))
			}
			.padding(10)
			.background(Color(nsColor: .controlBackgroundColor))
			.cornerRadius(8)

			refreshIntervalSection
			.padding(10)
			.background(Color(nsColor: .controlBackgroundColor))
			.cornerRadius(8)

			// Open full window button
			Button {
				openMainWindow()
			} label: {
				HStack {
					Image(systemName: "macwindow")
					Text("Open Full Main Window")
				}
				.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.regular)
		}
	}

	// MARK: - Footer
	private var footerView: some View {
		HStack {
			Link("inco.ai/blog/splash", destination: URL(string: "https://inco.ai/blog/splash/")!)
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			Spacer()

			Link("Hugging Face incoai", destination: URL(string: "https://huggingface.co/incoai")!)
				.font(.system(size: 10))
				.foregroundColor(.secondary)
		}
	}

	private func openMainWindow() {
		NSApp.activate(ignoringOtherApps: true)
		if let existing = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
			if existing.isMiniaturized {
				existing.deminiaturize(nil)
			}
			existing.makeKeyAndOrderFront(nil)
			return
		}
		openWindow(id: "main")
		// §7: Task cancelable en lugar de asyncAfter sin gestión.
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(100))
			for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
				window.makeKeyAndOrderFront(nil)
				return
			}
		}
	}
}
