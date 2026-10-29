import SwiftUI
import AppKit

struct ConnectedAppsView: View {
	// §6.3: asignación directa vía macro (la forma `init` con `State(initialValue:)`
	// queda fuera del soporte de migración de la macro @State).
	@State private var selectedTab: ConnectedAppsTab

	init(initialTab: ConnectedAppsTab = .detected) {
		selectedTab = initialTab
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Header()
			MetricsSummaryRow()

			Picker("Connected apps view", selection: $selectedTab) {
				ForEach(ConnectedAppsTab.allCases) { tab in
					Text(tab.title).tag(tab)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.padding(.vertical, 2)

			switch selectedTab {
			case .detected:
				DetectedAppsListSection(selectedTab: $selectedTab)
			case .quickConnect:
				QuickConnectGuideSection(
					host: SplashService.shared.preferredHostOrIP,
					port: SplashService.shared.activePort,
					activeModel: SplashService.shared.activeModel
				)
			}
		}
	}
}

enum ConnectedAppsTab: String, CaseIterable, Identifiable {
	case detected
	case quickConnect

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
		case .detected: return LocalizedStringResource("Detected Apps")
		case .quickConnect: return LocalizedStringResource("Integration Guide")
		}
	}
}

private struct Header: View {
	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 3) {
				HStack(spacing: 8) {
					Text("Connected Applications & Clients")
						.font(.system(size: 20, weight: .bold))

					if SplashService.shared.isRunning {
						HStack(spacing: 4) {
							Circle()
								.fill(Color.green)
								.frame(width: 7, height: 7)
							Text("Port \(SplashService.shared.activePort)")
								.font(.system(size: 11, weight: .semibold, design: .monospaced))
								.foregroundColor(.green)
						}
						.padding(.horizontal, 7)
						.padding(.vertical, 2)
						.background(Color.green.opacity(0.12))
						.cornerRadius(6)
					}
				}

				Text("Real-time monitoring of editors, autonomous agents, and processes consuming the Splash engine")
					.font(.system(size: 12))
					.foregroundColor(.secondary)
			}

			Spacer()

			Button {
				Task {
					await SplashService.shared.scanConnectedClients()
				}
			} label: {
				Label("Scan Now", systemImage: "arrow.clockwise")
					.font(.system(size: 11))
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
		}
	}
}

private struct MetricsSummaryRow: View {
	var body: some View {
		HStack(spacing: 12) {
			// §3.4: contadores calculados una vez por ciclo de sondeo en el servicio.
			let activeCount = SplashService.shared.activeClientCount
			let totalSockets = SplashService.shared.totalSockets

			StatBadgeCard(
				title: LocalizedStringResource("Connected Apps:"),
				value: LocalizedStringResource("\(activeCount)"),
				subtitle: LocalizedStringResource("\(SplashService.shared.connectedApps.count) this session"),
				icon: "app.connected.to.app.below.fill",
				color: activeCount > 0 ? .green : .secondary
			)

			let hostSubtitle: LocalizedStringResource = {
				if Preferences.listenOnAllInterfaces {
					if let ip = SplashService.shared.localNetworkIP {
						return LocalizedStringResource("LAN (\(ip))")
					} else {
						return LocalizedStringResource("LAN Connections (0.0.0.0)")
					}
				} else {
					return LocalizedStringResource("127.0.0.1 connections")
				}
			}()

			StatBadgeCard(
				title: LocalizedStringResource("Active TCP Sockets"),
				value: LocalizedStringResource("\(totalSockets)"),
				subtitle: hostSubtitle,
				icon: "network",
				color: totalSockets > 0 ? .blue : .secondary
			)

			StatBadgeCard(
				title: LocalizedStringResource("Running Engine"),
				value: SplashService.shared.isRunning ? "\(SplashService.shared.activeModel.components(separatedBy: "/").last ?? SplashService.shared.activeModel)" : LocalizedStringResource("Powered Off"),
				subtitle: SplashService.shared.isRunning ? LocalizedStringResource("Ready for inference") : LocalizedStringResource("Start the server"),
				icon: "cpu.fill",
				color: SplashService.shared.isRunning ? .purple : .red
			)
		}
	}
}

private struct DetectedAppsListSection: View {
	@Binding var selectedTab: ConnectedAppsTab

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			if !SplashService.shared.isRunning {
				ServerOfflinePlaceholder()
			} else if SplashService.shared.connectedApps.isEmpty {
				EmptyAppsPlaceholder(selectedTab: $selectedTab)
			} else {
				VStack(spacing: 10) {
					ForEach(SplashService.shared.connectedApps) { app in
						ConnectedAppCard(
							pid: app.pid,
							name: app.name,
							icon: app.icon,
							category: app.category,
							status: app.status,
							connectionCount: app.connectionCount,
							bundleId: app.bundleId,
							lastSeen: app.lastSeen
						)
					}
				}
			}
		}
	}
}

private struct ServerOfflinePlaceholder: View {
	var body: some View {
		VStack(spacing: 12) {
			Image(systemName: "server.rack")
				.font(.system(size: 36))
				.foregroundColor(.secondary.opacity(0.6))

			Text("Splash server is offline")
				.font(.system(size: 14, weight: .bold))

			Text("To see which applications and agents are consuming the engine, first start the server from the 'Server & Agents' tab.")
				.font(.system(size: 11))
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
				.frame(maxWidth: 420)

			Button {
				SplashService.shared.startServer(model: SplashService.shared.selectedModelForLaunch, port: SplashService.shared.activePort)
			} label: {
				Label("Start Server Now", systemImage: "play.fill")
					.font(.system(size: 11, weight: .semibold))
			}
			.buttonStyle(.borderedProminent)
			.tint(.green)
			.controlSize(.regular)
			.padding(.top, 4)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 36)
		.background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
		.cornerRadius(10)
	}
}

private struct EmptyAppsPlaceholder: View {
	@State private var copied: CopiedFlash?
	@Binding var selectedTab: ConnectedAppsTab

	var body: some View {
		VStack(spacing: 12) {
			Image(systemName: "antenna.radiowaves.left.and.right")
				.font(.system(size: 34))
				.foregroundColor(.accentColor.opacity(0.8))

			Text("Listening for incoming connections...")
				.font(.system(size: 14, weight: .semibold))

			Text("No clients connected to port \(SplashService.shared.activePort) yet.\nYou can connect Cursor, VS Code, Claude Code, Claude Cowork, DeepSeek Harness, OpenCode, Hermes, or any OpenAI API compatible app.")
				.font(.system(size: 11))
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
				.frame(maxWidth: 450)

			HStack(spacing: 10) {
				Button {
					let host = SplashService.shared.preferredHostOrIP
					copyToClipboard("http://\(host):\(SplashService.shared.activePort)/v1",
									flash: "URL Copied!",
									into: $copied)
				} label: {
					Label("Copy OpenAI Base URL", systemImage: "doc.on.doc")
						.font(.system(size: 11))
				}
				.buttonStyle(.bordered)
				.controlSize(.small)

				Button {
					selectedTab = .quickConnect
				} label: {
					Label("View Connection Guide", systemImage: "book.fill")
						.font(.system(size: 11))
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.small)
			}
			.padding(.top, 4)

			if let flash = copied {
				Text(flash.message)
					.font(.system(size: 10, weight: .semibold))
					.foregroundColor(.green)
					.transition(.opacity)
					.copiedFlashAutoClear($copied)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 36)
		.background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
		.cornerRadius(10)
	}
}

/// §3.2: sección independiente con entradas de valor (host/puerto/modelo) para que
/// el cuerpo de la vista no vuelva a correr en cada cambio del servicio.
private struct QuickConnectGuideSection: View {
	let host: String
	let port: Int
	let activeModel: String

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text("Connect Your Favorite Apps & IDEs")
				.font(.system(size: 14, weight: .bold))

			Text(Preferences.listenOnAllInterfaces
				 ? "Splash exposes a 100% OpenAI & Anthropic compatible API accessible on your LAN (\(host)):"
				 : "Splash exposes a 100% OpenAI & Anthropic compatible API on your local machine:")
			.font(.system(size: 11))
			.foregroundColor(.secondary)

			LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
				IntegrationGuideCard(
					title: LocalizedStringResource("Cursor IDE"),
					subtitle: LocalizedStringResource("Native AI Code Editor"),
					icon: "chevron.left.forwardslash.chevron.right",
					badge: LocalizedStringResource("OpenAI API"),
					color: .purple,
					steps: [
						LocalizedStringResource("1. Go to Settings → Models in Cursor"),
						LocalizedStringResource("2. Enable 'OpenAI API Key' (enter any text, e.g. 'splash')"),
						LocalizedStringResource("3. In 'Override OpenAI Base URL', enter:"),
						LocalizedStringResource("http://\(host):\(port)/v1")
					],
					copyText: "http://\(host):\(port)/v1"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("VS Code (Continue / Cline)"),
					subtitle: LocalizedStringResource("AI Coding Extensions"),
					icon: "sidebar.squares.trailing",
					badge: LocalizedStringResource("OpenAI Compatible"),
					color: .blue,
					steps: [
						LocalizedStringResource("1. In Continue/Cline extension, add a new model"),
						LocalizedStringResource("2. Select provider 'OpenAI' or 'Custom'"),
						LocalizedStringResource("3. Set apiBase in config.json:"),
						LocalizedStringResource("http://\(host):\(port)/v1")
					],
					copyText: "http://\(host):\(port)/v1"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("Claude Code CLI"),
					subtitle: LocalizedStringResource("Anthropic terminal agent"),
					icon: "brain.head.profile",
					badge: LocalizedStringResource("Anthropic API"),
					color: .orange,
					steps: [
						LocalizedStringResource("1. Export Splash environment variable:"),
						LocalizedStringResource("export ANTHROPIC_BASE_URL=\"http://\(host):\(port)\""),
						LocalizedStringResource("2. Launch Claude Code in your terminal:"),
						LocalizedStringResource("splash claude")
					],
					copyText: "export ANTHROPIC_BASE_URL=\"http://\(host):\(port)\"\nsplash claude"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("Claude Desktop / Cowork"),
					subtitle: LocalizedStringResource("macOS native App with Local Gateway"),
					icon: "person.2.badge.gearshape.fill",
					badge: LocalizedStringResource("Anthropic / Cowork"),
					color: .orange,
					steps: [
						LocalizedStringResource("1. In Claude for Mac, select your local Gateway"),
						LocalizedStringResource("2. Host / Endpoint URL:"),
						LocalizedStringResource("http://\(host):\(port)"),
						LocalizedStringResource("3. Splash responds to claude-haiku-4-5 & sonnet probes")
					],
					copyText: "http://\(host):\(port)"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("ChatGPT Desktop / Codex"),
					subtitle: LocalizedStringResource("OpenAI macOS native App"),
					icon: "sparkles",
					badge: LocalizedStringResource("OpenAI / Codex"),
					color: .teal,
					steps: [
						LocalizedStringResource("1. In ChatGPT for Mac or Codex scripts, point to your endpoint:"),
						LocalizedStringResource("http://\(host):\(port)/v1"),
						LocalizedStringResource("2. Active model in Splash:"),
						activeModel.isEmpty ? LocalizedStringResource("mlx-community/Qwen3.8-27B-4bit") : "\(activeModel)",
						LocalizedStringResource("3. API Key: 'splash' (bypass token)")
					],
					copyText: "http://\(host):\(port)/v1"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("Chatbox / NextChat / WebUI"),
					subtitle: LocalizedStringResource("macOS Chatbot Interfaces"),
					icon: "bubble.left.and.bubble.right.fill",
					badge: LocalizedStringResource("OpenAI Format"),
					color: .green,
					steps: [
						LocalizedStringResource("1. In Chatbot Settings, choose 'OpenAI API'"),
						LocalizedStringResource("2. Host / API Host:"),
						LocalizedStringResource("http://\(host):\(port)"),
						LocalizedStringResource("3. API Key: 'splash' (any string)")
					],
					copyText: "http://\(host):\(port)/v1"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("Python (OpenAI / LangChain)"),
					subtitle: LocalizedStringResource("Scripts and pipelines"),
					icon: "terminal.fill",
					badge: LocalizedStringResource("Python SDK"),
					color: .cyan,
					steps: [
						LocalizedStringResource("from openai import OpenAI"),
						LocalizedStringResource("client = OpenAI(base_url='http://\(host):\(port)/v1', api_key='splash')"),
						LocalizedStringResource("resp = client.chat.completions.create(model='\(activeModel)', messages=[...])")
					],
					copyText: "from openai import OpenAI\nclient = OpenAI(base_url='http://\(host):\(port)/v1', api_key='splash')"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("cURL / Terminal Directo"),
					subtitle: LocalizedStringResource("Direct HTTP requests"),
					icon: "network",
					badge: LocalizedStringResource("REST HTTP"),
					color: .indigo,
					steps: [
						LocalizedStringResource("curl http://\(host):\(port)/v1/chat/completions \\"),
						LocalizedStringResource("  -H 'Content-Type: application/json' \\"),
						LocalizedStringResource("  -d '{\"model\": \"\(activeModel)\", \"messages\": [{\"role\": \"user\", \"content\": \"Hola!\"}]}'")
					],
					copyText: "curl http://\(host):\(port)/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\": \"\(activeModel)\", \"messages\": [{\"role\": \"user\", \"content\": \"Hola\"}]}'"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("DeepSeek Harness (dsh)"),
					subtitle: LocalizedStringResource("DeepSeek autonomous coding agent"),
					icon: "cpu.fill",
					badge: LocalizedStringResource("OpenAI Protocol"),
					color: .blue,
					steps: [
						LocalizedStringResource("1. Launch DeepSeek Harness web runtime:"),
						LocalizedStringResource("npx @deepseek-ai/dsh web"),
						LocalizedStringResource("2. In Settings → Models → Custom model API:"),
						LocalizedStringResource("Base URL: http://\(host):\(port)/v1"),
						LocalizedStringResource("3. Protocol: openai-completions | API Key: splash")
					],
					copyText: "export OPENAI_BASE_URL=\"http://\(host):\(port)/v1\"\nexport OPENAI_API_KEY=\"splash\"\nnpx @deepseek-ai/dsh web"
				)

				IntegrationGuideCard(
					title: LocalizedStringResource("Hermes Agent"),
					subtitle: LocalizedStringResource("Nous Research coding agent"),
					icon: "bolt.horizontal.fill",
					badge: LocalizedStringResource("OpenAI Compatible"),
					color: .orange,
					steps: [
						LocalizedStringResource("1. In your Hermes .env or configuration:"),
						LocalizedStringResource("OPENAI_BASE_URL=\"http://\(host):\(port)/v1\""),
						LocalizedStringResource("OPENAI_API_KEY=\"splash\""),
						LocalizedStringResource("2. Active model in Splash:"),
						"\(activeModel.isEmpty ? "mlx-community/Qwen3.8-27B-4bit" : activeModel)"
					],
					copyText: "export OPENAI_BASE_URL=\"http://\(host):\(port)/v1\"\nexport OPENAI_API_KEY=\"splash\""
				)
			}
		}
	}
}

// MARK: - Subcomponents

struct ConnectedAppCard: View {
	// §3.7: entradas de valor individuales en vez del model entero — el model es
	// `Hashable` y cambia con cada sondeo, lo que re-identificaría la fila y
	// mataría el estado local (@State) de la tarjeta.
	let pid: Int32
	let name: String
	let icon: NSImage?
	let category: AppCategory
	let status: AppConnectionStatus
	let connectionCount: Int
	let bundleId: String?
	let lastSeen: Date
	// §3.7: la identidad es el PID estable.
	var id: Int32 { pid }
	@State private var isHovered: Bool = false
	/// P-04: la terminación de una app conectada exige confirmación explícita.
	@State private var confirmingTermination: Bool = false

	/// Busca la app viva en el servicio por PID antes de actuar sobre ella:
	/// el `ConnectedApp` que se muestra puede estar desactualizado.
	private var liveApp: ConnectedApp? {
		SplashService.shared.connectedApps.first(where: { $0.pid == pid })
	}

	var body: some View {
		HStack(spacing: 12) {
			// App Icon
			Group {
				if let icon = icon {
					Image(nsImage: icon)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 38, height: 38)
				} else {
					ZStack {
						RoundedRectangle(cornerRadius: 8)
							.fill(categoryColor(category).opacity(0.15))
							.frame(width: 38, height: 38)

						Image(systemName: category.iconName)
							.font(.system(size: 18))
							.foregroundColor(categoryColor(category))
					}
				}
			}

			// App Details
			VStack(alignment: .leading, spacing: 3) {
				HStack(spacing: 6) {
					Text(name)
						.font(.system(size: 13, weight: .bold))

					Text(category.localizedName)
						.font(.system(size: 9, weight: .medium))
						.foregroundColor(categoryColor(category))
						.padding(.horizontal, 5)
						.padding(.vertical, 1)
						.background(categoryColor(category).opacity(0.12))
						.cornerRadius(4)

					Spacer()

					// Status Badge
					HStack(spacing: 4) {
						Circle()
							.fill(statusColor(status))
							.frame(width: 6, height: 6)
						Text(status.localizedName)
							.font(.system(size: 10, weight: .semibold))
							.foregroundColor(statusColor(status))
					}
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(statusColor(status).opacity(0.12))
					.cornerRadius(5)
				}

				HStack(spacing: 12) {
					HStack(spacing: 3) {
						Text("PID:")
							.font(.system(size: 10))
							.foregroundColor(.secondary)
						Text(pid, format: .number.grouping(.never))
							.font(.system(size: 10, weight: .medium, design: .monospaced))
					}

					HStack(spacing: 3) {
						Image(systemName: "network")
							.font(.system(size: 9))
							.foregroundColor(.secondary)
						Text("\(connectionCount) sockets")
							.font(.system(size: 10))
							.foregroundColor(.secondary)
					}

					if let bundle = bundleId, !bundle.isEmpty {
						Text(bundle)
							.font(.system(size: 9, design: .monospaced))
							.foregroundColor(.secondary.opacity(0.8))
							.lineLimit(1)
					}

					Spacer()

					Text("Last seen: \(lastSeen, format: .dateTime.hour().minute().second())")
						.font(.system(size: 9))
						.foregroundColor(.secondary)
				}
			}

			// Actions
			if category != .lanClient {
				HStack(spacing: 6) {
					// §10: botones solo-icono con etiqueta de accesibilidad visible en VoiceOver.
					Button("Bring app to front", systemImage: "arrow.up.forward.app") {
						guard let live = liveApp else { return }
						SplashService.shared.activateApp(app: live)
					}
					.labelStyle(.iconOnly)
					.buttonStyle(.bordered)
					.controlSize(.small)
					.help("Bring app to front")

					Button("Reveal in Finder", systemImage: "folder") {
						guard let live = liveApp else { return }
						SplashService.shared.revealAppInFinder(app: live)
					}
					.labelStyle(.iconOnly)
					.buttonStyle(.bordered)
					.controlSize(.small)
					.help("Reveal in Finder")

					Button("Terminate client process", systemImage: "xmark.circle") {
						confirmingTermination = true
					}
					.labelStyle(.iconOnly)
					.buttonStyle(.bordered)
					.controlSize(.small)
					.help("Terminate client process")
				}
			} else {
				HStack(spacing: 4) {
					Image(systemName: "globe")
						.font(.system(size: 10))
						.foregroundColor(.indigo)
					Text("LAN Network")
						.font(.system(size: 10, weight: .medium))
						.foregroundColor(.secondary)
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 3)
				.background(Color.indigo.opacity(0.12))
				.cornerRadius(4)
			}
		}
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
		.overlay(
			RoundedRectangle(cornerRadius: 8)
				.stroke(status == .active ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
		)
		// P-04 / H-05: antes el botón «Terminar» enviaba SIGTERM al primer clic y sin
		// confirmación. Un clic accidental cerraba el cliente del usuario.
		.confirmationDialog(
			"Terminate \(name)?",
			isPresented: $confirmingTermination,
			titleVisibility: .visible
		) {
			Button("Terminate process (PID \(pid))",
				   role: .destructive) {
				guard let live = liveApp else { return }
				SplashService.shared.terminateApp(app: live)
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("A shutdown request will be sent to \(name) (PID \(pid)). Save its work before continuing. The application decides how to close.")
		}
	}

	private func categoryColor(_ cat: AppCategory) -> Color {
		switch cat {
		case .ide: return .purple
		case .codingAgent: return .orange
		case .chatbot: return .green
		case .terminal: return .blue
		case .customScript: return .cyan
		case .lanClient: return .indigo
		}
	}

	private func statusColor(_ st: AppConnectionStatus) -> Color {
		switch st {
		case .active: return .green
		case .idle: return .blue
		case .recent: return .secondary
		}
	}
}

struct StatBadgeCard: View {
	let title: LocalizedStringResource
	let value: LocalizedStringResource
	let subtitle: LocalizedStringResource
	let icon: String
	let color: Color

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: icon)
				.font(.system(size: 20))
				.foregroundColor(color)
				.frame(width: 32, height: 32)
				.background(color.opacity(0.12))
				.cornerRadius(8)

			VStack(alignment: .leading, spacing: 1) {
				Text(title)
					.font(.system(size: 10, weight: .semibold))
					.foregroundColor(.secondary)
				Text(value)
					.font(.system(size: 14, weight: .bold))
					.foregroundColor(.primary)
					.lineLimit(1)
				Text(subtitle)
					.font(.system(size: 9))
					.foregroundColor(.secondary)
					.lineLimit(1)
			}

			Spacer()
		}
		.padding(10)
		.frame(maxWidth: .infinity)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
	}
}

struct IntegrationGuideCard: View {
	let title: LocalizedStringResource
	let subtitle: LocalizedStringResource
	let icon: String
	let badge: LocalizedStringResource
	let color: Color
	let steps: [LocalizedStringResource]
	let copyText: String
	@State private var copied: CopiedFlash?

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 8) {
				Image(systemName: icon)
					.font(.system(size: 14, weight: .semibold))
					.foregroundColor(color)

				VStack(alignment: .leading, spacing: 1) {
					Text(title)
						.font(.system(size: 12, weight: .bold))
					Text(subtitle)
						.font(.system(size: 9))
						.foregroundColor(.secondary)
				}

				Spacer()

				Text(badge)
					.font(.system(size: 8, weight: .bold))
					.foregroundColor(color)
					.padding(.horizontal, 5)
					.padding(.vertical, 2)
					.background(color.opacity(0.12))
					.cornerRadius(4)
			}

			Divider()

			VStack(alignment: .leading, spacing: 3) {
				ForEach(steps, id: \.key) { step in
					if step.key.hasPrefix("http") || step.key.hasPrefix("export") || step.key.hasPrefix("curl") || step.key.hasPrefix("from") || step.key.hasPrefix("client") || step.key.hasPrefix("splash") {
						Text(step)
							.font(.system(size: 9, design: .monospaced))
							.foregroundColor(.accentColor)
							.padding(.vertical, 1)
					} else {
						Text(step)
							.font(.system(size: 10))
							.foregroundColor(.secondary)
					}
				}
			}

			Spacer(minLength: 4)

			Button {
				copyToClipboard(copyText, flash: "Copied!", into: $copied)
			} label: {
				HStack(spacing: 4) {
					Image(systemName: copied != nil ? "checkmark" : "doc.on.doc")
					Text(copied != nil ? "Copied!" : "Copiar Configuración")
				}
				.font(.system(size: 10, weight: .medium))
				.frame(maxWidth: .infinity)
			}
			.copiedFlashAutoClear($copied)
			.buttonStyle(.bordered)
			.controlSize(.small)
		}
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
	}
}
