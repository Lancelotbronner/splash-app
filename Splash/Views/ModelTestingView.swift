import SwiftUI
import AppKit

struct ModelTestingView: View {
	enum ModelTestingTab: Int, Hashable, CaseIterable {
		case smokeTest
		case benchmark
		case playground
	}

	@Environment(ModelDiagnosticService.self) private var diagnosticService
	// §6.2: selector tipado en vez de `Int` mágico.
	@State private var selectedTab: ModelTestingTab = .smokeTest

	// Playground inputs (viven aquí para sobrevivir al cambio de pestaña)
	@State private var playgroundProtocol: String = "openai" // "openai" | "anthropic"
	@State private var playgroundSystemPrompt: String = ""
	@State private var playgroundUserPrompt: String = "Escribe una función en Python para verificar si un número es primo y explica brevemente su complejidad."
	@State private var playgroundMaxTokens: Double = 256
	@State private var playgroundTemperature: Double = 0.2
	@State private var showingRawJSON: Bool = false

	// Benchmark options
	@State private var benchmarkTokens: Int = 128

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			// Header & Active Server Status Banner
			TestingHeaderView(
				isRunning: SplashService.shared.isRunning,
				activeModel: SplashService.shared.activeModel,
				activePort: SplashService.shared.activePort
			)

			// Segmented Selector
			Picker("Model testing section", selection: $selectedTab) {
				Label("Smoke Test", systemImage: "stethoscope").tag(ModelTestingTab.smokeTest)
				Label("Benchmark & Cache", systemImage: "bolt.fill").tag(ModelTestingTab.benchmark)
				Label("Playground", systemImage: "terminal.fill").tag(ModelTestingTab.playground)
			}
			.pickerStyle(.segmented)
			.labelsHidden()

			// Active Server Warning if offline
			if !SplashService.shared.isRunning {
				HStack(spacing: 8) {
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundColor(.orange)
					Text("Splash server is offline. Start the server from 'Server & Agents' tab to run diagnostics.")
						.font(.system(size: 11))
						.foregroundColor(.secondary)
				}
				.padding(10)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color.orange.opacity(0.1))
				.cornerRadius(8)
			}

			// Tab Content
			switch selectedTab {
			case .smokeTest:
				SmokeTestSection(
					results: diagnosticService.smokeTestResults,
					isRunning: diagnosticService.isRunningSmokeTest,
					isServerRunning: SplashService.shared.isRunning,
					activeModel: SplashService.shared.activeModel,
					activePort: SplashService.shared.activePort,
					onRun: {
						Task {
							await diagnosticService.runFullSmokeTest(
								port: SplashService.shared.activePort,
								targetModel: SplashService.shared.activeModel.isEmpty ? SplashService.shared.selectedModelForLaunch : SplashService.shared.activeModel
							)
						}
					}
				)
			case .benchmark:
				BenchmarkSection(
					tokens: $benchmarkTokens,
					isRunning: diagnosticService.isRunningBenchmark,
					progress: diagnosticService.benchmarkProgress,
					phase: diagnosticService.currentBenchmarkPhase,
					latest: diagnosticService.latestBenchmark,
					isServerRunning: SplashService.shared.isRunning,
					onStart: {
						Task {
							await diagnosticService.runBenchmark(
								port: SplashService.shared.activePort,
								targetModel: SplashService.shared.activeModel.isEmpty ? SplashService.shared.selectedModelForLaunch : SplashService.shared.activeModel,
								tokenLimit: benchmarkTokens
							)
						}
					}
				)
			case .playground:
				PlaygroundSection(
					protocol: $playgroundProtocol,
					systemPrompt: $playgroundSystemPrompt,
					userPrompt: $playgroundUserPrompt,
					maxTokens: $playgroundMaxTokens,
					temperature: $playgroundTemperature,
					isGenerating: diagnosticService.isGeneratingPlayground,
					output: diagnosticService.playgroundOutput,
					rawResponse: diagnosticService.playgroundRawResponse,
					tokensGenerated: diagnosticService.playgroundTokensGenerated,
					tokPerSec: diagnosticService.playgroundTokPerSec,
					ttftMs: diagnosticService.playgroundTTFTMs,
					error: diagnosticService.playgroundLastError,
					isServerRunning: SplashService.shared.isRunning,
					onSend: {
						Task {
							await diagnosticService.sendInteractivePrompt(
								port: SplashService.shared.activePort,
								model: SplashService.shared.activeModel.isEmpty ? SplashService.shared.selectedModelForLaunch : SplashService.shared.activeModel,
								apiProtocol: playgroundProtocol,
								systemPrompt: playgroundSystemPrompt,
								userPrompt: playgroundUserPrompt,
								maxTokens: Int(playgroundMaxTokens),
								temperature: playgroundTemperature
							)
						}
					}
				)
			}
		}
	}
}

// MARK: - Header (§3.3)

/// Cabecera de la pestaña con el badge del servidor activo.
private struct TestingHeaderView: View {
	let isRunning: Bool
	let activeModel: String
	let activePort: Int

	var body: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 2) {
				HStack(spacing: 6) {
					Image(systemName: "testtube.2")
						.font(.system(size: 16, weight: .bold))
						.foregroundColor(.purple)
					Text("Model Lab & Diagnostics")
						.font(.system(size: 16, weight: .bold))
				}
				Text("Integrity tests, API compatibility suites (OpenAI/Anthropic), and real-time Metal performance benchmarking.")
					.font(.system(size: 11))
					.foregroundColor(.secondary)
			}

			Spacer()

			// Server Badge
			HStack(spacing: 6) {
				Circle()
					.fill(isRunning ? Color.green : Color.red)
					.frame(width: 8, height: 8)
				Text("\(activeModel) (:\(activePort))")
					.font(.system(size: 11, design: .monospaced))
					.lineLimit(1)
					.truncationMode(.middle)
					.frame(maxWidth: 220)
			}
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(Color.secondary.opacity(0.08))
			.cornerRadius(6)
		}
	}
}

// MARK: - 1. Smoke Test (§3.3)

private struct SmokeTestSection: View {
	let results: [ModelDiagnosticService.SmokeTestResult]
	let isRunning: Bool
	let isServerRunning: Bool
	let activeModel: String
	let activePort: Int
	let onRun: () -> Void

	@State private var copied: CopiedFlash?

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Button(action: onRun) {
					HStack(spacing: 6) {
						if isRunning {
							ProgressView()
								.controlSize(.small)
							Text("Running diagnostics...")
						} else {
							Image(systemName: "play.circle.fill")
							Text("Run Full Smoke Test")
						}
					}
					.font(.system(size: 11, weight: .semibold))
				}
				.buttonStyle(.borderedProminent)
				.tint(.purple)
				.disabled(isRunning || !isServerRunning)

				Spacer()

				// §3.8: patrón de copia compartido con destello de confirmación.
				Button {
					copyToClipboard(smokeReport, flash: "Report copied!", into: $copied)
				} label: {
					Label("Copy Report", systemImage: copied != nil ? "checkmark" : "doc.on.doc")
						.font(.system(size: 10))
						.foregroundColor(copied != nil ? .green : .primary)
				}
				.copiedFlashAutoClear($copied)
				.buttonStyle(.borderless)
				.disabled(results.allSatisfy { $0.status == .idle })
			}

			// Test items list
			VStack(spacing: 8) {
				ForEach(results) { test in
					SmokeTestRow(test: test)
				}
			}
		}
	}

	private var smokeReport: String {
		var report = "### Splash Monitor — Model Smoke Diagnostics Report\n"
		report += "Model: \(activeModel) | Port: \(activePort)\n"
		report += "Date: \(Date().formatted())\n\n"
		for item in results {
			let statusText: String = {
				switch item.status {
				case .passed(let d, let ms): return "PASSED (\(d), \(String(format: "%.0f", ms))ms)"
				case .warning(let d, let ms): return "WARNING (\(d), \(String(format: "%.0f", ms))ms)"
				case .failed(let e): return "FAILED (\(e))"
				default: return "NOT RUN"
				}
			}()
			report += "- [\(String(localized: item.name))]: \(statusText)\n"
		}
		return report
	}
}

/// Fila de una comprobación del smoke test con entrada de valor.
private struct SmokeTestRow: View {
	let test: ModelDiagnosticService.SmokeTestResult

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: test.icon)
				.font(.system(size: 14))
				.foregroundColor(.blue)
				.frame(width: 20)

			VStack(alignment: .leading, spacing: 2) {
				Text(test.name)
					.font(.system(size: 12, weight: .medium))

				switch test.status {
				case .idle:
					Text("Pending")
						.font(.system(size: 10))
						.foregroundColor(.secondary)
				case .running:
					Text("Probing endpoint...")
						.font(.system(size: 10))
						.foregroundColor(.orange)
				case .passed(let details, _):
					Text(details)
						.font(.system(size: 10, design: .monospaced))
						.foregroundColor(.green)
				case .warning(let details, _):
					Text(details)
						.font(.system(size: 10, design: .monospaced))
						.foregroundColor(.orange)
				case .failed(let err):
					Text(err)
						.font(.system(size: 10, design: .monospaced))
						.foregroundColor(.red)
				}
			}

			Spacer()

			// Status badge
			switch test.status {
			case .idle:
				Image(systemName: "circle")
					.foregroundColor(.secondary.opacity(0.5))
			case .running:
				ProgressView()
					.controlSize(.small)
			case .passed(_, let latency):
				HStack(spacing: 4) {
					Text("\(String(format: "%.0f", latency)) ms")
						.font(.system(size: 9, design: .monospaced))
						.foregroundColor(.secondary)
					Image(systemName: "checkmark.circle.fill")
						.foregroundColor(.green)
				}
			case .warning(_, let latency):
				HStack(spacing: 4) {
					Text("\(String(format: "%.0f", latency)) ms")
						.font(.system(size: 9, design: .monospaced))
						.foregroundColor(.secondary)
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundColor(.orange)
				}
			case .failed:
				Image(systemName: "xmark.circle.fill")
					.foregroundColor(.red)
			}
		}
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
	}
}

// MARK: - 2. Benchmark (§3.3)

private struct BenchmarkSection: View {
	@Binding var tokens: Int
	let isRunning: Bool
	let progress: Double
	let phase: String
	let latest: ModelDiagnosticService.BenchmarkResult?
	let isServerRunning: Bool
	let onStart: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			// Options Row
			HStack(spacing: 12) {
				Picker("Output tokens:", selection: $tokens) {
					Text("64 tokens").tag(64)
					Text("128 tokens").tag(128)
					Text("256 tokens").tag(256)
					Text("512 tokens").tag(512)
				}
				.frame(width: 220)

				Button(action: onStart) {
					HStack(spacing: 4) {
						if isRunning {
							ProgressView()
								.controlSize(.small)
							Text("Benchmarking...")
						} else {
							Image(systemName: "speedometer")
							Text("Start Benchmark")
						}
					}
				}
				.buttonStyle(.borderedProminent)
				.tint(.blue)
				.disabled(isRunning || !isServerRunning)

				Spacer()
			}

			// Progress Bar
			if isRunning {
				VStack(alignment: .leading, spacing: 4) {
					ProgressView(value: progress, total: 1.0)
					Text(phase)
						.font(.system(size: 10))
						.foregroundColor(.secondary)
				}
				.padding(10)
				.background(Color(nsColor: .controlBackgroundColor))
				.cornerRadius(8)
			}

			// Results Gauges / Cards
			if let bench = latest {
				VStack(alignment: .leading, spacing: 10) {
					Text("Metal Performance Results")
						.font(.system(size: 13, weight: .semibold))

					LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
						// Card 1: Cold Decode Speed
						BenchmarkMetricCard(
							title: LocalizedStringResource("Cold Decode Speed"),
							value: LocalizedStringResource("\(String(format: "%.1f", bench.coldDecodeTokPerSec)) tok/s"),
							icon: "snowflake",
							color: .cyan,
							subtitle: LocalizedStringResource("First pass without prior cache")
						)

						// Card 2: Warm Cached Speed
						BenchmarkMetricCard(
							title: LocalizedStringResource("Warm Decode Speed"),
							value: LocalizedStringResource("\(String(format: "%.1f", bench.warmDecodeTokPerSec)) tok/s"),
							icon: "flame.fill",
							color: .orange,
							subtitle: LocalizedStringResource("Replay with indexed prefix")
						)

						// Card 3: Cold TTFT (§4: el motor no reporta TTFT; es una
						// estimación a partir del tiempo total, así se etiqueta).
						BenchmarkMetricCard(
							title: LocalizedStringResource("Estimated Cold TTFT"),
							value: LocalizedStringResource("\(String(format: "%.0f", bench.coldTTFTMs)) ms"),
							icon: "timer",
							color: .purple,
							subtitle: LocalizedStringResource("Estimated from total response time")
						)

						// Card 4: Cache Speedup Multiplier
						BenchmarkMetricCard(
							title: LocalizedStringResource("KV Cache Speedup"),
							value: "\(String(format: "%.1fx", bench.cacheSpeedupMultiplier))",
							icon: "arrow.up.right.circle.fill",
							color: .green,
							subtitle: LocalizedStringResource("Splash prefix efficiency factor")
						)
					}

					Text("Based on Splash's SPEED-Bench methodology: DFlash 2 speculative decoding and optimized Metal kernels.")
						.font(.system(size: 9))
						.foregroundColor(.secondary)
				}
				.padding(12)
				.background(Color(nsColor: .controlBackgroundColor))
				.cornerRadius(10)
			}
		}
	}
}

/// Tarjeta de métrica del benchmark (antes `metricCard(...)` inline).
private struct BenchmarkMetricCard: View {
	let title: LocalizedStringResource
	let value: LocalizedStringResource
	let icon: String
	let color: Color
	let subtitle: LocalizedStringResource

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Image(systemName: icon)
					.foregroundColor(color)
					.font(.system(size: 13))
				Text(title)
					.font(.system(size: 11, weight: .medium))
					.foregroundColor(.secondary)
			}
			Text(value)
				.font(.system(size: 18, weight: .bold, design: .rounded))
				.foregroundColor(.primary)
			Text(subtitle)
				.font(.system(size: 9))
				.foregroundColor(.secondary)
		}
		.padding(10)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(color.opacity(0.08))
		.cornerRadius(8)
	}
}

// MARK: - 3. Playground (§3.3)

private struct PlaygroundSection: View {
	@Binding var `protocol`: String
	@Binding var systemPrompt: String
	@Binding var userPrompt: String
	@Binding var maxTokens: Double
	@Binding var temperature: Double
	let isGenerating: Bool
	let output: String
	let rawResponse: String
	let tokensGenerated: Int
	let tokPerSec: Double
	let ttftMs: Double
	let error: String?
	let isServerRunning: Bool
	let onSend: () -> Void

	@State private var showingRawJSON: Bool = false

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Protocol Selector & Sliders
			HStack(spacing: 12) {
				Picker("API protocol", selection: $protocol) {
					Text("OpenAI Chat Completions").tag("openai")
					Text("Anthropic Messages").tag("anthropic")
				}
				.labelsHidden()
				.frame(width: 250)

				Text("Tokens: \(Int(maxTokens))")
					.font(.system(size: 11))
				Slider(value: $maxTokens, in: 32...1024, step: 32)
					.frame(width: 120)

				Text("Temp: \(String(format: "%.1f", temperature))")
					.font(.system(size: 11))
				Slider(value: $temperature, in: 0.0...1.0, step: 0.1)
					.frame(width: 100)
			}

			// System Prompt (Optional)
			VStack(alignment: .leading, spacing: 3) {
				Text("System Prompt (Optional):")
					.font(.system(size: 10, weight: .medium))
					.foregroundColor(.secondary)
				TextField("E.g. You are an expert software engineering assistant.", text: $systemPrompt)
					.textFieldStyle(.roundedBorder)
					.font(.system(size: 11))
			}

			// User Prompt
			VStack(alignment: .leading, spacing: 3) {
				Text("Input Prompt (User):")
					.font(.system(size: 10, weight: .medium))
					.foregroundColor(.secondary)
				TextEditor(text: $userPrompt)
					.font(.system(size: 11, design: .monospaced))
					.frame(height: 60)
					.padding(4)
					.background(Color(nsColor: .controlBackgroundColor))
					.cornerRadius(6)
			}

			// Action Button
			HStack {
				Button(action: onSend) {
					HStack(spacing: 6) {
						if isGenerating {
							ProgressView()
								.controlSize(.small)
							Text("Generating...")
						} else {
							Image(systemName: "paperplane.fill")
							Text("Send Prompt")
						}
					}
				}
				.buttonStyle(.borderedProminent)
				.tint(.purple)
				.disabled(isGenerating || !isServerRunning || userPrompt.isEmpty)

				Spacer()

				if !rawResponse.isEmpty {
					Toggle(isOn: $showingRawJSON) {
						Text("Raw JSON")
							.font(.system(size: 10))
					}
					.toggleStyle(.checkbox)
				}
			}

			// Output Display
			if error != nil {
				HStack(spacing: 6) {
					Image(systemName: "exclamationmark.octagon.fill")
						.foregroundColor(.red)
					Text(error ?? "")
						.font(.system(size: 11))
						.foregroundColor(.red)
				}
				.padding(8)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color.red.opacity(0.1))
				.cornerRadius(6)
			} else if !output.isEmpty || !rawResponse.isEmpty {
				VStack(alignment: .leading, spacing: 6) {
					HStack {
						Text("Model Response:")
							.font(.system(size: 11, weight: .semibold))

						Spacer()

						if tokensGenerated > 0 {
							HStack(spacing: 8) {
								Text("\(tokensGenerated) tokens")
								Text(verbatim: "•")
								Text("\(String(format: "%.1f", tokPerSec)) tok/s")
								Text(verbatim: "•")
								// §4: TTFT estimado, no medido por el motor.
								Text("Est. TTFT: \(String(format: "%.0f", ttftMs)) ms")
							}
							.font(.system(size: 10, weight: .medium, design: .monospaced))
							.foregroundColor(.secondary)
						}
					}

					ScrollView {
						Text(showingRawJSON ? rawResponse : output)
							.font(.system(size: 11, design: .monospaced))
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.padding(8)
					}
					.frame(height: 160)
					.background(Color.black.opacity(0.85))
					.foregroundColor(.white)
					.cornerRadius(6)
				}
			}
		}
	}
}
