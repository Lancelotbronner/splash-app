import Foundation

// MARK: - Splash Native Status Models

/// Mirrors the engine's `/status` payload, following the engine's v6 payload
/// (`schema_version: 6`) key by key.
struct SplashStatus: Codable, Equatable {
	let schemaVersion: Int?
	let ready: Bool?
	let maximumContextTokens: Int?
	let memoryPressure: String?
	let thermalState: String?
	let admission: AdmissionStatus?
	let loop: LoopStatus?
	let identity: IdentityStatus?
	let instance: InstanceInfo?
	let memoryPlan: MemoryPlan?
	let memoryActual: MemoryActual?
	let memoryGovernor: MemoryGovernor?
	let memoryAudit: MemoryAudit?
	let streamedTable: StreamedTable?
	let streamedExperts: StreamedExperts?
	let verifyRows: String?
	// Only emitted while a block-sparse target's KV can spill to the SSD;
	// absent from /status for targets that keep their KV in memory.
	let kvSpill: KvSpillStatus?
	let kv: KVStatus?
	let state: StateStatus?
	let disk: DiskStatus?
	let draftContext: DraftContext?
	let cache: CacheMetrics?
	let modelTiming: ModelTiming?
	let constraintMasks: ConstraintMasks?
	let images: ImageStats?
	let scheduler: SchedulerMetrics?
	let activeRequests: [ActiveRequest]?
	let requests: RequestMetrics?
	let metrics: PerformanceMetrics?
	let warmup: WarmupStatus?
	let metal: MetalHealth?
	let transport: TransportStatus?
	let vision: Bool?
	let inputModalities: [String]?
	let reasoningSwitch: Bool?
	let chatTemplate: ChatTemplate?
	let frontend: FrontendStatus?
	let grammarCache: GrammarCache?
	let responseStore: ResponseStore?
	let imageCache: ImageCacheStats?
	let tokenizerCache: TokenizerCache?
	let latency: [String: LatencyHistogram]?
	let aneFfn: AneFfnMetrics?
	let weights: WeightsStatus?
	let http: HTTPStatus?

	enum CodingKeys: String, CodingKey {
		case schemaVersion = "schema_version"
		case ready
		case maximumContextTokens = "maximum_context_tokens"
		case memoryPressure = "memory_pressure"
		case thermalState = "thermal_state"
		case admission
		case loop
		case identity
		case instance
		case memoryPlan = "memory_plan"
		case memoryActual = "memory_actual"
		case memoryGovernor = "memory_governor"
		case memoryAudit = "memory_audit"
		case streamedTable = "streamed_table"
		case streamedExperts = "streamed_experts"
		case verifyRows = "verify_rows"
		case kvSpill = "kv_spill"
		case kv
		case state
		case disk
		case draftContext = "draft_context"
		case cache
		case modelTiming = "model_timing"
		case constraintMasks = "constraint_masks"
		case images
		case scheduler
		case activeRequests = "active_requests"
		case requests
		case metrics
		case warmup
		case metal
		case transport
		case vision
		case inputModalities = "input_modalities"
		case reasoningSwitch = "reasoning_switch"
		case chatTemplate = "chat_template"
		case frontend
		case grammarCache = "grammar_cache"
		case responseStore = "response_store"
		case imageCache = "image_cache"
		case tokenizerCache = "tokenizer_cache"
		case latency
		case aneFfn = "ane_ffn"
		case weights
		case http
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

struct AdmissionStatus: Codable, Equatable {
	let waiting: Int?
	let waitingMemory: Int?
	let waitingConcurrency: Int?
	let heldBehindRefusal: Int?
	let restoring: Int?
	let suspended: Int?
	let draining: Bool?
	let oldestWaitMs: Double?

	enum CodingKeys: String, CodingKey {
		case waiting
		case waitingMemory = "waiting_memory"
		case waitingConcurrency = "waiting_concurrency"
		case heldBehindRefusal = "held_behind_refusal"
		case restoring
		case suspended
		case draining
		case oldestWaitMs = "oldest_wait_ms"
	}
}

struct LoopStatus: Codable, Equatable {
	/// Longest control pass / engine step of the native loop.
	let maxTickMs: Double?

	enum CodingKeys: String, CodingKey {
		case maxTickMs = "max_tick_ms"
	}
}

struct IdentityStatus: Codable, Equatable {
	let cache: IdentityCache?
	let kv: IdentityKv?
}

struct IdentityCache: Codable, Equatable {
	let loadedModelLayoutSha256: String?
	let buildId: String?
	let dtype: String?
	let blockTokens: Int?
	let ropeScaling: RopeScaling?

	enum CodingKeys: String, CodingKey {
		case loadedModelLayoutSha256 = "loaded_model_layout_sha256"
		case buildId = "build_id"
		case dtype
		case blockTokens = "block_tokens"
		case ropeScaling = "rope_scaling"
	}
}

/// Target RoPE scaling for `--max-context` past 256K; null otherwise.
struct RopeScaling: Codable, Equatable {
	let type: String?
	let factor: Double?
	let originalContextTokens: Int?

	enum CodingKeys: String, CodingKey {
		case type, factor
		case originalContextTokens = "original_context_tokens"
	}
}

struct IdentityKv: Codable, Equatable {
	let targetModelSha256: String?
	let format: String?
	let quantization: String?
	let scaleType: String?
	let keyLayout: String?
	let valueLayout: String?

	enum CodingKeys: String, CodingKey {
		case targetModelSha256 = "target_model_sha256"
		case format
		case quantization
		case scaleType = "scale_type"
		case keyLayout = "key_layout"
		case valueLayout = "value_layout"
	}
}

struct MemoryPlan: Codable, Equatable {
	let valid: Bool?
	let device: DeviceInfo?
	let model: ModelInfo?
	let budget: MemoryBudget?
}

struct DeviceInfo: Codable, Equatable {
	let deviceName: String?
	let macosVersion: String?
	let appleGpuFamily: Int?
	let gpuCoreCount: Int?
	let physicalMemoryBytes: Int64?
	let recommendedMaxWorkingSetBytes: Int64?
	let maxBufferLengthBytes: Int64?
	let maxThreadgroupMemoryBytes: Int64?
	let maxThreadgroupWidth: Int?
	let hasUnifiedMemory: Bool?

	enum CodingKeys: String, CodingKey {
		case deviceName = "device_name"
		case macosVersion = "macos_version"
		case appleGpuFamily = "apple_gpu_family"
		case gpuCoreCount = "gpu_core_count"
		case physicalMemoryBytes = "physical_memory_bytes"
		case recommendedMaxWorkingSetBytes = "recommended_max_working_set_bytes"
		case maxBufferLengthBytes = "max_buffer_length_bytes"
		case maxThreadgroupMemoryBytes = "max_threadgroup_memory_bytes"
		case maxThreadgroupWidth = "max_threadgroup_width"
		case hasUnifiedMemory = "has_unified_memory"
	}
}

struct ModelInfo: Codable, Equatable {
	let modelName: String?
	let maximumContextTokens: Int?
	let attentionLayers: Int?
	let kvHeads: Int?
	let headDimension: Int?
	let kvPageTokens: Int?
	let kvFormat: String?
	let kvElementsPerScale: Int?
	let kvPageBytes: Int64?
	let stateFormat: String?
	let memory: ModelMemory?

	enum CodingKeys: String, CodingKey {
		case modelName = "model_name"
		case maximumContextTokens = "maximum_context_tokens"
		case attentionLayers = "attention_layers"
		case kvHeads = "kv_heads"
		case headDimension = "head_dimension"
		case kvPageTokens = "kv_page_tokens"
		case kvFormat = "kv_format"
		case kvElementsPerScale = "kv_elements_per_scale"
		case kvPageBytes = "kv_page_bytes"
		case stateFormat = "state_format"
		case memory
	}
}

struct ModelMemory: Codable, Equatable {
	let targetWeightsBytes: Int64?
	let draftWeightsBytes: Int64?
	let visionWeightsBytes: Int64?
	let laneStateBytes: Int64?
	let sharedPrefillBytes: Int64?
	let sharedDecodeBytes: Int64?
	let pipelineReserveBytes: Int64?
	let runtimeOverheadReserveBytes: Int64?
	let streamedTableBytes: Int64?
	let aneFfnBytes: Int64?
	let stateStagingBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case targetWeightsBytes = "target_weights_bytes"
		case draftWeightsBytes = "draft_weights_bytes"
		case visionWeightsBytes = "vision_weights_bytes"
		case laneStateBytes = "lane_state_bytes"
		case sharedPrefillBytes = "shared_prefill_bytes"
		case sharedDecodeBytes = "shared_decode_bytes"
		case pipelineReserveBytes = "pipeline_reserve_bytes"
		case runtimeOverheadReserveBytes = "runtime_overhead_reserve_bytes"
		case streamedTableBytes = "streamed_table_bytes"
		case aneFfnBytes = "ane_ffn_bytes"
		case stateStagingBytes = "state_staging_bytes"
	}
}

struct MemoryBudget: Codable, Equatable {
	let physicalMemoryBytes: Int64?
	let hardBudgetBytes: Int64?
	let targetWeightsBytes: Int64?
	let draftWeightsBytes: Int64?
	let visionWeightsBytes: Int64?
	let configuredMemoryLimitBytes: Int64?
	let workingSetMarginBytes: Int64?
	let maximumBatchWidth: Int?
	let laneStateBytes: Int64?
	let sharedPrefillBytes: Int64?
	let sharedDecodeBytes: Int64?
	let pipelineReserveBytes: Int64?
	let runtimeOverheadReserveBytes: Int64?
	let streamedTableBytes: Int64?
	let aneFfnBytes: Int64?
	let stateStagingBytes: Int64?
	let fixedRuntimeBytes: Int64?
	let dynamicBudgetBytes: Int64?
	let kvExtentPages: Int?
	let kvExtentBytes: Int64?
	let kvCapacityPages: Int?
	let kvCapacityBytes: Int64?
	let kvCapacityTokens: Int?
	let kvIndexPageBytes: Int64?
	let contextBounds: ContextBounds?
	let minimumDynamicBytes: Int64?
	let minimumRequiredBytes: Int64?
	let deficitBytes: Int64?
	// "kv_spill" (plan-level) is null unless the target's KV can spill to the
	// SSD; its non-null shape is not documented, so it is not modeled here.

	enum CodingKeys: String, CodingKey {
		case physicalMemoryBytes = "physical_memory_bytes"
		case hardBudgetBytes = "hard_budget_bytes"
		case targetWeightsBytes = "target_weights_bytes"
		case draftWeightsBytes = "draft_weights_bytes"
		case visionWeightsBytes = "vision_weights_bytes"
		case configuredMemoryLimitBytes = "configured_memory_limit_bytes"
		case workingSetMarginBytes = "working_set_margin_bytes"
		case maximumBatchWidth = "maximum_batch_width"
		case laneStateBytes = "lane_state_bytes"
		case sharedPrefillBytes = "shared_prefill_bytes"
		case sharedDecodeBytes = "shared_decode_bytes"
		case pipelineReserveBytes = "pipeline_reserve_bytes"
		case runtimeOverheadReserveBytes = "runtime_overhead_reserve_bytes"
		case streamedTableBytes = "streamed_table_bytes"
		case aneFfnBytes = "ane_ffn_bytes"
		case stateStagingBytes = "state_staging_bytes"
		case fixedRuntimeBytes = "fixed_runtime_bytes"
		case dynamicBudgetBytes = "dynamic_budget_bytes"
		case kvExtentPages = "kv_extent_pages"
		case kvExtentBytes = "kv_extent_bytes"
		case kvCapacityPages = "kv_capacity_pages"
		case kvCapacityBytes = "kv_capacity_bytes"
		case kvCapacityTokens = "kv_capacity_tokens"
		case kvIndexPageBytes = "kv_index_page_bytes"
		case contextBounds = "context_bounds"
		case minimumDynamicBytes = "minimum_dynamic_bytes"
		case minimumRequiredBytes = "minimum_required_bytes"
		case deficitBytes = "deficit_bytes"
	}
}

/// What bounds `maximum_context_tokens`: the model window, one request's KV in
/// memory (resident), the longest context the floors/SSD cache hold (spilled /
/// disk), and which bound sets the limit (`model`, `memory` or `disk`).
struct ContextBounds: Codable, Equatable {
	let window: Int?
	let resident: Int?
	let spilled: Int?
	let disk: Int?
	let bound: String?
}

struct MemoryActual: Codable, Equatable {
	let allocatedBytes: Int64?
	let currentBytes: Int64?
	let peakBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case allocatedBytes = "allocated_bytes"
		case currentBytes = "current_bytes"
		case peakBytes = "peak_bytes"
	}
}

struct MemoryGovernor: Codable, Equatable {
	let limitBytes: Int64?
	let chargedBytes: Int64?
	let headroomBytes: Int64?
	let growthAllowed: Bool?
	let deniedReservations: Int?
	let systemPressure: String?
	let hostMeasurementValid: Bool?
	let hostAvailableBytes: Int64?
	let hostReserveBytes: Int64?
	let hostSpareBytes: Int64?
	let hostSpareReserveBytes: Int64?
	let hostHeadroomBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case limitBytes = "limit_bytes"
		case chargedBytes = "charged_bytes"
		case headroomBytes = "headroom_bytes"
		case growthAllowed = "growth_allowed"
		case deniedReservations = "denied_reservations"
		case systemPressure = "system_pressure"
		case hostMeasurementValid = "host_measurement_valid"
		case hostAvailableBytes = "host_available_bytes"
		case hostReserveBytes = "host_reserve_bytes"
		case hostSpareBytes = "host_spare_bytes"
		case hostSpareReserveBytes = "host_spare_reserve_bytes"
		case hostHeadroomBytes = "host_headroom_bytes"
	}
}

struct MemoryAudit: Codable, Equatable {
	let scope: String?
	let valid: Bool?
	let error: String?
	let categorizedBytes: Int64?
	let backendUnclassifiedBytes: Int64?
	let deviceUntrackedBytes: Int64?
	let devicePeakDeviationBasisPoints: Int?
	let actualHeadroomBytes: Int64?
	let backendAllocatedBytes: Int64?
	let deviceCurrentAllocatedBytes: Int64?
	let devicePeakAllocatedBytes: Int64?
	let backendPeakAllocatedBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case scope, valid, error
		case categorizedBytes = "categorized_bytes"
		case backendUnclassifiedBytes = "backend_unclassified_bytes"
		case deviceUntrackedBytes = "device_untracked_bytes"
		case devicePeakDeviationBasisPoints = "device_peak_deviation_basis_points"
		case actualHeadroomBytes = "actual_headroom_bytes"
		case backendAllocatedBytes = "backend_allocated_bytes"
		case deviceCurrentAllocatedBytes = "device_current_allocated_bytes"
		case devicePeakAllocatedBytes = "device_peak_allocated_bytes"
		case backendPeakAllocatedBytes = "backend_peak_allocated_bytes"
	}
}

struct CacheMetrics: Codable, Equatable {
	let probeHashedBlocks: Int?
	let hits: Int?
	let coldMisses: Int?
	let hitRate: Double?
	let kvHitTokens: Int64?
	let kvDiskHitTokens: Int64?
	let lostStateMisses: Int?
	let reusedTokens: Int64?
	let deduplicatedKvTokens: Int64?
	let replayStatePublications: Int64?
	let deduplicatedStatePublications: Int64?
	let recycledStatePublications: Int64?
	let diskStatePublications: Int64?
	let stateCaptures: Int64?
	let captureCuts: Int64?
	let replayStatePublicationFailures: Int64?
	let lazyJunctions: Int64?
	let junctionMaterializations: Int64?
	let junctionMaterializationFailures: Int64?
	let checkpointPublications: Int64?
	let checkpointPublicationFailures: Int64?
	let resourceSuspensions: Int64?
	let prioritySuspensions: Int64?
	let resourceResumptions: Int64?
	let resourceReplayTokens: Int64?

	enum CodingKeys: String, CodingKey {
		case probeHashedBlocks = "probe_hashed_blocks"
		case hits
		case coldMisses = "cold_misses"
		case hitRate = "hit_rate"
		case kvHitTokens = "kv_hit_tokens"
		case kvDiskHitTokens = "kv_disk_hit_tokens"
		case lostStateMisses = "lost_state_misses"
		case reusedTokens = "reused_tokens"
		case deduplicatedKvTokens = "deduplicated_kv_tokens"
		case replayStatePublications = "replay_state_publications"
		case deduplicatedStatePublications = "deduplicated_state_publications"
		case recycledStatePublications = "recycled_state_publications"
		case diskStatePublications = "disk_state_publications"
		case stateCaptures = "state_captures"
		case captureCuts = "capture_cuts"
		case replayStatePublicationFailures = "replay_state_publication_failures"
		case lazyJunctions = "lazy_junctions"
		case junctionMaterializations = "junction_materializations"
		case junctionMaterializationFailures = "junction_materialization_failures"
		case checkpointPublications = "checkpoint_publications"
		case checkpointPublicationFailures = "checkpoint_publication_failures"
		case resourceSuspensions = "resource_suspensions"
		case prioritySuspensions = "priority_suspensions"
		case resourceResumptions = "resource_resumptions"
		case resourceReplayTokens = "resource_replay_tokens"
	}
}

struct KVStatus: Codable, Equatable {
	let blockTokens: Int?
	let pagesAllocated: Int?
	let pagesActive: Int?
	let pagesCache: Int?
	let pagesFree: Int?
	let allocatedBytes: Int64?
	let reclaimableBytes: Int64?
	let extentAllocations: Int?
	let extentReleases: Int?
	let extentAllocateMaxMs: Double?
	let extentReleaseMaxMs: Double?
	let extentCompactions: Int?
	let pagesMoved: Int?
	let extentCompactMaxMs: Double?
	let window: KVWindow?

	enum CodingKeys: String, CodingKey {
		case blockTokens = "block_tokens"
		case pagesAllocated = "pages_allocated"
		case pagesActive = "pages_active"
		case pagesCache = "pages_cache"
		case pagesFree = "pages_free"
		case allocatedBytes = "allocated_bytes"
		case reclaimableBytes = "reclaimable_bytes"
		case extentAllocations = "extent_allocations"
		case extentReleases = "extent_releases"
		case extentAllocateMaxMs = "extent_allocate_max_ms"
		case extentReleaseMaxMs = "extent_release_max_ms"
		case extentCompactions = "extent_compactions"
		case pagesMoved = "pages_moved"
		case extentCompactMaxMs = "extent_compact_max_ms"
		case window
	}
}

/// Sliding-window layers: absent for targets without them.
struct KVWindow: Codable, Equatable {
	let windowPages: Int?
	let trim: Bool?
	let fullPages: Int?
	let slimPages: Int?
	let slimBytes: Int64?
	let pinnedBlocks: Int?
	let trimmedPages: Int?
	/// Blocks that took the page of a writer that computed them again.
	let upgrades: Int?
	let refusedStates: Int?

	enum CodingKeys: String, CodingKey {
		case windowPages = "window_pages"
		case trim
		case fullPages = "full_pages"
		case slimPages = "slim_pages"
		case slimBytes = "slim_bytes"
		case pinnedBlocks = "pinned_blocks"
		case trimmedPages = "trimmed_pages"
		case upgrades
		case refusedStates = "refused_states"
	}
}

struct StateStatus: Codable, Equatable {
	let entries: Int?
	let pinned: Int?
	let inUse: Int?
	let inUseEvictions: Int?
	let bytes: Int64?
	let allocatedBytes: Int64?
	let activeLanes: Int?
	let idleGdnCells: Int?
	let idleDraftRings: Int?
	let idleContextWindows: Int?
	let publications: Int64?
	let evictions: Int64?
	let checkpointEntries: Int?
	let checkpointBytes: Int64?
	let checkpointEvictions: Int?
	let checkpointRetirements: Int?
	let diskHits: Int?
	let diskPromotions: Int?
	let diskPromotionsSkipped: Int?
	let diskBytes: Int64?
	let offloads: Int?
	let offloadFailures: Int?
	let invalidations: Int?

	enum CodingKeys: String, CodingKey {
		case entries, pinned
		case inUse = "in_use"
		case inUseEvictions = "in_use_evictions"
		case bytes
		case allocatedBytes = "allocated_bytes"
		case activeLanes = "active_lanes"
		case idleGdnCells = "idle_gdn_cells"
		case idleDraftRings = "idle_draft_rings"
		case idleContextWindows = "idle_context_windows"
		case publications
		case evictions
		case checkpointEntries = "checkpoint_entries"
		case checkpointBytes = "checkpoint_bytes"
		case checkpointEvictions = "checkpoint_evictions"
		case checkpointRetirements = "checkpoint_retirements"
		case diskHits = "disk_hits"
		case diskPromotions = "disk_promotions"
		case diskPromotionsSkipped = "disk_promotions_skipped"
		case diskBytes = "disk_bytes"
		case offloads
		case offloadFailures = "offload_failures"
		case invalidations
	}
}

struct DiskStatus: Codable, Equatable {
	let capacityBytes: Int64?
	let limitBytes: Int64?
	let usedBytes: Int64?
	let fileBytes: Int64?
	let volumeAvailableBytes: Int64?
	let writesGated: String?
	let writeBudgetBytes: Int64?
	/// Emitted as microseconds / 1000.0, so fractional.
	let writesDeferredMs: Double?
	let readBytes: Int64?
	let writtenBytes: Int64?
	let kvBlocks: Int?
	let kvBytes: Int64?
	let kvDemotions: Int?
	let kvDemotionFailures: Int?
	let kvDemotionsRefused: Int?
	let kvRestores: Int?
	let kvRestoreFailures: Int?
	let kvPendingPages: Int?
	let persistent: Bool?
	let kvCopies: Int?
	let kvCopyFailures: Int?
	let takenBack: TakenBack?
	let writeBehind: WriteBehind?

	enum CodingKeys: String, CodingKey {
		case capacityBytes = "capacity_bytes"
		case limitBytes = "limit_bytes"
		case usedBytes = "used_bytes"
		case fileBytes = "file_bytes"
		case volumeAvailableBytes = "volume_available_bytes"
		case writesGated = "writes_gated"
		case writeBudgetBytes = "write_budget_bytes"
		case writesDeferredMs = "writes_deferred_ms"
		case readBytes = "read_bytes"
		case writtenBytes = "written_bytes"
		case kvBlocks = "kv_blocks"
		case kvBytes = "kv_bytes"
		case kvDemotions = "kv_demotions"
		case kvDemotionFailures = "kv_demotion_failures"
		case kvDemotionsRefused = "kv_demotions_refused"
		case kvRestores = "kv_restores"
		case kvRestoreFailures = "kv_restore_failures"
		case kvPendingPages = "kv_pending_pages"
		case persistent
		case kvCopies = "kv_copies"
		case kvCopyFailures = "kv_copy_failures"
		case takenBack = "taken_back"
		case writeBehind = "write_behind"
	}
}

struct TakenBack: Codable, Equatable {
	let states: Int?
	let kvBlocks: Int?
	let bytes: Int64?
	let leftBehind: Int?

	enum CodingKeys: String, CodingKey {
		case states
		case kvBlocks = "kv_blocks"
		case bytes
		case leftBehind = "left_behind"
	}
}

struct WriteBehind: Codable, Equatable {
	let waiting: Int?
	let durable: Int?
	let unneeded: Int?
	let refused: Int?
}

struct DraftContext: Codable, Equatable {
	let targetPrefillRows: Int?
	let promptEndRows: Int?
	let materializationRows: Int?
	let avoidedRows: Int?
	let restoreSkipped: Int?
	let resets: Int?

	enum CodingKeys: String, CodingKey {
		case targetPrefillRows = "target_prefill_rows"
		case promptEndRows = "prompt_end_rows"
		case materializationRows = "materialization_rows"
		case avoidedRows = "avoided_rows"
		case restoreSkipped = "restore_skipped"
		case resets
	}
}

struct SchedulerMetrics: Codable, Equatable {
	let queued: Int?
	let waitingResources: Int?
	let waitingPrefix: Int?
	let prefilling: Int?
	let decoding: Int?
	let waitingMask: Int?
	let terminal: Int?
	let prefillBatches: Int?
	let prefillRows: Int?
	let decodeBatches: Int?
	let decodeBatchesByWidth: [String: Int]?

	enum CodingKeys: String, CodingKey {
		case queued
		case waitingResources = "waiting_resources"
		case waitingPrefix = "waiting_prefix"
		case prefilling
		case decoding
		case waitingMask = "waiting_mask"
		case terminal
		case prefillBatches = "prefill_batches"
		case prefillRows = "prefill_rows"
		case decodeBatches = "decode_batches"
		case decodeBatchesByWidth = "decode_batches_by_width"
	}
}

/// One request the engine holds, ordered by id.
struct ActiveRequest: Codable, Equatable {
	let id: Int?
	/// queued, waiting_resources, waiting_prefix, prefill, decode, waiting_mask,
	/// or failed (deadline passed while its cached state was read from disk).
	let phase: String?
	let priority: String?
	let promptTokens: Int?
	let promptProcessed: Int?
	let generatedTokens: Int?
	let maxNewTokens: Int?
	/// Where a block-sparse target keeps its KV (`resident` or `spill`); only
	/// present while its KV can go to the SSD.
	let kvMode: String?
	let ageMs: Double?

	enum CodingKeys: String, CodingKey {
		case id, phase, priority
		case promptTokens = "prompt_tokens"
		case promptProcessed = "prompt_processed"
		case generatedTokens = "generated_tokens"
		case maxNewTokens = "max_new_tokens"
		case kvMode = "kv_mode"
		case ageMs = "age_ms"
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
	let prefillWallMs: Double?
	let prefillTokensPerSecond: Double?
	let decodeOutputTokens: Int64?
	let decodeWallMs: Double?
	let decodeCycleMs: Double?
	let decodeTokensPerSecond: Double?
	let draftedTokens: Int64?
	let acceptedDraftTokens: Int64?
	let draftAcceptanceRate: Double?
	let capacityFailures: Int?
	let metalFailures: Int?
	let currentPrefillBatch: BatchMetrics?
	let currentDecodeBatch: BatchMetrics?
	let ttftMs: PercentileMetric?
	let itlMs: PercentileMetric?

	enum CodingKeys: String, CodingKey {
		case prefillInputTokens = "prefill_input_tokens"
		case prefillWallMs = "prefill_wall_ms"
		case prefillTokensPerSecond = "prefill_tokens_per_second"
		case decodeOutputTokens = "decode_output_tokens"
		case decodeWallMs = "decode_wall_ms"
		case decodeCycleMs = "decode_cycle_ms"
		case decodeTokensPerSecond = "decode_tokens_per_second"
		case draftedTokens = "drafted_tokens"
		case acceptedDraftTokens = "accepted_draft_tokens"
		case draftAcceptanceRate = "draft_acceptance_rate"
		case capacityFailures = "capacity_failures"
		case metalFailures = "metal_failures"
		case currentPrefillBatch = "current_prefill_batch"
		case currentDecodeBatch = "current_decode_batch"
		case ttftMs = "ttft_ms"
		case itlMs = "itl_ms"
	}
}

struct BatchMetrics: Codable, Equatable {
	let valid: Bool?
	let width: Int?
	let inputTokens: Int?
	let outputTokens: Int?
	let draftedTokens: Int?
	let acceptedDraftTokens: Int?
	let wallMs: Double?
	let tokensPerSecond: Double?

	enum CodingKeys: String, CodingKey {
		case valid, width
		case inputTokens = "input_tokens"
		case outputTokens = "output_tokens"
		case draftedTokens = "drafted_tokens"
		case acceptedDraftTokens = "accepted_draft_tokens"
		case wallMs = "wall_ms"
		case tokensPerSecond = "tokens_per_second"
	}
}

struct PercentileMetric: Codable, Equatable {
	let p50: Double?
	let p95: Double?
	let samples: Int?
}

/// GPU time of prefill/decode commands, warmup included; with the Neural
/// Engine split it spans the GPU's waits on the Neural Engine.
struct ModelTiming: Codable, Equatable {
	let scope: String?
	let prefill: PhaseTiming?
	let decode: PhaseTiming?
}

struct PhaseTiming: Codable, Equatable {
	let lastGpuMs: Double?
	let lastWallMs: Double?
	let totalGpuMs: Double?
	let totalWallMs: Double?

	enum CodingKeys: String, CodingKey {
		case lastGpuMs = "last_gpu_ms"
		case lastWallMs = "last_wall_ms"
		case totalGpuMs = "total_gpu_ms"
		case totalWallMs = "total_wall_ms"
	}
}

struct ConstraintMasks: Codable, Equatable {
	let overlapBatches: Int?
	let overlapRequests: Int?
	let lastTargetForwardGpuMs: Double?
	let totalTargetForwardGpuMs: Double?
	let lastResidualWaitMs: Double?
	let totalResidualWaitMs: Double?

	enum CodingKeys: String, CodingKey {
		case overlapBatches = "overlap_batches"
		case overlapRequests = "overlap_requests"
		case lastTargetForwardGpuMs = "last_target_forward_gpu_ms"
		case totalTargetForwardGpuMs = "total_target_forward_gpu_ms"
		case lastResidualWaitMs = "last_residual_wait_ms"
		case totalResidualWaitMs = "total_residual_wait_ms"
	}
}

struct ImageStats: Codable, Equatable {
	let encodes: Int?
	let embeddingReuses: Int?
	let embeddingEvictions: Int?
	let arenaBytes: Int64?
	let cachedBytes: Int64?
	let stateHeldBytes: Int64?
	let rowsBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case encodes
		case embeddingReuses = "embedding_reuses"
		case embeddingEvictions = "embedding_evictions"
		case arenaBytes = "arena_bytes"
		case cachedBytes = "cached_bytes"
		case stateHeldBytes = "state_held_bytes"
		case rowsBytes = "rows_bytes"
	}
}

struct WarmupStatus: Codable, Equatable {
	/// Key is "prefill_" + the engine's prefill token budget ("prefill_2048"
	/// with the current budget).
	let prefill2048: Bool?
	let decodeB1: Bool?
	let decodeB2: Bool?
	let decodeB3: Bool?
	let decodeB4: Bool?
	let compositeStateRestore: Bool?
	let memoryLimitedSteps: [String]?
	let detail: String?

	enum CodingKeys: String, CodingKey {
		case prefill2048 = "prefill_2048"
		case decodeB1 = "decode_b1"
		case decodeB2 = "decode_b2"
		case decodeB3 = "decode_b3"
		case decodeB4 = "decode_b4"
		case compositeStateRestore = "composite_state_restore"
		case memoryLimitedSteps = "memory_limited_steps"
		case detail
	}
}

struct MetalHealth: Codable, Equatable {
	let healthy: Bool?
	let failureReason: String?

	enum CodingKeys: String, CodingKey {
		case healthy
		case failureReason = "failure_reason"
	}
}

struct TransportStatus: Codable, Equatable {
	let ready: Bool?
	let recovering: Bool?
	let stopped: Bool?
	let pending: Int?
	let pendingLimit: Int?
	let restarts: Int?
	let lastCrashTrace: String?
	let statusStale: Bool?
	let statusAgeMs: Double?
	/// Names the failure, the last failed restart, or why restarts stopped.
	let error: String?

	enum CodingKeys: String, CodingKey {
		case ready
		case recovering
		case stopped
		case pending
		case pendingLimit = "pending_limit"
		case restarts
		case lastCrashTrace = "last_crash_trace"
		case statusStale = "status_stale"
		case statusAgeMs = "status_age_ms"
		case error
	}
}

struct ChatTemplate: Codable, Equatable {
	/// How system messages after the first render: native, patched or unsupported.
	let laterSystem: String?

	enum CodingKeys: String, CodingKey {
		case laterSystem = "later_system"
	}
}

struct FrontendStatus: Codable, Equatable {
	let preparationCapacity: Int?
	let active: Int?
	let waiting: Int?

	enum CodingKeys: String, CodingKey {
		case preparationCapacity = "preparation_capacity"
		case active
		case waiting
	}
}

struct GrammarCache: Codable, Equatable {
	let entries: Int?
	let capacity: Int?
	let sourceBytes: Int64?
	let sourceBudgetBytes: Int64?
	let hits: Int?
	let misses: Int?

	enum CodingKeys: String, CodingKey {
		case entries
		case capacity
		case sourceBytes = "source_bytes"
		case sourceBudgetBytes = "source_budget_bytes"
		case hits
		case misses
	}
}

struct ResponseStore: Codable, Equatable {
	let entries: Int?
	let bytes: Int64?
	let budgetBytes: Int64?
	let evictions: Int?
	let hits: Int?
	let misses: Int?

	enum CodingKeys: String, CodingKey {
		case entries
		case bytes
		case budgetBytes = "budget_bytes"
		case evictions
		case hits
		case misses
	}
}

struct ImageCacheStats: Codable, Equatable {
	let entries: Int?
	let bytes: Int64?
	let budgetBytes: Int64?
	let requestBytes: Int64?
	let requestBudgetBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case entries
		case bytes
		case budgetBytes = "budget_bytes"
		case requestBytes = "request_bytes"
		case requestBudgetBytes = "request_budget_bytes"
	}
}

struct TokenizerCache: Codable, Equatable {
	let enabled: Bool?
	let entries: Int?
	let bytes: Int64?
	let budgetBytes: Int64?
	let capacity: Int?
	let hits: Int?
	let reusedTokens: Int64?

	enum CodingKeys: String, CodingKey {
		case enabled
		case entries
		case bytes
		case budgetBytes = "budget_bytes"
		case capacity
		case hits
		case reusedTokens = "reused_tokens"
	}
}

/// Fixed latency histogram, in seconds: cumulative buckets labeled by upper
/// bound (including "+Inf"), sample count and sum.
struct LatencyHistogram: Codable, Equatable {
	let buckets: [String: Int]
	let count: Int
	let sum: Double
}

struct AneFfnMetrics: Codable, Equatable {
	/// off, split or stopped.
	let state: String?
	let share: Double?
	let minimumRows: Int?
	let reason: String?
	let splitCommands: Int?
	let evaluations: Int?
	let aneMs: Double?
	let reruns: Int?

	enum CodingKeys: String, CodingKey {
		case state, share
		case minimumRows = "minimum_rows"
		case reason
		case splitCommands = "split_commands"
		case evaluations
		case aneMs = "ane_ms"
		case reruns
	}
}

struct WeightsStatus: Codable, Equatable {
	let idleReleaseSeconds: Double?
	let released: Bool?
	let restoring: Bool?
	let restores: Int?
	let restoreFailures: Int?

	enum CodingKeys: String, CodingKey {
		case idleReleaseSeconds = "idle_release_seconds"
		case released
		case restoring
		case restores
		case restoreFailures = "restore_failures"
	}
}

// MARK: - v6 streamed tables, experts & KV spill

/// A `model::LatencyStats` block: quantiles, maximum and total in
/// milliseconds, and the sample count. (Distinct from `LatencyHistogram`,
/// the Prometheus-style buckets/count/sum under `latency`.)
struct LatencyStats: Codable, Equatable {
	let p50: Double?
	let p95: Double?
	let p99: Double?
	let max: Double?
	let total: Double?
	let samples: Int?
}

/// The pickup/work/resume round trips of a host step, per latency stage.
struct HostSteps: Codable, Equatable {
	let pickupMs: LatencyStats?
	let workMs: LatencyStats?
	let resumeMs: LatencyStats?

	enum CodingKeys: String, CodingKey {
		case pickupMs = "pickup_ms"
		case workMs = "work_ms"
		case resumeMs = "resume_ms"
	}
}

/// The streamed PLE table's store (`--ple-memory`), or null.
struct StreamedTable: Codable, Equatable {
	let table: String?
	let tableBytes: Int64?
	let cacheBytes: Int64?
	let cacheCapacityRows: Int64?
	let cachedRows: Int64?
	let evictions: Int?
	let prefill: StreamedUse?
	let decode: StreamedUse?
	let readBytes: Int64?
	let readRetries: Int?
	let readErrors: Int?
	let readMs: LatencyStats?
	let prefetchRequestedRows: Int64?
	let prefetchReadRows: Int64?
	let prefetchDroppedRows: Int64?
	let poisoned: Bool?
	let failure: String?

	enum CodingKeys: String, CodingKey {
		case table
		case tableBytes = "table_bytes"
		case cacheBytes = "cache_bytes"
		case cacheCapacityRows = "cache_capacity_rows"
		case cachedRows = "cached_rows"
		case evictions
		case prefill
		case decode
		case readBytes = "read_bytes"
		case readRetries = "read_retries"
		case readErrors = "read_errors"
		case readMs = "read_ms"
		case prefetchRequestedRows = "prefetch_requested_rows"
		case prefetchReadRows = "prefetch_read_rows"
		case prefetchDroppedRows = "prefetch_dropped_rows"
		case poisoned
		case failure
	}
}

/// Per use (prefill, decode) counters of a streamed table.
struct StreamedUse: Codable, Equatable {
	let stages: Int?
	let requestedRows: Int64?
	let uniqueRows: Int64?
	let hitRows: Int64?
	let readRows: Int64?
	let hitRate: Double?
	let stageMs: LatencyStats?

	enum CodingKeys: String, CodingKey {
		case stages
		case requestedRows = "requested_rows"
		case uniqueRows = "unique_rows"
		case hitRows = "hit_rows"
		case readRows = "read_rows"
		case hitRate = "hit_rate"
		case stageMs = "stage_ms"
	}
}

/// The streamed routed experts' store (`--expert-memory`), or null.
struct StreamedExperts: Codable, Equatable {
	let capBytes: Int64?
	let floorBytes: Int64?
	let chunks: Int?
	let capChunks: Int?
	let shrinks: Int?
	let regrows: Int?
	let arenaBytes: Int64?
	let stagingBytes: Int64?
	let slots: Int?
	let experts: Int?
	let resident: Int?
	let prefill: ExpertUse?
	let decode: ExpertUse?
	let failure: String?

	enum CodingKeys: String, CodingKey {
		case capBytes = "cap_bytes"
		case floorBytes = "floor_bytes"
		case chunks
		case capChunks = "cap_chunks"
		case shrinks
		case regrows
		case arenaBytes = "arena_bytes"
		case stagingBytes = "staging_bytes"
		case slots
		case experts
		case resident
		case prefill
		case decode
		case failure
	}
}

/// Per use (prefill, decode) counters of the expert store.
struct ExpertUse: Codable, Equatable {
	let loads: Int64?
	let routed: Int64?
	let read: Int64?
	let prefetched: Int64?
	let readAhead: Int64?
	let hitRate: Double?
	let readBytes: Int64?
	let hostSteps: HostSteps?

	enum CodingKeys: String, CodingKey {
		case loads
		case routed
		case read
		case prefetched
		case readAhead = "read_ahead"
		case hitRate = "hit_rate"
		case readBytes = "read_bytes"
		case hostSteps = "host_steps"
	}
}

/// A spill-capable target's KV on the SSD cache (`kv_spill`).
struct KvSpillStatus: Codable, Equatable {
	let requests: KvSpillRequests?
	let pages: KvSpillPages?
	let writeThrough: WriteThrough?
	let spillMoves: Int64?
	let unspills: Int64?
	let rewrites: Int64?
	let restores: KvSpillRestores?
	let quota: KvSpillQuota?
	let indexRunwayBytes: Int64?
	let blockCache: KvBlockCache?
	let historyStream: KvHistoryStream?

	enum CodingKeys: String, CodingKey {
		case requests
		case pages
		case writeThrough = "write_through"
		case spillMoves = "spill_moves"
		case unspills
		case rewrites
		case restores
		case quota
		case indexRunwayBytes = "index_runway_bytes"
		case blockCache = "block_cache"
		case historyStream = "history_stream"
	}
}

struct KvSpillRequests: Codable, Equatable {
	let spill: Int?
	let resident: Int?
	let converted: Int?
	let bounded: Int?
	let lengthEnds: Int?
	let refused: KvSpillRefusals?
	let waitingQuota: Int?

	enum CodingKeys: String, CodingKey {
		case spill
		case resident
		case converted
		case bounded
		case lengthEnds = "length_ends"
		case refused
		case waitingQuota = "waiting_quota"
	}
}

struct KvSpillRefusals: Codable, Equatable {
	let quota: Int?
	let writeBudget: Int?
	let closed: Int?

	enum CodingKeys: String, CodingKey {
		case quota
		case writeBudget = "write_budget"
		case closed
	}
}

struct KvSpillPages: Codable, Equatable {
	/// Pages holding only their index.
	let index: Int?
	let indexBytes: Int64?
	let spilled: Int?
	let spilledBytes: Int64?

	enum CodingKeys: String, CodingKey {
		case index
		case indexBytes = "index_bytes"
		case spilled
		case spilledBytes = "spilled_bytes"
	}
}

struct WriteThrough: Codable, Equatable {
	let pages: Int64?
	let bytes: Int64?
	let inFlight: Int?
	let failures: Int?
	let paused: Bool?

	enum CodingKeys: String, CodingKey {
		case pages
		case bytes
		case inFlight = "in_flight"
		case failures
		case paused
	}
}

struct KvSpillRestores: Codable, Equatable {
	let indexPages: Int?
	let wholePages: Int?
	let ms: LatencyStats?

	enum CodingKeys: String, CodingKey {
		case indexPages = "index_pages"
		case wholePages = "whole_pages"
		case ms
	}
}

struct KvSpillQuota: Codable, Equatable {
	let activeLimitBytes: Int64?
	let heldBytes: Int64?
	let committedBytes: Int64?
	let revoked: Int64?

	enum CodingKeys: String, CodingKey {
		case activeLimitBytes = "active_limit_bytes"
		case heldBytes = "held_bytes"
		case committedBytes = "committed_bytes"
		case revoked
	}
}

/// The hot block cache of spilled pages; null when the target has none.
struct KvBlockCache: Codable, Equatable {
	let bytes: Int64?
	let targetBytes: Int64?
	let floorBytes: Int64?
	let slotsPerLayer: Int?
	let lanes: Int?
	// `model::KvReadStats` counters: resolves, block-list entries, those of
	// Full pages, cached hits, misses read, hit rate, ghost hits, bytes and failures.
	let resolves: Int64?
	let entries: Int64?
	let paged: Int64?
	let hits: Int64?
	let read: Int64?
	let hitRate: Double?
	let ghostHits: Int64?
	let readBytes: Int64?
	let readFailures: Int?
	let resolveMs: LatencyStats?
	let readMs: LatencyStats?
	let hostSteps: HostSteps?

	enum CodingKeys: String, CodingKey {
		case bytes
		case targetBytes = "target_bytes"
		case floorBytes = "floor_bytes"
		case slotsPerLayer = "slots_per_layer"
		case lanes
		case resolves
		case entries
		case paged
		case hits
		case read
		case hitRate = "hit_rate"
		case ghostHits = "ghost_hits"
		case readBytes = "read_bytes"
		case readFailures = "read_failures"
		case resolveMs = "resolve_ms"
		case readMs = "read_ms"
		case hostSteps = "host_steps"
	}
}

/// The history streams that run beside decoders; null when none ran.
struct KvHistoryStream: Codable, Equatable {
	let commands: Int?
	let contendedCommands: Int?
	let layers: Int?
	let pages: Int64?
	let bytes: Int64?
	let stagingBytes: Int64?
	let buffers: Int?
	let readMs: LatencyStats?
	let waitMs: LatencyStats?
	let decodeGapMs: LatencyStats?

	enum CodingKeys: String, CodingKey {
		case commands
		case contendedCommands = "contended_commands"
		case layers
		case pages
		case bytes
		case stagingBytes = "staging_bytes"
		case buffers
		case readMs = "read_ms"
		case waitMs = "wait_ms"
		case decodeGapMs = "decode_gap_ms"
	}
}

// MARK: - HTTP process

struct HTTPStatus: Codable, Equatable {
	let requests: HTTPCounter?
	let requestBodyBytes: HTTPCounter?
	let maxRequestBytes: Int64?
	let tokenCounts: HTTPCounter?
	let connections: HTTPCounter?

	enum CodingKeys: String, CodingKey {
		case requests
		case requestBodyBytes = "request_body_bytes"
		case maxRequestBytes = "max_request_bytes"
		case tokenCounts = "token_counts"
		case connections
	}
}

struct HTTPCounter: Codable, Equatable {
	let active: Int?
	let capacity: Int?
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

	/// §9: `ByteCountFormatStyle` (localizable) en lugar de `String(format:)`.
	var formattedSize: String {
		diskSizeBytes.formatted(.byteCount(style: .file))
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
