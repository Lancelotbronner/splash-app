import SwiftUI

struct TokenMetricsView: View {

	var body: some View {
		VStack(spacing: 14) {
			// Active Request Lifecycle (Issue #6)
			activeRequestCard

			// Speed Hero Cards
			HStack(spacing: 12) {
				MetricCard(
					title: "DECODE (Output)",
					value: SplashService.shared.formattedDecodeSpeed,
					unit: "tok/s",
					subtitle: "\(SplashService.shared.formattedTokensDecode) tokens",
					icon: "bolt.fill",
					tint: .green
				)

				MetricCard(
					title: "PREFILL (Input)",
					value: SplashService.shared.formattedPrefillSpeed,
					unit: "tok/s",
					subtitle: "\(SplashService.shared.formattedTokensPrefill) tokens",
					icon: "arrow.down.forward.circle.fill",
					tint: .blue
				)
			}

			// Sparkline / Mini Speed History
			if !SplashService.shared.speedHistory.isEmpty {
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text("Decode Speed History")
							.font(.system(size: 11, weight: .medium))
							.foregroundColor(.secondary)
						Spacer()
						Text("\(SplashService.shared.formattedDecodeSpeed) tok/s current")
							.font(.system(size: 11, weight: .semibold, design: .monospaced))
							.foregroundColor(.green)
					}

					SpeedMiniChart(data: SplashService.shared.speedHistory)
						.frame(height: 38)
						.background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
						.cornerRadius(6)
				}
				.padding(8)
				.background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
				.cornerRadius(8)
			}

			// Efficiency Metrics (Prefix Cache & DFlash Speculative Decoding)
			VStack(spacing: 8) {
				HStack(spacing: 12) {
					MiniStatRow(
						title: "Reused KV Cache",
						value: SplashService.shared.formattedTokensReused,
						detail: "\(SplashService.shared.formattedCacheHitRate) hit rate",
						icon: "arrow.triangle.2.circlepath",
						tint: .cyan
					)

					MiniStatRow(
						title: "DFlash 2 Speculation",
						value: SplashService.shared.formattedDraftAcceptanceRate,
						detail: "Draft acceptance",
						icon: "sparkles",
						tint: .orange
					)
				}

				HStack(spacing: 12) {
					MiniStatRow(
						title: "Latency TTFT (p50)",
						value: String(format: "%.0f ms", SplashService.shared.status?.metrics?.ttftMs?.p50 ?? 0.0),
						detail: "Time to first token",
						icon: "timer",
						tint: .purple
					)

					MiniStatRow(
						title: "Latency ITL (p50)",
						value: String(format: "%.1f ms", SplashService.shared.status?.metrics?.itlMs?.p50 ?? 0.0),
						detail: "Inter-token latency",
						icon: "waveform.path.ecg",
						tint: .indigo
					)
				}
			}

			// Hardware & Metal Memory Section
			VStack(alignment: .leading, spacing: 6) {
				HStack {
					Label {
						Text("Unified Metal Memory")
							.font(.system(size: 11, weight: .medium))
					} icon: {
						Image(systemName: "memorychip")
							.foregroundColor(.pink)
					}

					Spacer()

					Text("\(SplashService.shared.formattedMemoryUsed) / \(SplashService.shared.formattedMemoryLimit)")
						.font(.system(size: 11, weight: .semibold, design: .monospaced))
						.foregroundColor(.primary)
				}

				GeometryReader { geo in
					ZStack(alignment: .leading) {
						RoundedRectangle(cornerRadius: 4)
							.fill(Color(nsColor: .separatorColor))
							.frame(height: 7)

						RoundedRectangle(cornerRadius: 4)
							.fill(
								LinearGradient(
									colors: SplashService.shared.memoryUsageRatio > 0.85 ? [.orange, .red] : [.blue, .purple],
									startPoint: .leading,
									endPoint: .trailing
								)
							)
							.frame(width: max(4, geo.size.width * CGFloat(SplashService.shared.memoryUsageRatio)), height: 7)
					}
				}
				.frame(height: 7)

				if let dev = SplashService.shared.status?.memoryPlan?.device {
					HStack {
						Text("\(dev.deviceName ?? "Apple Silicon") · \(dev.gpuCoreCount ?? 0) Cores GPU")
							.font(.system(size: 10))
							.foregroundColor(.secondary)
						Spacer()
						if let thermal = SplashService.shared.status?.thermalState {
							Text("Thermal: \(thermal.capitalized)")
								.font(.system(size: 10, weight: .medium))
								.foregroundColor(thermal == "nominal" ? .green : (thermal == "fair" ? .yellow : .orange))
							Text(verbatim: "·")
								.foregroundColor(.secondary)
						}
						Text("Pressure: \(SplashService.shared.status?.memoryPressure?.capitalized ?? "Normal")")
							.font(.system(size: 10, weight: .medium))
							.foregroundColor(SplashService.shared.status?.memoryPressure == "normal" ? .green : .orange)
					}
				}

				// Estado de Pesos Metal y Presión del Sistema macOS
				HStack(spacing: 8) {
					if let weights = SplashService.shared.status?.weights {
						HStack(spacing: 4) {
							Circle()
								.fill(weights.released == true ? Color.orange : Color.green)
								.frame(width: 6, height: 6)
							if weights.released == true {
								Text("Weights Released (Metal Unwired)")
									.font(.system(size: 10, weight: .semibold))
									.foregroundColor(.orange)
							} else {
								Text("Weights Active in VRAM")
									.font(.system(size: 10, weight: .medium))
									.foregroundColor(.secondary)
							}
							if let restores = weights.restores, restores > 0 {
								Text("· \(restores) restores")
									.font(.system(size: 9))
									.foregroundColor(.secondary)
							}
						}
					}

					Spacer()

					// Aviso o Botón de Liberación Manual
					if SplashService.shared.isRunning {
						Button {
							SplashService.shared.releaseMemoryNow()
						} label: {
							HStack(spacing: 3) {
								Image(systemName: "arrow.down.right.and.arrow.up.left")
									.font(.system(size: 9))
								Text("Free Memory")
									.font(.system(size: 10, weight: .medium))
							}
							.padding(.horizontal, 6)
							.padding(.vertical, 2)
							.background(Color.secondary.opacity(0.1))
							.cornerRadius(4)
						}
						.buttonStyle(.plain)
						.help("Stops the server and immediately unloads all Metal unified memory used by the model.")
					}
				}

				if let notice = SplashService.shared.memoryReliefNotice {
					HStack(spacing: 4) {
						Image(systemName: "info.circle.fill")
							.font(.system(size: 9))
							.foregroundColor(.blue)
						Text(notice)
							.font(.system(size: 10))
							.foregroundColor(.secondary)
						Spacer()
						Button {
							SplashService.shared.memoryReliefNotice = nil
						} label: {
							Image(systemName: "xmark")
								.font(.system(size: 8))
								.foregroundColor(.secondary)
						}
						.buttonStyle(.plain)
					}
					.padding(4)
					.background(Color.blue.opacity(0.08))
					.cornerRadius(4)
				}

				if let ane = SplashService.shared.status?.aneFfn, let state = ane.state {
					HStack {
						Label {
							Text("Apple Neural Engine (ANE)")
								.font(.system(size: 10, weight: .medium))
						} icon: {
							Image(systemName: "cpu")
								.font(.system(size: 10))
								.foregroundColor(.indigo)
						}
						Spacer()
						if let share = ane.share {
							Text("\(state.capitalized) · \(Int(share * 100))%% share")
								.font(.system(size: 10, weight: .medium, design: .monospaced))
								.foregroundColor(.secondary)
						} else {
							Text(state.capitalized)
								.font(.system(size: 10, weight: .medium, design: .monospaced))
								.foregroundColor(.secondary)
						}
					}
					.padding(.top, 2)
				}
			}
			.padding(10)
			.background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
			.cornerRadius(8)

			// Connected Applications Quick Bar
			if SplashService.shared.isRunning {
				HStack(spacing: 8) {
					Image(systemName: "app.connected.to.app.below.fill")
						.font(.system(size: 11))
						.foregroundColor(.purple)

					let activeApps = SplashService.shared.connectedApps.filter { $0.status == .active || $0.status == .idle }
					if activeApps.isEmpty {
						Text("Connected apps:")
							.font(.system(size: 10, weight: .semibold))
							.foregroundColor(.secondary)
						Text("None active (listening :\(SplashService.shared.activePort))")
							.font(.system(size: 10))
							.foregroundColor(.secondary)
					} else {
						Text("Connected apps (\(activeApps.count)):")
							.font(.system(size: 10, weight: .semibold))
							.foregroundColor(.secondary)

						ScrollView(.horizontal, showsIndicators: false) {
							HStack(spacing: 6) {
								ForEach(activeApps) { app in
									HStack(spacing: 4) {
										if let icon = app.icon {
											Image(nsImage: icon)
												.resizable()
												.frame(width: 14, height: 14)
										} else {
											Image(systemName: app.category.iconName)
												.font(.system(size: 9))
												.foregroundColor(.purple)
										}
										Text(app.name)
											.font(.system(size: 10, weight: .medium))
									}
									.padding(.horizontal, 6)
									.padding(.vertical, 2)
									.background(Color(nsColor: .controlBackgroundColor))
									.cornerRadius(5)
								}
							}
						}
					}

					Spacer()
				}
				.padding(8)
				.background(Color.purple.opacity(0.08))
				.cornerRadius(6)
			}

			// Requests Overview
			let reqs = SplashService.shared.status?.requests
			HStack(spacing: 14) {
				RequestPill(title: "Completed", count: reqs?.completed ?? 0, color: .green)
				RequestPill(title: "Queued", count: SplashService.shared.status?.scheduler?.queued ?? 0, color: .blue)
				RequestPill(title: "Cancelled", count: reqs?.cancelled ?? 0, color: .gray)
				RequestPill(title: "Failed", count: reqs?.failed ?? 0, color: .red)
			}
			.font(.system(size: 10))

			// JMGREP Developers signature
			HStack(spacing: 5) {
				Image(systemName: "hammer.fill")
					.font(.system(size: 9))
					.foregroundColor(.accentColor)
				Text("JMGREP Developers")
					.font(.system(size: 10, weight: .bold))
				Text("By Joan Gregorio Pérez - Ingeniero en software")
					.font(.system(size: 10, weight: .medium))
					.foregroundColor(.secondary)
			}
			.padding(.top, 4)
		}
	}

	// MARK: - Active Request Progress Card (Issue #6)
	@ViewBuilder
	private var activeRequestCard: some View {
		let stage = SplashService.shared.activeRequestStage
		let stageColor: Color = {
			switch stage {
			case .prefilling: return .blue
			case .decoding: return .green
			case .queued: return .orange
			case .idle: return .secondary
			case .offline: return .gray
			}
		}()

		VStack(alignment: .leading, spacing: 8) {
			// Header: Stage Title & Live badge
			HStack(spacing: 8) {
				HStack(spacing: 6) {
					Circle()
						.fill(stageColor)
						.frame(width: 8, height: 8)
						.shadow(color: stage == .prefilling || stage == .decoding ? stageColor.opacity(0.8) : .clear, radius: 4)

					Text("REQUEST LIFECYCLE")
						.font(.system(size: 10, weight: .bold, design: .rounded))
						.foregroundColor(.secondary)
				}

				Spacer()

				// Stage Badge
				HStack(spacing: 5) {
					Image(systemName: stage.icon)
						.font(.system(size: 10, weight: .bold))
					Text(stage.title)
						.font(.system(size: 10, weight: .bold))
				}
				.foregroundColor(stageColor)
				.padding(.horizontal, 7)
				.padding(.vertical, 3)
				.background(stageColor.opacity(0.12))
				.cornerRadius(5)
			}

			// Progress Bar / Live Status
			if stage == .prefilling {
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text("Stage 1/2: Ingesting prompt & evaluating KV Cache...")
							.font(.system(size: 11, weight: .medium))
							.foregroundColor(.blue)
						Spacer()
						Text("\(SplashService.shared.formattedPrefillSpeed) tok/s")
							.font(.system(size: 11, weight: .bold, design: .monospaced))
							.foregroundColor(.blue)
					}
					ProgressView()
						.progressViewStyle(.linear)
						.tint(.blue)
				}
			} else if stage == .decoding {
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text("Stage 2/2: Generating output response tokens...")
							.font(.system(size: 11, weight: .medium))
							.foregroundColor(.green)
						Spacer()
						Text("\(SplashService.shared.formattedDecodeSpeed) tok/s")
							.font(.system(size: 11, weight: .bold, design: .monospaced))
							.foregroundColor(.green)
					}
					ProgressView()
						.progressViewStyle(.linear)
						.tint(.green)
				}
			} else if stage == .queued {
				HStack {
					Text("Request queued waiting for inference slot...")
						.font(.system(size: 11))
						.foregroundColor(.orange)
					Spacer()
					Text("Queued: \(SplashService.shared.status?.scheduler?.queued ?? 1)")
						.font(.system(size: 11, weight: .medium))
						.foregroundColor(.orange)
				}
			} else {
				HStack {
					Text("Server stopped · Start Splash to accept requests")
						.font(.system(size: 11))
						.foregroundColor(.secondary)
					Spacer()
					if let completed = SplashService.shared.status?.requests?.completed, completed > 0 {
						Text("\(completed) completed")
							.font(.system(size: 10, weight: .medium))
							.foregroundColor(.secondary)
					}
				}
			}
		}
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
		.overlay(
			RoundedRectangle(cornerRadius: 8)
				.stroke(stage == .prefilling || stage == .decoding ? stageColor.opacity(0.4) : Color.secondary.opacity(0.12), lineWidth: 1)
		)
	}
}

// MARK: - Subcomponents

struct MetricCard: View {
	let title: LocalizedStringResource
	let value: String
	let unit: LocalizedStringResource
	let subtitle: LocalizedStringResource
	let icon: String
	let tint: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 5) {
				Image(systemName: icon)
					.font(.system(size: 11, weight: .bold))
					.foregroundColor(tint)
				Text(title)
					.font(.system(size: 10, weight: .semibold))
					.foregroundColor(.secondary)
			}

			HStack(alignment: .firstTextBaseline, spacing: 3) {
				Text(value)
					.font(.system(size: 22, weight: .bold, design: .rounded))
					.foregroundColor(.primary)
				Text(unit)
					.font(.system(size: 11, weight: .medium))
					.foregroundColor(.secondary)
			}

			Text(subtitle)
				.font(.system(size: 10))
				.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(10)
		.overlay(
			RoundedRectangle(cornerRadius: 10)
				.stroke(tint.opacity(0.25), lineWidth: 1)
		)
	}
}

struct MiniStatRow: View {
	let title: LocalizedStringResource
	let value: String
	let detail: LocalizedStringResource
	let icon: String
	let tint: Color

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: icon)
				.font(.system(size: 12))
				.foregroundColor(tint)
				.frame(width: 20)

			VStack(alignment: .leading, spacing: 1) {
				Text(title)
					.font(.system(size: 10))
					.foregroundColor(.secondary)
				Text(value)
					.font(.system(size: 12, weight: .semibold, design: .monospaced))
					.foregroundColor(.primary)
			}

			Spacer()

			Text(detail)
				.font(.system(size: 10))
				.foregroundColor(.secondary)
		}
		.padding(8)
		.frame(maxWidth: .infinity)
		.background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
		.cornerRadius(8)
	}
}

struct RequestPill: View {
	let title: LocalizedStringResource
	let count: Int
	let color: Color

	var body: some View {
		HStack(spacing: 4) {
			Circle()
				.fill(color)
				.frame(width: 6, height: 6)
			Text(title)
				.foregroundColor(.secondary)
			Text("\(count)")
				.fontWeight(.semibold)
				.foregroundColor(.primary)
		}
	}
}

struct SpeedMiniChart: View {
	let data: [Double]

	var body: some View {
		GeometryReader { geo in
			let maxVal = max(data.max() ?? 10.0, 10.0)
			Path { path in
				guard data.count > 1 else { return }
				let stepX = geo.size.width / CGFloat(data.count - 1)
				for (index, val) in data.enumerated() {
					let normY = 1.0 - CGFloat(val / maxVal)
					let pt = CGPoint(x: CGFloat(index) * stepX, y: max(2, min(geo.size.height - 2, normY * geo.size.height)))
					if index == 0 {
						path.move(to: pt)
					} else {
						path.addLine(to: pt)
					}
				}
			}
			.stroke(
				LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing),
				style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
			)
		}
	}
}
