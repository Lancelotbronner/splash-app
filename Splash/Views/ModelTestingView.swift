import SwiftUI
import AppKit

struct ModelTestingView: View {
	@Environment(ModelDiagnosticService.self) private var diagnosticService
	@State private var selectedSubTab: Int = 0 // 0: Smoke Test, 1: Benchmark, 2: Playground

	// Playground inputs
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
			headerView

			// Segmented Selector
			Picker("Tab", selection: $selectedSubTab) {
				Label("Smoke Test", systemImage: "stethoscope").tag(0)
				Label("Benchmark & Cache", systemImage: "bolt.fill").tag(1)
				Label("Playground", systemImage: "terminal.fill").tag(2)
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
			switch selectedSubTab {
			case 0:
				smokeTestView
			case 1:
				benchmarkView
			case 2:
				playgroundView
			default:
				EmptyView()
			}
		}
	}

	// MARK: - Header

	private var headerView: some View {
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
					.fill(SplashService.shared.isRunning ? Color.green : Color.red)
					.frame(width: 8, height: 8)
				Text("\(SplashService.shared.activeModel) (:\(SplashService.shared.activePort))")
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

	// MARK: - 1. Smoke Test View

	private var smokeTestView: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Button {
					Task {
						await diagnosticService.runFullSmokeTest(
							port: SplashService.shared.activePort,
							targetModel: SplashService.shared.activeModel.isEmpty ? SplashService.shared.selectedModelForLaunch : SplashService.shared.activeModel
						)
					}
				} label: {
					HStack(spacing: 6) {
						if diagnosticService.isRunningSmokeTest {
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
				.disabled(diagnosticService.isRunningSmokeTest || !SplashService.shared.isRunning)

				Spacer()

				Button {
					copySmokeReportToClipboard()
				} label: {
					Label("Copy Report", systemImage: "doc.on.doc")
						.font(.system(size: 10))
				}
				.buttonStyle(.borderless)
				.disabled(diagnosticService.smokeTestResults.allSatisfy { $0.status == .idle })
			}

			// Test items list
			VStack(spacing: 8) {
				ForEach(diagnosticService.smokeTestResults) { test in
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
		}
	}

	private func copySmokeReportToClipboard() {
		var report = "### Splash Monitor — Model Smoke Diagnostics Report\n"
		report += "Model: \(SplashService.shared.activeModel) | Port: \(SplashService.shared.activePort)\n"
		report += "Date: \(Date().formatted())\n\n"
		for item in diagnosticService.smokeTestResults {
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
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(report, forType: .string)
	}

	// MARK: - 2. Benchmark View

	private var benchmarkView: some View {
		VStack(alignment: .leading, spacing: 14) {
			// Options Row
			HStack(spacing: 12) {
				Picker("Output tokens:", selection: $benchmarkTokens) {
					Text("64 tokens").tag(64)
					Text("128 tokens").tag(128)
					Text("256 tokens").tag(256)
					Text("512 tokens").tag(512)
				}
				.frame(width: 220)

				Button {
					Task {
						await diagnosticService.runBenchmark(
							port: SplashService.shared.activePort,
							targetModel: SplashService.shared.activeModel.isEmpty ? SplashService.shared.selectedModelForLaunch : SplashService.shared.activeModel,
							tokenLimit: benchmarkTokens
						)
					}
				} label: {
					HStack(spacing: 4) {
						if diagnosticService.isRunningBenchmark {
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
				.disabled(diagnosticService.isRunningBenchmark || !SplashService.shared.isRunning)

				Spacer()
			}

			// Progress Bar
			if diagnosticService.isRunningBenchmark {
				VStack(alignment: .leading, spacing: 4) {
					ProgressView(value: diagnosticService.benchmarkProgress, total: 1.0)
					Text(diagnosticService.currentBenchmarkPhase)
						.font(.system(size: 10))
						.foregroundColor(.secondary)
				}
				.padding(10)
				.background(Color(nsColor: .controlBackgroundColor))
				.cornerRadius(8)
			}

			// Results Gauges / Cards
			if let bench = diagnosticService.latestBenchmark {
				VStack(alignment: .leading, spacing: 10) {
					Text("Metal Performance Results")
						.font(.system(size: 13, weight: .semibold))

					LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
						// Card 1: Cold Decode Speed
						metricCard(
							title: LocalizedStringResource("Cold Decode Speed"),
							value: LocalizedStringResource("\(String(format: "%.1f", bench.coldDecodeTokPerSec)) tok/s"),
							icon: "snowflake",
							color: .cyan,
							subtitle: LocalizedStringResource("First pass without prior cache")
						)

						// Card 2: Warm Cached Speed
						metricCard(
							title: LocalizedStringResource("Warm Decode Speed"),
							value: LocalizedStringResource("\(String(format: "%.1f", bench.warmDecodeTokPerSec)) tok/s"),
							icon: "flame.fill",
							color: .orange,
							subtitle: LocalizedStringResource("Replay with indexed prefix")
						)

						// Card 3: Cold TTFT
						metricCard(
							title: LocalizedStringResource("Cold TTFT (1st Token)"),
							value: LocalizedStringResource("\(String(format: "%.0f", bench.coldTTFTMs)) ms"),
							icon: "timer",
							color: .purple,
							subtitle: LocalizedStringResource("Initial prefill latency")
						)

						// Card 4: Cache Speedup Multiplier
						metricCard(
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

	private func metricCard(title: LocalizedStringResource, value: LocalizedStringResource, icon: String, color: Color, subtitle: LocalizedStringResource) -> some View {
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

	// MARK: - 3. Playground View

	private var playgroundView: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Protocol Selector & Sliders
			HStack(spacing: 12) {
				Picker("API:", selection: $playgroundProtocol) {
					Text("OpenAI Chat Completions").tag("openai")
					Text("Anthropic Messages").tag("anthropic")
				}
				.frame(width: 250)

				Text("Tokens: \(Int(playgroundMaxTokens))")
					.font(.system(size: 11))
				Slider(value: $playgroundMaxTokens, in: 32...1024, step: 32)
					.frame(width: 120)

				Text("Temp: \(String(format: "%.1f", playgroundTemperature))")
					.font(.system(size: 11))
				Slider(value: $playgroundTemperature, in: 0.0...1.0, step: 0.1)
					.frame(width: 100)
			}

			// System Prompt (Optional)
			VStack(alignment: .leading, spacing: 3) {
				Text("System Prompt (Optional):")
					.font(.system(size: 10, weight: .medium))
					.foregroundColor(.secondary)
				TextField("E.g. You are an expert software engineering assistant.", text: $playgroundSystemPrompt)
					.textFieldStyle(.roundedBorder)
					.font(.system(size: 11))
			}

			// User Prompt
			VStack(alignment: .leading, spacing: 3) {
				Text("Input Prompt (User):")
					.font(.system(size: 10, weight: .medium))
					.foregroundColor(.secondary)
				TextEditor(text: $playgroundUserPrompt)
					.font(.system(size: 11, design: .monospaced))
					.frame(height: 60)
					.padding(4)
					.background(Color(nsColor: .controlBackgroundColor))
					.cornerRadius(6)
			}

			// Action Button
			HStack {
				Button {
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
				} label: {
					HStack(spacing: 6) {
						if diagnosticService.isGeneratingPlayground {
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
				.disabled(diagnosticService.isGeneratingPlayground || !SplashService.shared.isRunning || playgroundUserPrompt.isEmpty)

				Spacer()

				if !diagnosticService.playgroundRawResponse.isEmpty {
					Toggle(isOn: $showingRawJSON) {
						Text("Raw JSON")
							.font(.system(size: 10))
					}
					.toggleStyle(.checkbox)
				}
			}

			// Output Display
			if diagnosticService.playgroundLastError != nil {
				HStack(spacing: 6) {
					Image(systemName: "exclamationmark.octagon.fill")
						.foregroundColor(.red)
					Text(diagnosticService.playgroundLastError ?? "")
						.font(.system(size: 11))
						.foregroundColor(.red)
				}
				.padding(8)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color.red.opacity(0.1))
				.cornerRadius(6)
			} else if !diagnosticService.playgroundOutput.isEmpty || !diagnosticService.playgroundRawResponse.isEmpty {
				VStack(alignment: .leading, spacing: 6) {
					HStack {
						Text("Model Response:")
							.font(.system(size: 11, weight: .semibold))

						Spacer()

						if diagnosticService.playgroundTokensGenerated > 0 {
							HStack(spacing: 8) {
								Text("\(diagnosticService.playgroundTokensGenerated) tokens")
								Text(verbatim: "•")
								Text("\(String(format: "%.1f", diagnosticService.playgroundTokPerSec)) tok/s")
								Text(verbatim: "•")
								Text("TTFT: \(String(format: "%.0f", diagnosticService.playgroundTTFTMs)) ms")
							}
							.font(.system(size: 10, weight: .medium, design: .monospaced))
							.foregroundColor(.secondary)
						}
					}

					ScrollView {
						Text(showingRawJSON ? diagnosticService.playgroundRawResponse : diagnosticService.playgroundOutput)
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
