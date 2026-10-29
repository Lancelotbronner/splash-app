import Foundation

// MARK: - Splash Native Status Models

struct SplashStatus: Codable, Equatable {
	let ready: Bool?
	let maximumContextTokens: Int?
	let memoryPressure: String?
	let instance: InstanceInfo?
	let memoryPlan: MemoryPlan?
	let memoryActual: MemoryActual?
	let memoryGovernor: MemoryGovernor?
	let cache: CacheMetrics?
	let scheduler: SchedulerMetrics?
	let requests: RequestMetrics?
	let metrics: PerformanceMetrics?
	let vision: Bool?
	let inputModalities: [String]?
	let thermalState: String?
	let aneFfn: AneFfnMetrics?
	let weights: WeightsStatus?
	// Splash 1.4.0+ Telemetry
	let streaming: StreamingStatus?
	let kvSpill: KvSpillStatus?
	let verificationMode: String?

	enum CodingKeys: String, CodingKey {
		case ready
		case maximumContextTokens = "maximum_context_tokens"
		case memoryPressure = "memory_pressure"
		case instance
		case memoryPlan = "memory_plan"
		case memoryActual = "memory_actual"
		case memoryGovernor = "memory_governor"
		case cache
		case scheduler
		case requests
		case metrics
		case vision
		case inputModalities = "input_modalities"
		case thermalState = "thermal_state"
		case aneFfn = "ane_ffn"
		case weights
		case streaming
		case kvSpill = "kv_spill"
		case verificationMode = "verification_mode"
	}
}

struct InstanceInfo: Codable, Equatable {
	let id: String?
	let pid: Int?
	let model: String?
	let host: String?
	let port: Int?
	let startedAt: Double?

	enum CodingKeys: String, CodingKey {
		case id, pid, model, host, port
		case startedAt = "started_at"
	}
}

struct MemoryPlan: Codable, Equatable {
	let device: DeviceInfo?
	let model: ModelInfo?
	let budget: MemoryBudget?
}

struct DeviceInfo: Codable, Equatable {
	let deviceName: String?
	let macosVersion: String?
	let gpuCoreCount: Int?
	let physicalMemoryBytes: Int64?
	let recommendedMaxWorkingSetBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case deviceName = "device_name"
		case macosVersion = "macos_version"
		case gpuCoreCount = "gpu_core_count"
		case physicalMemoryBytes = "physical_memory_bytes"
		case recommendedMaxWorkingSetBytes = "recommended_max_working_set_bytes"
	}
}

struct ModelInfo: Codable, Equatable {
	let modelName: String?
	let maximumContextTokens: Int?
	let attentionLayers: Int?

	enum CodingKeys: String, CodingKey {
		case modelName = "model_name"
		case maximumContextTokens = "maximum_context_tokens"
		case attentionLayers = "attention_layers"
	}
}

struct MemoryBudget: Codable, Equatable {
	let physicalMemoryBytes: Int64?
	let hardBudgetBytes: Int64?
	let targetWeightsBytes: Int64?
	let draftWeightsBytes: Int64?
	let fixedRuntimeBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case physicalMemoryBytes = "physical_memory_bytes"
		case hardBudgetBytes = "hard_budget_bytes"
		case targetWeightsBytes = "target_weights_bytes"
		case draftWeightsBytes = "draft_weights_bytes"
		case fixedRuntimeBytes = "fixed_runtime_bytes"
	}
}

struct MemoryActual: Codable, Equatable {
	let currentBytes: Int64?
	let peakBytes: Int64?
	let denseBytes: Int64?
	let sparseResidentBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case currentBytes = "current_bytes"
		case peakBytes = "peak_bytes"
		case denseBytes = "dense_bytes"
		case sparseResidentBytes = "sparse_resident_bytes"
	}
}

struct MemoryGovernor: Codable, Equatable {
	let limitBytes: Int64?
	let observedResidentBytes: Int64?
	let headroomBytes: Int64?
	let systemPressure: String?
	let hostAvailableBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case limitBytes = "limit_bytes"
		case observedResidentBytes = "observed_resident_bytes"
		case headroomBytes = "headroom_bytes"
		case systemPressure = "system_pressure"
		case hostAvailableBytes = "host_available_bytes"
	}
}

struct CacheMetrics: Codable, Equatable {
	let lookups: Int?
	let hits: Int?
	let coldMisses: Int?
	let hitRate: Double?
	let reusedTokens: Int64?
	let kvHitTokens: Int64?
	let deduplicatedTokens: Int64?

	enum CodingKeys: String, CodingKey {
		case lookups, hits
		case coldMisses = "cold_misses"
		case hitRate = "hit_rate"
		case reusedTokens = "reused_tokens"
		case kvHitTokens = "kv_hit_tokens"
		case deduplicatedTokens = "deduplicated_tokens"
	}
}

struct SchedulerMetrics: Codable, Equatable {
	let queued: Int?
	let prefilling: Int?
	let decoding: Int?
	let prefillBatches: Int?
	let decodeBatches: Int?

	enum CodingKeys: String, CodingKey {
		case queued, prefilling, decoding
		case prefillBatches = "prefill_batches"
		case decodeBatches = "decode_batches"
	}
}

struct RequestMetrics: Codable, Equatable {
	let submitted: Int?
	let completed: Int?
	let cancelled: Int?
	let failed: Int?
}

struct PerformanceMetrics: Codable, Equatable {
	let prefillInputTokens: Int64?
	let prefillTokensPerSecond: Double?
	let decodeOutputTokens: Int64?
	let decodeTokensPerSecond: Double?
	let draftedTokens: Int64?
	let acceptedDraftTokens: Int64?
	let draftAcceptanceRate: Double?
	let ttftMs: PercentileMetric?
	let itlMs: PercentileMetric?

	enum CodingKeys: String, CodingKey {
		case prefillInputTokens = "prefill_input_tokens"
		case prefillTokensPerSecond = "prefill_tokens_per_second"
		case decodeOutputTokens = "decode_output_tokens"
		case decodeTokensPerSecond = "decode_tokens_per_second"
		case draftedTokens = "drafted_tokens"
		case acceptedDraftTokens = "accepted_draft_tokens"
		case draftAcceptanceRate = "draft_acceptance_rate"
		case ttftMs = "ttft_ms"
		case itlMs = "itl_ms"
	}
}

struct PercentileMetric: Codable, Equatable {
	let p50: Double?
	let p95: Double?
	let samples: Int?
}

struct AneFfnMetrics: Codable, Equatable {
	let state: String?
	let share: Double?
	let minPromptChunk: Int?
	let evaluations: Int?
	let timing: Double?
	let reruns: Int?

	enum CodingKeys: String, CodingKey {
		case state, share, evaluations, timing, reruns
		case minPromptChunk = "min_prompt_chunk"
	}
}

struct WeightsStatus: Codable, Equatable {
	let idleReleaseSeconds: Double?
	let released: Bool?
	let restores: Int?

	enum CodingKeys: String, CodingKey {
		case idleReleaseSeconds = "idle_release_seconds"
		case released, restores
	}
}

// MARK: - Splash 1.4.0+ Streaming & KV Spill Models

struct StreamingStatus: Codable, Equatable {
	let enabled: Bool?
	let expertMemoryBytes: Int64?
	let pleMemoryBytes: Int64?
	let activeStreams: Int?

	enum CodingKeys: String, CodingKey {
		case enabled
		case expertMemoryBytes = "expert_memory_bytes"
		case pleMemoryBytes = "ple_memory_bytes"
		case activeStreams = "active_streams"
	}
}

struct KvSpillStatus: Codable, Equatable {
	let active: Bool?
	let spilledTokens: Int?
	let spilledBytes: Int64?
	let hotTokens: Int?

	enum CodingKeys: String, CodingKey {
		case active
		case spilledTokens = "spilled_tokens"
		case spilledBytes = "spilled_bytes"
		case hotTokens = "hot_tokens"
	}
}

// MARK: - Lock file model

/// Datos puros del bloqueo del motor; `nonisolated` (§7) para poder decodificarse
/// desde el sondeo de bloqueos que ahora corre fuera del actor principal.
nonisolated struct ServeLock: Codable, Equatable {
	let pid: Int
	let model: String
	let port: Int
}

// MARK: - Hugging Face & Local Model Info

struct HuggingFaceModelItem: Codable, Equatable, Identifiable {
	var id: String
	let likes: Int?
	let downloads: Int?
	let tags: [String]?
	let pipelineTag: String?
	let createdAt: String?

	enum CodingKeys: String, CodingKey {
		case id, likes, downloads, tags
		case pipelineTag = "pipeline_tag"
		case createdAt
	}

	var isOfficial: Bool {
		if id.hasSuffix("-Splash") { return false }
		// Splash 1.3.x — Qwen3 base family
		if id.hasPrefix("mlx-community/Qwen3.8-27B") { return true }
		if id.hasPrefix("mlx-community/Qwen3.6-35B") { return true }
		if id.hasPrefix("nvidia/Qwen3.8-27B") { return true }
		// Splash 1.4.0 — Qwen3.8-Flash-Next (GGUF only)
		if id.hasPrefix("ISTA-DASLab/Qwen3.8-Flash-Next") { return true }
		// Splash 1.4.1 — Ornith-1.5-122B (GGUF + MLX con visión)
		if id.hasPrefix("unsloth/Ornith-1.5-122B") { return true }
		if id.hasPrefix("ornith-ai/Ornith-1.5-122B") { return true }
		// Splash 1.4.1 — Flint 40B-A2.5B MoE (GGUF, 262K contexto)
		if id.hasPrefix("unsloth/flint-GGUF") { return true }
		if id.hasPrefix("unsloth/Flint") { return true }
		if id.hasPrefix("incoai/Flint") { return true }
		if id.hasPrefix("RecursiveSI/Flint") { return true }
		return false
	}

	var displayName: String {
		return id.components(separatedBy: "/").last ?? id
	}
}

/// Fila del catálogo local; `nonisolated` (§7) porque la construcción ocurre en
/// el escaneo del directorio de modelos, que ahora corre fuera del actor principal.
nonisolated struct InstalledSplashModel: Identifiable, Equatable, Hashable {
	var id: String { repoId }
	let repoId: String
	let localPath: URL
	let diskSizeBytes: Int64
	let isCurrentlyActive: Bool

	var formattedSize: String {
		let gb = Double(diskSizeBytes) / 1_073_741_824.0
		if gb >= 1.0 {
			return String(format: "%.1f GB", gb)
		}
		let mb = Double(diskSizeBytes) / 1_048_576.0
		return String(format: "%.0f MB", mb)
	}

	var shortName: String {
		repoId.components(separatedBy: "/").last ?? repoId
	}

	var variant: String? {
		ModelIDValidator.components(from: repoId)?.variant
	}

	var isCoderFineTune: Bool {
		let lower = repoId.lowercased()
		return lower.contains("coder") || lower.contains("code") || lower.contains("qwopus") || lower.contains("tiel")
	}
}
