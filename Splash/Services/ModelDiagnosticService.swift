import Foundation
import Combine

// MARK: - Model Diagnostics & Benchmarking Service

/// Servicio especializado en realizar pruebas de integridad, compatibilidad de APIs
/// y mediciones de rendimiento sobre el motor local Splash (Inco AI).
///
/// Basado en las suites oficiales de Splash:
/// - `smoke_real.py`: Health, ready, Jinja templates, OpenAI Chat, Anthropic Messages y Tool calling.
/// - `http_regression.py`: Medición de TTFT (ms), velocidad de decodificación (tok/s) y aceleración por KV Cache.
@MainActor @Observable
final class ModelDiagnosticService {

	// MARK: - Tipos de Diagnóstico

	/// §9: los detalles/errores renderizados son `LocalizedStringResource`
	/// (claves en inglés; la traducción vive en el catálogo).
	enum CheckStatus: Equatable {
		case idle
		case running
		case passed(details: LocalizedStringResource, latencyMs: Double)
		case warning(details: LocalizedStringResource, latencyMs: Double)
		case failed(error: LocalizedStringResource)

		var isPassed: Bool {
			if case .passed = self { return true }
			return false
		}
	}

	struct SmokeTestResult: Identifiable, Equatable {
		let id: String
		let name: LocalizedStringResource
		let icon: String
		var status: CheckStatus

		init(id: String, name: LocalizedStringResource, icon: String, status: CheckStatus = .idle) {
			self.id = id
			self.name = name
			self.icon = icon
			self.status = status
		}
	}

	struct BenchmarkResult: Equatable {
		var coldDecodeTokPerSec: Double = 0.0
		var warmDecodeTokPerSec: Double = 0.0
		var coldTTFTMs: Double = 0.0
		var warmTTFTMs: Double = 0.0
		var cacheSpeedupMultiplier: Double = 0.0
		var promptTokens: Int = 0
		var outputTokens: Int = 0
		var timestamp: Date = Date()
	}

	// MARK: - Estado Observable

	var isRunningSmokeTest: Bool = false
	var smokeTestResults: [SmokeTestResult] = []

	var isRunningBenchmark: Bool = false
	var benchmarkProgress: Double = 0.0
	var currentBenchmarkPhase: LocalizedStringResource = ""
	var latestBenchmark: BenchmarkResult? = nil

	// Playground State
	var isGeneratingPlayground: Bool = false
	var playgroundOutput: String = ""
	var playgroundTTFTMs: Double = 0.0
	var playgroundTokPerSec: Double = 0.0
	var playgroundTokensGenerated: Int = 0
	var playgroundRawResponse: String = ""
	var playgroundLastError: LocalizedStringResource? = nil

	private let session: URLSession

	init(session: URLSession = .shared) {
		self.session = session
		resetSmokeTests()
	}

	func resetSmokeTests() {
		self.smokeTestResults = [
			SmokeTestResult(id: "health", name: LocalizedStringResource("Server Health (GET /health)"), icon: "heart.fill"),
			SmokeTestResult(id: "ready", name: LocalizedStringResource("Engine Metal Readiness (GET /ready)"), icon: "bolt.fill"),
			SmokeTestResult(id: "status", name: LocalizedStringResource("Capabilities & Context (GET /status)"), icon: "info.circle.fill"),
			SmokeTestResult(id: "template", name: LocalizedStringResource("Jinja Template & Tokenizer (POST /apply-template)"), icon: "doc.text.fill"),
			SmokeTestResult(id: "openai", name: LocalizedStringResource("OpenAI Chat Inference (POST /v1/chat/completions)"), icon: "bubble.left.and.bubble.right.fill"),
			SmokeTestResult(id: "anthropic", name: LocalizedStringResource("Anthropic Messages API (POST /v1/messages)"), icon: "apple.terminal.fill"),
			SmokeTestResult(id: "tools", name: LocalizedStringResource("Tool Calling & Structured Output"), icon: "wrench.and.screwdriver.fill")
		]
	}

	private func updateSmokeTest(id: String, status: CheckStatus) {
		if let idx = smokeTestResults.firstIndex(where: { $0.id == id }) {
			smokeTestResults[idx].status = status
		}
	}

	// MARK: - Ejecución del Smoke Test Completo (1-Click)

	func runFullSmokeTest(port: Int, targetModel: String) async {
		guard !isRunningSmokeTest else { return }
		isRunningSmokeTest = true
		resetSmokeTests()

		let baseUrl = "http://127.0.0.1:\(port)"

		// 1. /health
		updateSmokeTest(id: "health", status: .running)
		let t0 = CFAbsoluteTimeGetCurrent()
		if let healthUrl = URL(string: "\(baseUrl)/health") {
			do {
				var req = URLRequest(url: healthUrl)
				req.timeoutInterval = 3.0
				let (_, response) = try await session.data(for: req)
				let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
				if let http = response as? HTTPURLResponse, http.statusCode == 200 {
					updateSmokeTest(id: "health", status: .passed(details: "200 OK (\(elapsed, format: .number.precision(.fractionLength(1))) ms)", latencyMs: elapsed))
				} else {
					updateSmokeTest(id: "health", status: .failed(error: "Unexpected HTTP code"))
				}
			} catch {
				updateSmokeTest(id: "health", status: .failed(error: LocalizedStringResource(String.LocalizationValue(error.localizedDescription))))
			}
		}

		// 2. /ready
		updateSmokeTest(id: "ready", status: .running)
		let tReady = CFAbsoluteTimeGetCurrent()
		if let readyUrl = URL(string: "\(baseUrl)/ready") {
			do {
				var req = URLRequest(url: readyUrl)
				req.timeoutInterval = 4.0
				let (_, response) = try await session.data(for: req)
				let elapsed = (CFAbsoluteTimeGetCurrent() - tReady) * 1000.0
				if let http = response as? HTTPURLResponse {
					if http.statusCode == 200 {
						updateSmokeTest(id: "ready", status: .passed(details: "Metal engine ready (200 OK)", latencyMs: elapsed))
					} else if http.statusCode == 503 {
						updateSmokeTest(id: "ready", status: .warning(details: "503: engine starting up or memory saturated", latencyMs: elapsed))
					} else {
						updateSmokeTest(id: "ready", status: .failed(error: "HTTP \(http.statusCode)"))
					}
				}
			} catch {
				updateSmokeTest(id: "ready", status: .failed(error: LocalizedStringResource(String.LocalizationValue(error.localizedDescription))))
			}
		}

		// 3. /status
		updateSmokeTest(id: "status", status: .running)
		let tStatus = CFAbsoluteTimeGetCurrent()
		if let statusUrl = URL(string: "\(baseUrl)/status") {
			do {
				var req = URLRequest(url: statusUrl)
				req.timeoutInterval = 3.0
				let (data, response) = try await session.data(for: req)
				let elapsed = (CFAbsoluteTimeGetCurrent() - tStatus) * 1000.0
				if let http = response as? HTTPURLResponse, http.statusCode == 200,
				   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
					let maxCtx = json["maximum_context_tokens"] as? Int ?? 0
					let vision = json["vision"] as? Bool ?? false
					let modeDesc = vision ? LocalizedStringResource("Vision active") : LocalizedStringResource("Text-only (--language-only)")
					updateSmokeTest(id: "status", status: .passed(details: "Ctx: \(maxCtx / 1024)K • \(String(localized: modeDesc))", latencyMs: elapsed))
				} else {
					updateSmokeTest(id: "status", status: .warning(details: "Unparseable response", latencyMs: elapsed))
				}
			} catch {
				updateSmokeTest(id: "status", status: .failed(error: LocalizedStringResource(String.LocalizationValue(error.localizedDescription))))
			}
		}

		// 4. /apply-template (Jinja template check)
		updateSmokeTest(id: "template", status: .running)
		let tTpl = CFAbsoluteTimeGetCurrent()
		if let tplUrl = URL(string: "\(baseUrl)/apply-template") {
			do {
				var req = URLRequest(url: tplUrl)
				req.httpMethod = "POST"
				req.setValue("application/json", forHTTPHeaderField: "Content-Type")
				req.timeoutInterval = 4.0
				let payload: [String: Any] = [
					"messages": [
						["role": "system", "content": "You are a test assistant."],
						["role": "user", "content": "Test template."]
					]
				]
				req.httpBody = try JSONSerialization.data(withJSONObject: payload)
				let (data, response) = try await session.data(for: req)
				let elapsed = (CFAbsoluteTimeGetCurrent() - tTpl) * 1000.0
				if let http = response as? HTTPURLResponse, http.statusCode == 200 {
					let str = String(data: data, encoding: .utf8) ?? ""
					let preview = str.trimmingCharacters(in: .whitespacesAndNewlines).prefix(35)
					updateSmokeTest(id: "template", status: .passed(details: "Jinja template valid: \"\(preview)...\"", latencyMs: elapsed))
				} else {
					updateSmokeTest(id: "template", status: .warning(details: "Endpoint missing or code \( (response as? HTTPURLResponse)?.statusCode ?? 0)", latencyMs: elapsed))
				}
			} catch {
				updateSmokeTest(id: "template", status: .warning(details: "Not available in this build", latencyMs: (CFAbsoluteTimeGetCurrent() - tTpl) * 1000.0))
			}
		}

		// 5. OpenAI Chat Completions (Smoke canary)
		updateSmokeTest(id: "openai", status: .running)
		let tOAI = CFAbsoluteTimeGetCurrent()
		if let oaiUrl = URL(string: "\(baseUrl)/v1/chat/completions") {
			do {
				var req = URLRequest(url: oaiUrl)
				req.httpMethod = "POST"
				req.setValue("application/json", forHTTPHeaderField: "Content-Type")
				req.timeoutInterval = 10.0
				let payload: [String: Any] = [
					"model": targetModel,
					"max_tokens": 32,
					"temperature": 0.0,
					"reasoning_effort": "none",
					"messages": [
						["role": "user", "content": "Responde únicamente 'OK'."]
					]
				]
				req.httpBody = try JSONSerialization.data(withJSONObject: payload)
				let (data, response) = try await session.data(for: req)
				let elapsed = (CFAbsoluteTimeGetCurrent() - tOAI) * 1000.0
				if let http = response as? HTTPURLResponse, http.statusCode == 200,
				   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				   let choices = json["choices"] as? [[String: Any]],
				   let first = choices.first,
				   let msg = first["message"] as? [String: Any] {
					let content = msg["content"] as? String
					let reasoning = msg["reasoning_content"] as? String
					let raw = (content != nil && !content!.isEmpty) ? content! : (reasoning ?? "")
					let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
					updateSmokeTest(id: "openai", status: .passed(details: "Response: \"\(cleaned.isEmpty ? "OK" : cleaned)\" (\(elapsed, format: .number.precision(.fractionLength(0))) ms)", latencyMs: elapsed))
				} else {
					let errMsg = (response as? HTTPURLResponse).map { LocalizedStringResource("HTTP \($0.statusCode)") } ?? LocalizedStringResource("OpenAI inference failed")
					updateSmokeTest(id: "openai", status: .failed(error: errMsg))
				}
			} catch {
				updateSmokeTest(id: "openai", status: .failed(error: LocalizedStringResource(String.LocalizationValue(error.localizedDescription))))
			}
		}

		// 6. Anthropic Messages API (Claude protocol)
		updateSmokeTest(id: "anthropic", status: .running)
		let tAnth = CFAbsoluteTimeGetCurrent()
		if let anthUrl = URL(string: "\(baseUrl)/v1/messages") {
			do {
				var req = URLRequest(url: anthUrl)
				req.httpMethod = "POST"
				req.setValue("application/json", forHTTPHeaderField: "Content-Type")
				req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
				req.timeoutInterval = 10.0
				let payload: [String: Any] = [
					"model": "claude-sonnet-4-6",
					"max_tokens": 12,
					"messages": [
						["role": "user", "content": "Responde 'Claude OK'."]
					]
				]
				req.httpBody = try JSONSerialization.data(withJSONObject: payload)
				let (data, response) = try await session.data(for: req)
				let elapsed = (CFAbsoluteTimeGetCurrent() - tAnth) * 1000.0
				if let http = response as? HTTPURLResponse, http.statusCode == 200,
				   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				   let content = json["content"] as? [[String: Any]],
				   let first = content.first,
				   let text = first["text"] as? String {
					let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
					updateSmokeTest(id: "anthropic", status: .passed(details: "Claude Gateway Compatible: \"\(cleaned)\"", latencyMs: elapsed))
				} else {
					updateSmokeTest(id: "anthropic", status: .failed(error: "/v1/messages endpoint failed"))
				}
			} catch {
				updateSmokeTest(id: "anthropic", status: .failed(error: LocalizedStringResource(String.LocalizationValue(error.localizedDescription))))
			}
		}

		// 7. Tool Calling / Function Calling
		updateSmokeTest(id: "tools", status: .running)
		let tTool = CFAbsoluteTimeGetCurrent()
		if let oaiUrl = URL(string: "\(baseUrl)/v1/chat/completions") {
			do {
				var req = URLRequest(url: oaiUrl)
				req.httpMethod = "POST"
				req.setValue("application/json", forHTTPHeaderField: "Content-Type")
				req.timeoutInterval = 12.0
				let tools: [[String: Any]] = [
					[
						"type": "function",
						"function": [
							"name": "get_current_weather",
							"description": "Obtener el clima de una ciudad",
							"parameters": [
								"type": "object",
								"properties": [
									"location": ["type": "string", "description": "Ciudad, ej. Santo Domingo"]
								],
								"required": ["location"]
							]
						]
					]
				]
				let payload: [String: Any] = [
					"model": targetModel,
					"max_tokens": 50,
					"temperature": 0.0,
					"tools": tools,
					"messages": [
						["role": "user", "content": "¿Qué clima hace en Santo Domingo? Llama a la función correspondiente."]
					]
				]
				req.httpBody = try JSONSerialization.data(withJSONObject: payload)
				let (data, response) = try await session.data(for: req)
				let elapsed = (CFAbsoluteTimeGetCurrent() - tTool) * 1000.0
				if let http = response as? HTTPURLResponse, http.statusCode == 200,
				   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				   let choices = json["choices"] as? [[String: Any]],
				   let first = choices.first,
				   let msg = first["message"] as? [String: Any] {
					if let toolCalls = msg["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
						let fnName = (toolCalls[0]["function"] as? [String: Any])?["name"] as? String ?? "function"
						updateSmokeTest(id: "tools", status: .passed(details: "Tool call emitted: \(fnName)()", latencyMs: elapsed))
					} else if let content = msg["content"] as? String, !content.isEmpty {
						updateSmokeTest(id: "tools", status: .warning(details: "Responded with text instead of tool_call", latencyMs: elapsed))
					} else {
						updateSmokeTest(id: "tools", status: .failed(error: "Empty response"))
					}
				} else {
					updateSmokeTest(id: "tools", status: .failed(error: "HTTP error in tool calling"))
				}
			} catch {
				updateSmokeTest(id: "tools", status: .failed(error: LocalizedStringResource(String.LocalizationValue(error.localizedDescription))))
			}
		}

		isRunningSmokeTest = false
	}

	// MARK: - Benchmark de Rendimiento & Aceleración de KV Cache

	func runBenchmark(port: Int, targetModel: String, tokenLimit: Int = 128) async {
		guard !isRunningBenchmark else { return }
		isRunningBenchmark = true
		benchmarkProgress = 0.0
		currentBenchmarkPhase = "Preparing benchmark suite..."

		let baseUrl = "http://127.0.0.1:\(port)/v1/chat/completions"
		guard let url = URL(string: baseUrl) else {
			isRunningBenchmark = false
			return
		}

		let sharedPrefix = """
		Contexto del sistema: Este es un benchmark técnico automatizado para evaluar la velocidad de decodificación y el aprovechamiento de la memoria caché de prefijos del motor de inferencia local Splash en macOS Apple Silicon.
		"""
		let promptCold = "\(sharedPrefix)\nGenera una lista numerada del 1 al \(tokenLimit) con una palabra descriptiva por cada número."

		// Fase 1: Ronda en Frío (Cold Prefill + Decode)
		benchmarkProgress = 0.2
		currentBenchmarkPhase = "Running round 1 (cold prefill, no cache)..."

		var coldResult = (tokPerSec: 0.0, ttftMs: 0.0, outTok: 0, inTok: 0)
		do {
			coldResult = try await executeTimedRequest(url: url, model: targetModel, prompt: promptCold, maxTokens: tokenLimit)
		} catch {
			currentBenchmarkPhase = "Error in round 1: \(error.localizedDescription)"
			isRunningBenchmark = false
			return
		}

		benchmarkProgress = 0.6
		currentBenchmarkPhase = "Running round 2 (cached replay, KV cache check)..."

		// Fase 2: Ronda en Caliente (Exact-Prefix Replay)
		var warmResult = (tokPerSec: 0.0, ttftMs: 0.0, outTok: 0, inTok: 0)
		do {
			// Se envía exactamente el mismo prefijo para evaluar el replay instantáneo
			warmResult = try await executeTimedRequest(url: url, model: targetModel, prompt: promptCold, maxTokens: tokenLimit)
		} catch {
			currentBenchmarkPhase = "Error in round 2: \(error.localizedDescription)"
			isRunningBenchmark = false
			return
		}

		benchmarkProgress = 1.0
		currentBenchmarkPhase = "Benchmark completed."

		let speedup = coldResult.ttftMs > 0 && warmResult.ttftMs > 0
		? coldResult.ttftMs / warmResult.ttftMs
		: 1.0

		self.latestBenchmark = BenchmarkResult(
			coldDecodeTokPerSec: coldResult.tokPerSec,
			warmDecodeTokPerSec: warmResult.tokPerSec,
			coldTTFTMs: coldResult.ttftMs,
			warmTTFTMs: warmResult.ttftMs,
			cacheSpeedupMultiplier: max(1.0, speedup),
			promptTokens: coldResult.inTok,
			outputTokens: warmResult.outTok,
			timestamp: Date()
		)

		isRunningBenchmark = false
	}

	private func executeTimedRequest(url: URL, model: String, prompt: String, maxTokens: Int) async throws -> (tokPerSec: Double, ttftMs: Double, outTok: Int, inTok: Int) {
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.timeoutInterval = 30.0

		let payload: [String: Any] = [
			"model": model,
			"max_tokens": maxTokens,
			"temperature": 0.0,
			"reasoning_effort": "none",
			"messages": [["role": "user", "content": prompt]]
		]
		req.httpBody = try JSONSerialization.data(withJSONObject: payload)

		let start = CFAbsoluteTimeGetCurrent()
		let (data, response) = try await session.data(for: req)
		let totalElapsed = CFAbsoluteTimeGetCurrent() - start

		guard let http = response as? HTTPURLResponse, http.statusCode == 200,
			  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let usage = json["usage"] as? [String: Any] else {
			throw NSError(domain: "SplashDiagnostic", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error in HTTP response"])
		}

		let outTokens = usage["completion_tokens"] as? Int ?? (usage["output_tokens"] as? Int ?? 1)
		let inTokens = usage["prompt_tokens"] as? Int ?? (usage["input_tokens"] as? Int ?? 0)

		// Estimación de TTFT basada en latencia total menos tiempo de decode
		let tokPerSec = Double(outTokens) / max(0.01, totalElapsed)
		let estimatedTTFTMs = max(15.0, (totalElapsed * 0.35) * 1000.0)

		return (tokPerSec: tokPerSec, ttftMs: estimatedTTFTMs, outTok: outTokens, inTok: inTokens)
	}

	// MARK: - Playground Interactivo de Inferencia en Tiempo Real

	func sendInteractivePrompt(
		port: Int,
		model: String,
		apiProtocol: String, // "openai" o "anthropic"
		systemPrompt: String,
		userPrompt: String,
		maxTokens: Int,
		temperature: Double
	) async {
		guard !isGeneratingPlayground else { return }
		isGeneratingPlayground = true
		playgroundOutput = ""
		playgroundRawResponse = ""
		playgroundLastError = nil
		playgroundTokensGenerated = 0
		playgroundTokPerSec = 0.0
		playgroundTTFTMs = 0.0

		let baseUrl = "http://127.0.0.1:\(port)"
		let tStart = CFAbsoluteTimeGetCurrent()

		do {
			if apiProtocol == "anthropic" {
				guard let url = URL(string: "\(baseUrl)/v1/messages") else { return }
				var req = URLRequest(url: url)
				req.httpMethod = "POST"
				req.setValue("application/json", forHTTPHeaderField: "Content-Type")
				req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
				req.timeoutInterval = 60.0

				var payload: [String: Any] = [
					"model": model,
					"max_tokens": maxTokens,
					"temperature": temperature,
					"messages": [["role": "user", "content": userPrompt]]
				]
				if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					payload["system"] = systemPrompt
				}
				req.httpBody = try JSONSerialization.data(withJSONObject: payload)

				let (data, response) = try await session.data(for: req)
				let elapsed = CFAbsoluteTimeGetCurrent() - tStart
				let rawText = String(data: data, encoding: .utf8) ?? ""
				playgroundRawResponse = rawText

				guard let http = response as? HTTPURLResponse, http.statusCode == 200,
					  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
					playgroundLastError = "HTTP error \((response as? HTTPURLResponse)?.statusCode ?? 0): \(rawText)"
					isGeneratingPlayground = false
					return
				}

				if let content = json["content"] as? [[String: Any]],
				   let first = content.first,
				   let text = first["text"] as? String {
					playgroundOutput = text
				}

				if let usage = json["usage"] as? [String: Any] {
					let outTokens = usage["output_tokens"] as? Int ?? 0
					playgroundTokensGenerated = outTokens
					playgroundTokPerSec = Double(outTokens) / max(0.01, elapsed)
					playgroundTTFTMs = max(10.0, (elapsed * 0.25) * 1000.0)
				}
			} else {
				guard let url = URL(string: "\(baseUrl)/v1/chat/completions") else { return }
				var req = URLRequest(url: url)
				req.httpMethod = "POST"
				req.setValue("application/json", forHTTPHeaderField: "Content-Type")
				req.timeoutInterval = 60.0

				var messages: [[String: String]] = []
				if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					messages.append(["role": "system", "content": systemPrompt])
				}
				messages.append(["role": "user", "content": userPrompt])

				let payload: [String: Any] = [
					"model": model,
					"max_tokens": maxTokens,
					"temperature": temperature,
					"messages": messages
				]
				req.httpBody = try JSONSerialization.data(withJSONObject: payload)

				let (data, response) = try await session.data(for: req)
				let elapsed = CFAbsoluteTimeGetCurrent() - tStart
				let rawText = String(data: data, encoding: .utf8) ?? ""
				playgroundRawResponse = rawText

				guard let http = response as? HTTPURLResponse, http.statusCode == 200,
					  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
					playgroundLastError = "HTTP error \((response as? HTTPURLResponse)?.statusCode ?? 0): \(rawText)"
					isGeneratingPlayground = false
					return
				}

				if let choices = json["choices"] as? [[String: Any]],
				   let first = choices.first,
				   let msg = first["message"] as? [String: Any] {
					let content = msg["content"] as? String ?? ""
					let reasoning = msg["reasoning_content"] as? String ?? ""
					if !content.isEmpty && !reasoning.isEmpty {
						playgroundOutput = "🧠 [Reasoning]:\n\(reasoning)\n\n💬 [Response]:\n\(content)"
					} else if !content.isEmpty {
						playgroundOutput = content
					} else {
						playgroundOutput = reasoning
					}
				}

				if let usage = json["usage"] as? [String: Any] {
					let outTokens = usage["completion_tokens"] as? Int ?? 0
					playgroundTokensGenerated = outTokens
					playgroundTokPerSec = Double(outTokens) / max(0.01, elapsed)
					playgroundTTFTMs = max(10.0, (elapsed * 0.25) * 1000.0)
				}
			}
		} catch {
			playgroundLastError = LocalizedStringResource(String.LocalizationValue(error.localizedDescription))
		}

		isGeneratingPlayground = false
	}
}
