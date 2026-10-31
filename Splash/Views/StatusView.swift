import Foundation
import SwiftUI

/// Read-only inspector of the engine's live `/status` payload
/// (`SplashService.shared.status`): a grouped form, one section per part of
/// the model, each drilling into every field of that part.
struct StatusView: View {
	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Engine Status")
		}
	}

	@ViewBuilder
	private var content: some View {
		if let status = SplashService.shared.status {
			StatusRootForm(status: status)
		} else {
			ContentUnavailableView {
				Label("No Status", systemImage: "waveform.path.ecg")
			} description: {
				Text("Start the Splash server to see the live engine status.")
			}
		}
	}
}

// MARK: - Root form

private struct StatusRootForm: View {
	let status: SplashStatus

	var body: some View {
		Form {
			Section("Overview") {
				StatusBool(label: "Ready", value: status.ready)
				StatusText(label: "Memory Pressure", value: status.memoryPressure)
				StatusText(label: "Thermal State", value: status.thermalState)
				StatusNumber(label: "Context Limit", value: status.maximumContextTokens)
				StatusBool(label: "Vision Input", value: status.vision)
				if let modalities = status.inputModalities {
					LabeledContent("Input Modalities") {
						Text(modalities.joined(separator: ", "))
					}
				}
				StatusBool(label: "Reasoning Switch", value: status.reasoningSwitch)
				StatusText(label: "Verify Rows", value: status.verifyRows)
				StatusNumber(label: "Schema Version", value: status.schemaVersion)
			}

			Section {
				if let instance = status.instance {
					LabeledContent("Model") {
						Text(instance.model ?? "—")
							.lineLimit(1)
							.truncationMode(.middle)
					}
					LabeledContent("Endpoint") {
						Text(endpoint(of: instance))
							.monospacedDigit()
					}
					StatusNumber(label: "PID", value: instance.pid)
				}
			} header: {
				NavigationLink("Instance") { InstanceDetail(instance: status.instance) }
			}

			Section {
				StatusBytes(label: "In Use", value: status.memoryActual?.currentBytes)
				StatusBytes(label: "Peak", value: status.memoryActual?.peakBytes)
				StatusBytes(label: "Headroom", value: status.memoryGovernor?.headroomBytes)
				StatusText(label: "Pressure", value: status.memoryGovernor?.systemPressure)
			} header: {
				NavigationLink("Memory") {
					MemoryDetail(plan: status.memoryPlan,
								 actual: status.memoryActual,
								 governor: status.memoryGovernor,
								 audit: status.memoryAudit)
				}
			}

			Section {
				StatusNumber(label: "Queued", value: status.scheduler?.queued)
				StatusNumber(label: "Prefilling", value: status.scheduler?.prefilling)
				StatusNumber(label: "Decoding", value: status.scheduler?.decoding)
				LabeledContent("Active Requests") {
					Text("\(status.activeRequests?.count ?? 0)")
						.monospacedDigit()
				}
				LabeledContent("Completed") {
					Text("\(status.requests?.completed ?? 0)")
						.monospacedDigit()
				}
				LabeledContent("Failed") {
					Text("\(status.requests?.failed ?? 0)")
						.monospacedDigit()
						.foregroundColor((status.requests?.failed ?? 0) > 0 ? .red : .primary)
				}
			} header: {
				NavigationLink("Scheduler") {
					SchedulerDetail(scheduler: status.scheduler,
									requests: status.requests,
									activeRequests: status.activeRequests)
				}
			}

			Section {
				StatusSpeed(label: "Decode", value: status.metrics?.decodeTokensPerSecond)
				StatusSpeed(label: "Prefill", value: status.metrics?.prefillTokensPerSecond)
				StatusMs(label: "TTFT p50", value: status.metrics?.ttftMs?.p50)
				StatusMs(label: "ITL p50", value: status.metrics?.itlMs?.p50)
				StatusPercent(label: "Draft Acceptance", value: status.metrics?.draftAcceptanceRate)
			} header: {
				NavigationLink("Performance") {
					MetricsDetail(metrics: status.metrics, modelTiming: status.modelTiming)
				}
			}

			Section {
				StatusPercent(label: "Hit Rate", value: status.cache?.hitRate)
				StatusNumber(label: "Reused Tokens", value: status.cache?.reusedTokens)
				StatusNumber(label: "KV Hit Tokens", value: status.cache?.kvHitTokens)
				StatusNumber(label: "Probe Blocks", value: status.cache?.probeHashedBlocks)
			} header: {
				NavigationLink("Cache") {
					CacheDetail(cache: status.cache, draftContext: status.draftContext)
				}
			}

			Section {
				StatusNumber(label: "KV Pages Active", value: status.kv?.pagesActive)
				StatusBytes(label: "KV Allocated", value: status.kv?.allocatedBytes)
				StatusBytes(label: "Disk Used", value: status.disk?.usedBytes)
				StatusBytes(label: "KV on Disk", value: status.disk?.kvBytes)
			} header: {
				NavigationLink("KV & Disk") {
					KVDetail(kv: status.kv, state: status.state, disk: status.disk, kvSpill: status.kvSpill)
				}
			}

			Section {
				StatusText(label: "ANE FFN", value: status.aneFfn?.state)
				StatusPercent(label: "ANE Share", value: status.aneFfn?.share)
				StatusMs(label: "ANE Time", value: status.aneFfn?.aneMs)
				StatusBool(label: "Weights Released", value: status.weights?.released)
				StatusNumber(label: "Weight Restores", value: status.weights?.restores)
			} header: {
				NavigationLink("Neural Engine & Weights") {
					ANEDetail(aneFfn: status.aneFfn, weights: status.weights)
				}
			}

			Section {
				StatusBool(label: "Transport Ready", value: status.transport?.ready)
				StatusBool(label: "Metal Healthy", value: status.metal?.healthy)
				StatusMs(label: "Max Loop Tick", value: status.loop?.maxTickMs)
				StatusNumber(label: "Admission Waiting", value: status.admission?.waiting)
			} header: {
				NavigationLink("Engine Health") {
					EngineDetail(transport: status.transport,
								 metal: status.metal,
								 loop: status.loop,
								 admission: status.admission,
								 warmup: status.warmup,
								 identity: status.identity)
				}
			}

			if status.streamedTable != nil || status.streamedExperts != nil {
				Section {
					StatusText(label: "PLE Table", value: status.streamedTable?.table)
					StatusBytes(label: "Table Bytes", value: status.streamedTable?.tableBytes)
					StatusNumber(label: "Expert Slots", value: status.streamedExperts?.slots)
					StatusNumber(label: "Resident Experts", value: status.streamedExperts?.resident)
				} header: {
					NavigationLink("Streaming") {
						StreamedDetail(table: status.streamedTable, experts: status.streamedExperts)
					}
				}
			}

			Section {
				LabeledContent("HTTP Requests") {
					Text("\(status.http?.requests?.active ?? 0) / \(status.http?.requests?.capacity ?? 0)")
						.monospacedDigit()
				}
				LabeledContent("Connections") {
					Text("\(status.http?.connections?.active ?? 0) / \(status.http?.connections?.capacity ?? 0)")
						.monospacedDigit()
				}
				StatusNumber(label: "Grammar Cache Hits", value: status.grammarCache?.hits)
				StatusNumber(label: "Tokenizer Hits", value: status.tokenizerCache?.hits)
			} header: {
				NavigationLink("Process") {
					ProcessDetail(http: status.http,
								  frontend: status.frontend,
								  grammarCache: status.grammarCache,
								  responseStore: status.responseStore,
								  imageCache: status.imageCache,
								  tokenizerCache: status.tokenizerCache)
				}
			}

			Section {
				LabeledContent("Stages") {
					Text("\(status.latency?.count ?? 0)")
						.monospacedDigit()
				}
			} header: {
				NavigationLink("Latency") {
					LatencyDetail(latency: status.latency)
				}
			}
		}
		.formStyle(.grouped)
	}

	private func endpoint(of instance: InstanceInfo) -> String {
		var text = instance.host ?? "?"
		if let port = instance.port {
			text += ":\(port)"
		}
		return text
	}
}

// MARK: - Detail: Instance

private struct InstanceDetail: View {
	let instance: InstanceInfo?

	var body: some View {
		Form {
			if let instance {
				Section("Instance") {
					StatusText(label: "Model", value: instance.model)
					StatusText(label: "ID", value: instance.id)
					StatusNumber(label: "PID", value: instance.pid)
					StatusText(label: "Host", value: instance.host)
					StatusNumber(label: "Port", value: instance.port)
					if let startedAt = instance.startedAt {
						LabeledContent("Started") {
							Text(Date(timeIntervalSince1970: startedAt), format: .dateTime.year().month().day().hour().minute().second())
						}
					}
				}
			} else {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Instance")
	}
}

// MARK: - Detail: Memory

private struct MemoryDetail: View {
	let plan: MemoryPlan?
	let actual: MemoryActual?
	let governor: MemoryGovernor?
	let audit: MemoryAudit?

	var body: some View {
		Form {
			if let actual {
				Section("Metal Allocations") {
					StatusBytes(label: "Allocated", value: actual.allocatedBytes)
					StatusBytes(label: "Current", value: actual.currentBytes)
					StatusBytes(label: "Peak", value: actual.peakBytes)
				}
			}
			if let governor {
				Section("Governor") {
					StatusBytes(label: "Limit", value: governor.limitBytes)
					StatusBytes(label: "Charged", value: governor.chargedBytes)
					StatusBytes(label: "Headroom", value: governor.headroomBytes)
					StatusBool(label: "Growth Allowed", value: governor.growthAllowed)
					StatusNumber(label: "Denied Reservations", value: governor.deniedReservations)
					StatusText(label: "System Pressure", value: governor.systemPressure)
					StatusBool(label: "Host Measurement Valid", value: governor.hostMeasurementValid)
					StatusBytes(label: "Host Available", value: governor.hostAvailableBytes)
					StatusBytes(label: "Host Reserve", value: governor.hostReserveBytes)
					StatusBytes(label: "Host Spare", value: governor.hostSpareBytes)
					StatusBytes(label: "Host Spare Reserve", value: governor.hostSpareReserveBytes)
					StatusBytes(label: "Host Headroom", value: governor.hostHeadroomBytes)
				}
			}
			if let device = plan?.device {
				Section("Device") {
					StatusText(label: "Name", value: device.deviceName)
					StatusText(label: "macOS", value: device.macosVersion)
					StatusNumber(label: "GPU Family", value: device.appleGpuFamily)
					StatusNumber(label: "GPU Cores", value: device.gpuCoreCount)
					StatusBytes(label: "Physical Memory", value: device.physicalMemoryBytes)
					StatusBytes(label: "Recommended Working Set", value: device.recommendedMaxWorkingSetBytes)
					StatusBytes(label: "Max Buffer Length", value: device.maxBufferLengthBytes)
					StatusBytes(label: "Max Threadgroup Memory", value: device.maxThreadgroupMemoryBytes)
					StatusNumber(label: "Max Threadgroup Width", value: device.maxThreadgroupWidth)
					StatusBool(label: "Unified Memory", value: device.hasUnifiedMemory)
				}
			}
			if let model = plan?.model {
				Section("Model") {
					StatusText(label: "Name", value: model.modelName)
					StatusNumber(label: "Context Limit", value: model.maximumContextTokens)
					StatusNumber(label: "Attention Layers", value: model.attentionLayers)
					StatusNumber(label: "KV Heads", value: model.kvHeads)
					StatusNumber(label: "Head Dimension", value: model.headDimension)
					StatusNumber(label: "KV Page Tokens", value: model.kvPageTokens)
					StatusText(label: "KV Format", value: model.kvFormat)
					StatusNumber(label: "KV Elements per Scale", value: model.kvElementsPerScale)
					StatusBytes(label: "KV Page Bytes", value: model.kvPageBytes)
					StatusText(label: "State Format", value: model.stateFormat)
					if let memory = model.memory {
						Section("Model Memory Plan") {
							StatusBytes(label: "Target Weights", value: memory.targetWeightsBytes)
							StatusBytes(label: "Draft Weights", value: memory.draftWeightsBytes)
							StatusBytes(label: "Vision Weights", value: memory.visionWeightsBytes)
							StatusBytes(label: "Lane State", value: memory.laneStateBytes)
							StatusBytes(label: "Shared Prefill", value: memory.sharedPrefillBytes)
							StatusBytes(label: "Shared Decode", value: memory.sharedDecodeBytes)
							StatusBytes(label: "Pipeline Reserve", value: memory.pipelineReserveBytes)
							StatusBytes(label: "Runtime Overhead", value: memory.runtimeOverheadReserveBytes)
							StatusBytes(label: "Streamed Table", value: memory.streamedTableBytes)
							StatusBytes(label: "ANE FFN", value: memory.aneFfnBytes)
							StatusBytes(label: "State Staging", value: memory.stateStagingBytes)
						}
					}
				}
			}
			if let budget = plan?.budget {
				Section("Budget") {
					StatusBytes(label: "Physical Memory", value: budget.physicalMemoryBytes)
					StatusBytes(label: "Hard Budget", value: budget.hardBudgetBytes)
					StatusBytes(label: "Configured Limit", value: budget.configuredMemoryLimitBytes)
					StatusBytes(label: "Working Set Margin", value: budget.workingSetMarginBytes)
					StatusBytes(label: "Target Weights", value: budget.targetWeightsBytes)
					StatusBytes(label: "Draft Weights", value: budget.draftWeightsBytes)
					StatusBytes(label: "Vision Weights", value: budget.visionWeightsBytes)
					StatusNumber(label: "Max Batch Width", value: budget.maximumBatchWidth)
					StatusBytes(label: "Lane State", value: budget.laneStateBytes)
					StatusBytes(label: "Shared Prefill", value: budget.sharedPrefillBytes)
					StatusBytes(label: "Shared Decode", value: budget.sharedDecodeBytes)
					StatusBytes(label: "Pipeline Reserve", value: budget.pipelineReserveBytes)
					StatusBytes(label: "Runtime Overhead", value: budget.runtimeOverheadReserveBytes)
					StatusBytes(label: "Streamed Table", value: budget.streamedTableBytes)
					StatusBytes(label: "ANE FFN", value: budget.aneFfnBytes)
					StatusBytes(label: "State Staging", value: budget.stateStagingBytes)
					StatusBytes(label: "Fixed Runtime", value: budget.fixedRuntimeBytes)
					StatusBytes(label: "Dynamic Budget", value: budget.dynamicBudgetBytes)
					StatusNumber(label: "KV Extent Pages", value: budget.kvExtentPages)
					StatusBytes(label: "KV Extent Bytes", value: budget.kvExtentBytes)
					StatusNumber(label: "KV Capacity Pages", value: budget.kvCapacityPages)
					StatusBytes(label: "KV Capacity Bytes", value: budget.kvCapacityBytes)
					StatusNumber(label: "KV Capacity Tokens", value: budget.kvCapacityTokens)
					StatusBytes(label: "KV Index Page", value: budget.kvIndexPageBytes)
					if let bounds = budget.contextBounds {
						Section("Context Bounds") {
							StatusNumber(label: "Window", value: bounds.window)
							StatusNumber(label: "Resident", value: bounds.resident)
							StatusNumber(label: "Spilled", value: bounds.spilled)
							StatusNumber(label: "Disk", value: bounds.disk)
							StatusText(label: "Bound By", value: bounds.bound)
						}
					}
					StatusBytes(label: "Minimum Dynamic", value: budget.minimumDynamicBytes)
					StatusBytes(label: "Minimum Required", value: budget.minimumRequiredBytes)
					StatusBytes(label: "Deficit", value: budget.deficitBytes)
				}
			}
			if let audit {
				Section("Audit") {
					StatusText(label: "Scope", value: audit.scope)
					StatusBool(label: "Valid", value: audit.valid)
					StatusText(label: "Error", value: audit.error)
					StatusBytes(label: "Categorized", value: audit.categorizedBytes)
					StatusBytes(label: "Backend Unclassified", value: audit.backendUnclassifiedBytes)
					StatusBytes(label: "Device Untracked", value: audit.deviceUntrackedBytes)
					StatusNumber(label: "Peak Deviation (bp)", value: audit.devicePeakDeviationBasisPoints)
					StatusBytes(label: "Actual Headroom", value: audit.actualHeadroomBytes)
					StatusBytes(label: "Backend Allocated", value: audit.backendAllocatedBytes)
					StatusBytes(label: "Device Current", value: audit.deviceCurrentAllocatedBytes)
					StatusBytes(label: "Device Peak", value: audit.devicePeakAllocatedBytes)
					StatusBytes(label: "Backend Peak", value: audit.backendPeakAllocatedBytes)
				}
			}
			if actual == nil && governor == nil && plan == nil && audit == nil {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Memory")
	}
}

// MARK: - Detail: Scheduler

private struct SchedulerDetail: View {
	let scheduler: SchedulerMetrics?
	let requests: RequestMetrics?
	let activeRequests: [ActiveRequest]?

	var body: some View {
		Form {
			if let scheduler {
				Section("Scheduler") {
					StatusNumber(label: "Queued", value: scheduler.queued)
					StatusNumber(label: "Waiting Resources", value: scheduler.waitingResources)
					StatusNumber(label: "Waiting Prefix", value: scheduler.waitingPrefix)
					StatusNumber(label: "Prefilling", value: scheduler.prefilling)
					StatusNumber(label: "Decoding", value: scheduler.decoding)
					StatusNumber(label: "Waiting Mask", value: scheduler.waitingMask)
					StatusNumber(label: "Terminal", value: scheduler.terminal)
					StatusNumber(label: "Prefill Batches", value: scheduler.prefillBatches)
					StatusNumber(label: "Prefill Rows", value: scheduler.prefillRows)
					StatusNumber(label: "Decode Batches", value: scheduler.decodeBatches)
					if let byWidth = scheduler.decodeBatchesByWidth {
						ForEach(byWidth.sorted(by: { $0.key < $1.key }), id: \.key) { width, count in
							LabeledContent("Width \(width.dropFirst())") {
								Text("\(count)").monospacedDigit()
							}
						}
					}
				}
			}
			if let requests {
				Section("Requests Since Start") {
					StatusNumber(label: "Submitted", value: requests.submitted)
					StatusNumber(label: "Completed", value: requests.completed)
					StatusNumber(label: "Cancelled", value: requests.cancelled)
					StatusNumber(label: "Failed", value: requests.failed)
				}
			}
			if let activeRequests, !activeRequests.isEmpty {
				Section("Active Requests") {
					ForEach(activeRequests, id: \.id) { request in
						NavigationLink {
							RequestDetail(request: request)
						} label: {
							HStack {
								Text(requestLabel(request))
								Spacer()
								if let age = request.ageMs {
									Text(age.formatted(.number.precision(.fractionLength(0))) + " ms")
										.font(.system(size: 11))
										.foregroundColor(.secondary)
										.monospacedDigit()
								}
							}
						}
					}
				}
			}
			if scheduler == nil && requests == nil && (activeRequests?.isEmpty ?? true) {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Scheduler")
	}

	private func requestLabel(_ request: ActiveRequest) -> String {
		var text = "#" + String(request.id ?? 0)
		if let phase = request.phase {
			text += " · " + phase
		}
		if let generated = request.generatedTokens, let maxNew = request.maxNewTokens {
			text += " · \(generated)/\(maxNew) tok"
		}
		return text
	}
}

private struct RequestDetail: View {
	let request: ActiveRequest

	var body: some View {
		Form {
			Section("Request") {
				StatusNumber(label: "ID", value: request.id)
				StatusText(label: "Phase", value: request.phase)
				StatusText(label: "Priority", value: request.priority)
				StatusNumber(label: "Prompt Tokens", value: request.promptTokens)
				StatusNumber(label: "Prompt Processed", value: request.promptProcessed)
				StatusNumber(label: "Generated Tokens", value: request.generatedTokens)
				StatusNumber(label: "Max New Tokens", value: request.maxNewTokens)
				StatusText(label: "KV Mode", value: request.kvMode)
				StatusMs(label: "Age", value: request.ageMs)
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Request")
	}
}

// MARK: - Detail: Performance

private struct MetricsDetail: View {
	let metrics: PerformanceMetrics?
	let modelTiming: ModelTiming?

	var body: some View {
		Form {
			if let metrics {
				Section("Throughput") {
					StatusNumber(label: "Prefill Input Tokens", value: metrics.prefillInputTokens)
					StatusMs(label: "Prefill Wall", value: metrics.prefillWallMs)
					StatusSpeed(label: "Prefill", value: metrics.prefillTokensPerSecond)
					StatusNumber(label: "Decode Output Tokens", value: metrics.decodeOutputTokens)
					StatusMs(label: "Decode Wall", value: metrics.decodeWallMs)
					StatusMs(label: "Decode Cycle", value: metrics.decodeCycleMs)
					StatusSpeed(label: "Decode", value: metrics.decodeTokensPerSecond)
				}
				Section("Latency") {
					if let ttft = metrics.ttftMs {
						percentileRow("TTFT", ttft)
					}
					if let itl = metrics.itlMs {
						percentileRow("ITL", itl)
					}
				}
				Section("Speculative Decoding") {
					StatusNumber(label: "Drafted Tokens", value: metrics.draftedTokens)
					StatusNumber(label: "Accepted Drafts", value: metrics.acceptedDraftTokens)
					StatusPercent(label: "Draft Acceptance", value: metrics.draftAcceptanceRate)
				}
				Section("Failures") {
					StatusNumber(label: "Capacity Failures", value: metrics.capacityFailures)
					StatusNumber(label: "Metal Failures", value: metrics.metalFailures)
				}
				if let prefill = metrics.currentPrefillBatch {
					batchSection("Current Prefill Batch", prefill)
				}
				if let decode = metrics.currentDecodeBatch {
					batchSection("Current Decode Batch", decode)
				}
			}
			if let modelTiming {
				Section("Model Timing (\(modelTiming.scope ?? "model_lifetime"))") {
					if let prefill = modelTiming.prefill {
						phaseTimingRow("Prefill", prefill)
					}
					if let decode = modelTiming.decode {
						phaseTimingRow("Decode", decode)
					}
				}
			}
			if metrics == nil && modelTiming == nil {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Performance")
	}

	@ViewBuilder
	private func percentileRow(_ name: String, _ metric: PercentileMetric) -> some View {
		LabeledContent("\(name) p50") {
			Text(metric.p50.map { $0.formatted(.number.precision(.fractionLength(1))) + " ms" } ?? "—")
				.monospacedDigit()
		}
		LabeledContent("\(name) p95") {
			Text(metric.p95.map { $0.formatted(.number.precision(.fractionLength(1))) + " ms" } ?? "—")
				.monospacedDigit()
		}
		StatusNumber(label: "\(name) Samples", value: metric.samples)
	}

	@ViewBuilder
	private func batchSection(_ title: String, _ batch: BatchMetrics) -> some View {
		Section(title) {
			StatusBool(label: "Valid", value: batch.valid)
			StatusNumber(label: "Width", value: batch.width)
			StatusNumber(label: "Input Tokens", value: batch.inputTokens)
			StatusNumber(label: "Output Tokens", value: batch.outputTokens)
			StatusNumber(label: "Drafted Tokens", value: batch.draftedTokens)
			StatusNumber(label: "Accepted Drafts", value: batch.acceptedDraftTokens)
			StatusMs(label: "Wall", value: batch.wallMs)
			StatusSpeed(label: "Speed", value: batch.tokensPerSecond)
		}
	}

	@ViewBuilder
	private func phaseTimingRow(_ name: String, _ timing: PhaseTiming) -> some View {
		StatusMs(label: "\(name) Last GPU", value: timing.lastGpuMs)
		StatusMs(label: "\(name) Last Wall", value: timing.lastWallMs)
		StatusMs(label: "\(name) Total GPU", value: timing.totalGpuMs)
		StatusMs(label: "\(name) Total Wall", value: timing.totalWallMs)
	}
}

// MARK: - Detail: Cache

private struct CacheDetail: View {
	let cache: CacheMetrics?
	let draftContext: DraftContext?

	var body: some View {
		Form {
			if let cache {
				Section("Prefix Cache") {
					StatusNumber(label: "Probe Hashed Blocks", value: cache.probeHashedBlocks)
					StatusNumber(label: "Hits", value: cache.hits)
					StatusNumber(label: "Cold Misses", value: cache.coldMisses)
					StatusPercent(label: "Hit Rate", value: cache.hitRate)
					StatusNumber(label: "KV Hit Tokens", value: cache.kvHitTokens)
					StatusNumber(label: "KV Disk Hit Tokens", value: cache.kvDiskHitTokens)
					StatusNumber(label: "Lost State Misses", value: cache.lostStateMisses)
					StatusNumber(label: "Reused Tokens", value: cache.reusedTokens)
					StatusNumber(label: "Deduplicated KV Tokens", value: cache.deduplicatedKvTokens)
				}
				Section("State Publications") {
					StatusNumber(label: "Replay", value: cache.replayStatePublications)
					StatusNumber(label: "Deduplicated", value: cache.deduplicatedStatePublications)
					StatusNumber(label: "Recycled", value: cache.recycledStatePublications)
					StatusNumber(label: "From Disk", value: cache.diskStatePublications)
					StatusNumber(label: "Captures", value: cache.stateCaptures)
					StatusNumber(label: "Capture Cuts", value: cache.captureCuts)
					StatusNumber(label: "Replay Failures", value: cache.replayStatePublicationFailures)
					StatusNumber(label: "Lazy Junctions", value: cache.lazyJunctions)
					StatusNumber(label: "Junction Materializations", value: cache.junctionMaterializations)
					StatusNumber(label: "Junction Failures", value: cache.junctionMaterializationFailures)
					StatusNumber(label: "Checkpoint Publications", value: cache.checkpointPublications)
					StatusNumber(label: "Checkpoint Failures", value: cache.checkpointPublicationFailures)
					StatusNumber(label: "Resource Suspensions", value: cache.resourceSuspensions)
					StatusNumber(label: "Priority Suspensions", value: cache.prioritySuspensions)
					StatusNumber(label: "Resource Resumptions", value: cache.resourceResumptions)
					StatusNumber(label: "Resource Replay Tokens", value: cache.resourceReplayTokens)
				}
			}
			if let draftContext {
				Section("Draft Context") {
					StatusNumber(label: "Target Prefill Rows", value: draftContext.targetPrefillRows)
					StatusNumber(label: "Prompt End Rows", value: draftContext.promptEndRows)
					StatusNumber(label: "Materialization Rows", value: draftContext.materializationRows)
					StatusNumber(label: "Avoided Rows", value: draftContext.avoidedRows)
					StatusNumber(label: "Restore Skipped", value: draftContext.restoreSkipped)
					StatusNumber(label: "Resets", value: draftContext.resets)
				}
			}
			if cache == nil && draftContext == nil {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Cache")
	}
}

// MARK: - Detail: KV & Disk

private struct KVDetail: View {
	let kv: KVStatus?
	let state: StateStatus?
	let disk: DiskStatus?
	let kvSpill: KvSpillStatus?

	var body: some View {
		Form {
			if let kv {
				Section("KV Pages") {
					StatusNumber(label: "Block Tokens", value: kv.blockTokens)
					StatusNumber(label: "Allocated", value: kv.pagesAllocated)
					StatusNumber(label: "Active", value: kv.pagesActive)
					StatusNumber(label: "Cache", value: kv.pagesCache)
					StatusNumber(label: "Free", value: kv.pagesFree)
					StatusBytes(label: "Allocated Bytes", value: kv.allocatedBytes)
					StatusBytes(label: "Reclaimable", value: kv.reclaimableBytes)
				}
				Section("Extents") {
					StatusNumber(label: "Allocations", value: kv.extentAllocations)
					StatusNumber(label: "Releases", value: kv.extentReleases)
					StatusMs(label: "Allocate Max", value: kv.extentAllocateMaxMs)
					StatusMs(label: "Release Max", value: kv.extentReleaseMaxMs)
					StatusNumber(label: "Compactions", value: kv.extentCompactions)
					StatusNumber(label: "Pages Moved", value: kv.pagesMoved)
					StatusMs(label: "Compact Max", value: kv.extentCompactMaxMs)
				}
				if let window = kv.window {
					Section("Sliding Window") {
						StatusNumber(label: "Window Pages", value: window.windowPages)
						StatusBool(label: "Trim", value: window.trim)
						StatusNumber(label: "Full Pages", value: window.fullPages)
						StatusNumber(label: "Slim Pages", value: window.slimPages)
						StatusBytes(label: "Slim Bytes", value: window.slimBytes)
						StatusNumber(label: "Pinned Blocks", value: window.pinnedBlocks)
						StatusNumber(label: "Trimmed Pages", value: window.trimmedPages)
						StatusNumber(label: "Upgrades", value: window.upgrades)
						StatusNumber(label: "Refused States", value: window.refusedStates)
					}
				}
			}
			if let state {
				Section("State Cache") {
					StatusNumber(label: "Entries", value: state.entries)
					StatusNumber(label: "Pinned", value: state.pinned)
					StatusNumber(label: "In Use", value: state.inUse)
					StatusNumber(label: "In-Use Evictions", value: state.inUseEvictions)
					StatusBytes(label: "Bytes", value: state.bytes)
					StatusBytes(label: "Allocated", value: state.allocatedBytes)
					StatusNumber(label: "Active Lanes", value: state.activeLanes)
					StatusNumber(label: "Idle GDN Cells", value: state.idleGdnCells)
					StatusNumber(label: "Idle Draft Rings", value: state.idleDraftRings)
					StatusNumber(label: "Idle Context Windows", value: state.idleContextWindows)
					StatusNumber(label: "Publications", value: state.publications)
					StatusNumber(label: "Evictions", value: state.evictions)
					StatusNumber(label: "Checkpoint Entries", value: state.checkpointEntries)
					StatusBytes(label: "Checkpoint Bytes", value: state.checkpointBytes)
					StatusNumber(label: "Checkpoint Evictions", value: state.checkpointEvictions)
					StatusNumber(label: "Checkpoint Retirements", value: state.checkpointRetirements)
					StatusNumber(label: "Disk Hits", value: state.diskHits)
					StatusNumber(label: "Disk Promotions", value: state.diskPromotions)
					StatusNumber(label: "Promotions Skipped", value: state.diskPromotionsSkipped)
					StatusBytes(label: "Disk Bytes", value: state.diskBytes)
					StatusNumber(label: "Offloads", value: state.offloads)
					StatusNumber(label: "Offload Failures", value: state.offloadFailures)
					StatusNumber(label: "Invalidations", value: state.invalidations)
				}
			}
			if let disk {
				Section("SSD Tier") {
					StatusBytes(label: "Capacity", value: disk.capacityBytes)
					StatusBytes(label: "Limit", value: disk.limitBytes)
					StatusBytes(label: "Used", value: disk.usedBytes)
					StatusBytes(label: "File", value: disk.fileBytes)
					StatusBytes(label: "Volume Available", value: disk.volumeAvailableBytes)
					StatusText(label: "Writes Gated", value: disk.writesGated)
					StatusBytes(label: "Write Budget", value: disk.writeBudgetBytes)
					StatusMs(label: "Writes Deferred", value: disk.writesDeferredMs)
					StatusBytes(label: "Read", value: disk.readBytes)
					StatusBytes(label: "Written", value: disk.writtenBytes)
					StatusNumber(label: "KV Blocks", value: disk.kvBlocks)
					StatusBytes(label: "KV Bytes", value: disk.kvBytes)
					StatusNumber(label: "KV Demotions", value: disk.kvDemotions)
					StatusNumber(label: "Demotion Failures", value: disk.kvDemotionFailures)
					StatusNumber(label: "Demotions Refused", value: disk.kvDemotionsRefused)
					StatusNumber(label: "KV Restores", value: disk.kvRestores)
					StatusNumber(label: "Restore Failures", value: disk.kvRestoreFailures)
					StatusNumber(label: "Pending Pages", value: disk.kvPendingPages)
					StatusBool(label: "Persistent", value: disk.persistent)
					StatusNumber(label: "KV Copies", value: disk.kvCopies)
					StatusNumber(label: "Copy Failures", value: disk.kvCopyFailures)
					if let takenBack = disk.takenBack {
						Section("Adopted From Disk") {
							StatusNumber(label: "States", value: takenBack.states)
							StatusNumber(label: "KV Blocks", value: takenBack.kvBlocks)
							StatusBytes(label: "Bytes", value: takenBack.bytes)
							StatusNumber(label: "Left Behind", value: takenBack.leftBehind)
						}
					}
					if let writeBehind = disk.writeBehind {
						Section("Write Behind") {
							StatusNumber(label: "Waiting", value: writeBehind.waiting)
							StatusNumber(label: "Durable", value: writeBehind.durable)
							StatusNumber(label: "Unneeded", value: writeBehind.unneeded)
							StatusNumber(label: "Refused", value: writeBehind.refused)
						}
					}
				}
			}
			if let kvSpill {
				Section("KV Spill") {
					StatusNumber(label: "Spill Requests", value: kvSpill.requests?.spill)
					StatusNumber(label: "Resident Requests", value: kvSpill.requests?.resident)
					StatusNumber(label: "Converted", value: kvSpill.requests?.converted)
					StatusBytes(label: "Spilled Pages", value: kvSpill.pages?.spilledBytes)
					NavigationLink("Spill Details") {
						KvSpillDetail(kvSpill: kvSpill)
					}
				}
			}
			if kv == nil && state == nil && disk == nil {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("KV & Disk")
	}
}

private struct KvSpillDetail: View {
	let kvSpill: KvSpillStatus

	var body: some View {
		Form {
			if let requests = kvSpill.requests {
				Section("Requests") {
					StatusNumber(label: "Spill", value: requests.spill)
					StatusNumber(label: "Resident", value: requests.resident)
					StatusNumber(label: "Converted", value: requests.converted)
					StatusNumber(label: "Bounded", value: requests.bounded)
					StatusNumber(label: "Length Ends", value: requests.lengthEnds)
					StatusNumber(label: "Refused (Quota)", value: requests.refused?.quota)
					StatusNumber(label: "Refused (Write Budget)", value: requests.refused?.writeBudget)
					StatusNumber(label: "Refused (Closed)", value: requests.refused?.closed)
					StatusNumber(label: "Waiting Quota", value: requests.waitingQuota)
				}
			}
			if let pages = kvSpill.pages {
				Section("Pages") {
					StatusNumber(label: "Index", value: pages.index)
					StatusBytes(label: "Index Bytes", value: pages.indexBytes)
					StatusNumber(label: "Spilled", value: pages.spilled)
					StatusBytes(label: "Spilled Bytes", value: pages.spilledBytes)
				}
			}
			if let writeThrough = kvSpill.writeThrough {
				Section("Write Through") {
					StatusNumber(label: "Pages", value: writeThrough.pages)
					StatusBytes(label: "Bytes", value: writeThrough.bytes)
					StatusNumber(label: "In Flight", value: writeThrough.inFlight)
					StatusNumber(label: "Failures", value: writeThrough.failures)
					StatusBool(label: "Paused", value: writeThrough.paused)
				}
			}
			Section("Moves & Restores") {
				StatusNumber(label: "Spill Moves", value: kvSpill.spillMoves)
				StatusNumber(label: "Unspills", value: kvSpill.unspills)
				StatusNumber(label: "Rewrites", value: kvSpill.rewrites)
				StatusNumber(label: "Index Restores", value: kvSpill.restores?.indexPages)
				StatusNumber(label: "Whole Restores", value: kvSpill.restores?.wholePages)
				latencyStatsRow("Restore", kvSpill.restores?.ms)
			}
			if let quota = kvSpill.quota {
				Section("Quota") {
					StatusBytes(label: "Active Limit", value: quota.activeLimitBytes)
					StatusBytes(label: "Held", value: quota.heldBytes)
					StatusBytes(label: "Committed", value: quota.committedBytes)
					StatusNumber(label: "Revoked", value: quota.revoked)
				}
			}
			StatusBytes(label: "Index Runway", value: kvSpill.indexRunwayBytes)
			if let blockCache = kvSpill.blockCache {
				Section("Block Cache") {
					StatusBytes(label: "Bytes", value: blockCache.bytes)
					StatusBytes(label: "Target", value: blockCache.targetBytes)
					StatusBytes(label: "Floor", value: blockCache.floorBytes)
					StatusNumber(label: "Slots per Layer", value: blockCache.slotsPerLayer)
					StatusNumber(label: "Lanes", value: blockCache.lanes)
					StatusNumber(label: "Resolves", value: blockCache.resolves)
					StatusNumber(label: "Entries", value: blockCache.entries)
					StatusNumber(label: "Paged", value: blockCache.paged)
					StatusNumber(label: "Hits", value: blockCache.hits)
					StatusNumber(label: "Read", value: blockCache.read)
					StatusPercent(label: "Hit Rate", value: blockCache.hitRate)
					StatusNumber(label: "Ghost Hits", value: blockCache.ghostHits)
					StatusBytes(label: "Read Bytes", value: blockCache.readBytes)
					StatusNumber(label: "Read Failures", value: blockCache.readFailures)
					latencyStatsRow("Resolve", blockCache.resolveMs)
					latencyStatsRow("Read", blockCache.readMs)
					hostStepsRow("Host Steps", blockCache.hostSteps)
				}
			}
			if let stream = kvSpill.historyStream {
				Section("History Stream") {
					StatusNumber(label: "Commands", value: stream.commands)
					StatusNumber(label: "Contended Commands", value: stream.contendedCommands)
					StatusNumber(label: "Layers", value: stream.layers)
					StatusNumber(label: "Pages", value: stream.pages)
					StatusBytes(label: "Bytes", value: stream.bytes)
					StatusBytes(label: "Staging", value: stream.stagingBytes)
					StatusNumber(label: "Buffers", value: stream.buffers)
					latencyStatsRow("Read", stream.readMs)
					latencyStatsRow("Wait", stream.waitMs)
					latencyStatsRow("Decode Gap", stream.decodeGapMs)
				}
			}
		}
		.formStyle(.grouped)
		.navigationTitle("KV Spill")
	}
}

// MARK: - Detail: ANE & Weights

private struct ANEDetail: View {
	let aneFfn: AneFfnMetrics?
	let weights: WeightsStatus?

	var body: some View {
		Form {
			if let aneFfn {
				Section("ANE FFN Split") {
					StatusText(label: "State", value: aneFfn.state)
					StatusPercent(label: "Share", value: aneFfn.share)
					StatusNumber(label: "Minimum Rows", value: aneFfn.minimumRows)
					if let reason = aneFfn.reason {
						LabeledContent("Reason") {
							Text(reason)
						}
					}
					StatusNumber(label: "Split Commands", value: aneFfn.splitCommands)
					StatusNumber(label: "Evaluations", value: aneFfn.evaluations)
					StatusMs(label: "ANE Time", value: aneFfn.aneMs)
					StatusNumber(label: "Reruns", value: aneFfn.reruns)
				}
			}
			if let weights {
				Section("Weights") {
					StatusDouble(label: "Idle Release (s)", value: weights.idleReleaseSeconds)
					StatusBool(label: "Released", value: weights.released)
					StatusBool(label: "Restoring", value: weights.restoring)
					StatusNumber(label: "Restores", value: weights.restores)
					StatusNumber(label: "Restore Failures", value: weights.restoreFailures)
				}
			}
			if aneFfn == nil && weights == nil {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Neural Engine & Weights")
	}
}

// MARK: - Detail: Engine Health

private struct EngineDetail: View {
	let transport: TransportStatus?
	let metal: MetalHealth?
	let loop: LoopStatus?
	let admission: AdmissionStatus?
	let warmup: WarmupStatus?
	let identity: IdentityStatus?

	var body: some View {
		Form {
			if let transport {
				Section("Transport") {
					StatusBool(label: "Ready", value: transport.ready)
					StatusBool(label: "Recovering", value: transport.recovering)
					StatusBool(label: "Stopped", value: transport.stopped)
					StatusNumber(label: "Pending", value: transport.pending)
					StatusNumber(label: "Pending Limit", value: transport.pendingLimit)
					StatusNumber(label: "Restarts", value: transport.restarts)
					StatusText(label: "Last Crash Trace", value: transport.lastCrashTrace)
					StatusBool(label: "Status Stale", value: transport.statusStale)
					StatusMs(label: "Status Age", value: transport.statusAgeMs)
					StatusText(label: "Error", value: transport.error)
				}
			}
			if let metal {
				Section("Metal") {
					StatusBool(label: "Healthy", value: metal.healthy)
					StatusText(label: "Failure Reason", value: metal.failureReason)
				}
			}
			if let loop {
				Section("Native Loop") {
					StatusMs(label: "Max Tick", value: loop.maxTickMs)
				}
			}
			if let admission {
				Section("Admission") {
					StatusNumber(label: "Waiting", value: admission.waiting)
					StatusNumber(label: "Waiting Memory", value: admission.waitingMemory)
					StatusNumber(label: "Waiting Concurrency", value: admission.waitingConcurrency)
					StatusNumber(label: "Held Behind Refusal", value: admission.heldBehindRefusal)
					StatusNumber(label: "Restoring", value: admission.restoring)
					StatusNumber(label: "Suspended", value: admission.suspended)
					StatusBool(label: "Draining", value: admission.draining)
					StatusMs(label: "Oldest Wait", value: admission.oldestWaitMs)
				}
			}
			if let warmup {
				Section("Warmup") {
					StatusBool(label: "Prefill 2048", value: warmup.prefill2048)
					StatusBool(label: "Decode B1", value: warmup.decodeB1)
					StatusBool(label: "Decode B2", value: warmup.decodeB2)
					StatusBool(label: "Decode B3", value: warmup.decodeB3)
					StatusBool(label: "Decode B4", value: warmup.decodeB4)
					StatusBool(label: "Composite State Restore", value: warmup.compositeStateRestore)
					if let limited = warmup.memoryLimitedSteps, !limited.isEmpty {
						LabeledContent("Memory Limited") {
							Text(limited.joined(separator: ", "))
						}
					}
					if let detail = warmup.detail {
						LabeledContent("Detail") {
							Text(detail)
						}
					}
				}
			}
			if let identity {
				if let cache = identity.cache {
					Section("Cache Identity") {
						StatusText(label: "Model Layout SHA-256", value: cache.loadedModelLayoutSha256)
						StatusText(label: "Build ID", value: cache.buildId)
						StatusText(label: "DType", value: cache.dtype)
						StatusNumber(label: "Block Tokens", value: cache.blockTokens)
						if let rope = cache.ropeScaling {
							Section("RoPE Scaling") {
								StatusText(label: "Type", value: rope.type)
								StatusDouble(label: "Factor", value: rope.factor)
								StatusNumber(label: "Original Context", value: rope.originalContextTokens)
							}
						}
					}
				}
				if let kv = identity.kv {
					Section("KV Identity") {
						StatusText(label: "Target Model SHA-256", value: kv.targetModelSha256)
						StatusText(label: "Format", value: kv.format)
						StatusText(label: "Quantization", value: kv.quantization)
						StatusText(label: "Scale Type", value: kv.scaleType)
						StatusText(label: "Key Layout", value: kv.keyLayout)
						StatusText(label: "Value Layout", value: kv.valueLayout)
					}
				}
			}
			if transport == nil && metal == nil && loop == nil && admission == nil && warmup == nil && identity == nil {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Engine Health")
	}
}

// MARK: - Detail: Streaming

private struct StreamedDetail: View {
	let table: StreamedTable?
	let experts: StreamedExperts?

	var body: some View {
		Form {
			if let table {
				Section("PLE Table (\(table.table ?? "?"))") {
					StatusBytes(label: "Table Bytes", value: table.tableBytes)
					StatusBytes(label: "Cache Bytes", value: table.cacheBytes)
					StatusNumber(label: "Cache Capacity Rows", value: table.cacheCapacityRows)
					StatusNumber(label: "Cached Rows", value: table.cachedRows)
					StatusNumber(label: "Evictions", value: table.evictions)
					useRow("Prefill", table.prefill)
					useRow("Decode", table.decode)
					StatusBytes(label: "Read Bytes", value: table.readBytes)
					StatusNumber(label: "Read Retries", value: table.readRetries)
					StatusNumber(label: "Read Errors", value: table.readErrors)
					latencyStatsRow("Read", table.readMs)
					StatusNumber(label: "Prefetch Requested", value: table.prefetchRequestedRows)
					StatusNumber(label: "Prefetch Read", value: table.prefetchReadRows)
					StatusNumber(label: "Prefetch Dropped", value: table.prefetchDroppedRows)
					StatusBool(label: "Poisoned", value: table.poisoned)
					StatusText(label: "Failure", value: table.failure)
				}
			}
			if let experts {
				Section("Expert Store") {
					StatusBytes(label: "Cap", value: experts.capBytes)
					StatusBytes(label: "Floor", value: experts.floorBytes)
					StatusNumber(label: "Chunks", value: experts.chunks)
					StatusNumber(label: "Chunks at Cap", value: experts.capChunks)
					StatusNumber(label: "Shrinks", value: experts.shrinks)
					StatusNumber(label: "Regrows", value: experts.regrows)
					StatusBytes(label: "Arena Bytes", value: experts.arenaBytes)
					StatusBytes(label: "Staging Bytes", value: experts.stagingBytes)
					StatusNumber(label: "Slots", value: experts.slots)
					StatusNumber(label: "Experts", value: experts.experts)
					StatusNumber(label: "Resident", value: experts.resident)
					NavigationLink("Expert Uses") {
						ExpertUsesDetail(prefill: experts.prefill, decode: experts.decode)
					}
					StatusText(label: "Failure", value: experts.failure)
				}
			}
			if table == nil && experts == nil {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Streaming")
	}

	@ViewBuilder
	private func useRow(_ name: String, _ use: StreamedUse?) -> some View {
		if let use {
			Section("\(name) Use") {
				StatusNumber(label: "Stages", value: use.stages)
				StatusNumber(label: "Requested Rows", value: use.requestedRows)
				StatusNumber(label: "Unique Rows", value: use.uniqueRows)
				StatusNumber(label: "Hit Rows", value: use.hitRows)
				StatusNumber(label: "Read Rows", value: use.readRows)
				StatusPercent(label: "Hit Rate", value: use.hitRate)
				latencyStatsRow("Stage", use.stageMs)
			}
		}
	}
}

private struct ExpertUsesDetail: View {
	let prefill: ExpertUse?
	let decode: ExpertUse?

	var body: some View {
		Form {
			useSection("Prefill", prefill)
			useSection("Decode", decode)
		}
		.formStyle(.grouped)
		.navigationTitle("Expert Uses")
	}

	@ViewBuilder
	private func useSection(_ name: String, _ use: ExpertUse?) -> some View {
		if let use {
			Section("\(name) Use") {
				StatusNumber(label: "Loads", value: use.loads)
				StatusNumber(label: "Routed", value: use.routed)
				StatusNumber(label: "Read", value: use.read)
				StatusNumber(label: "Prefetched", value: use.prefetched)
				StatusNumber(label: "Read Ahead", value: use.readAhead)
				StatusPercent(label: "Hit Rate", value: use.hitRate)
				StatusBytes(label: "Read Bytes", value: use.readBytes)
				hostStepsRow("Host Steps", use.hostSteps)
			}
		}
	}
}

// MARK: - Detail: Process

private struct ProcessDetail: View {
	let http: HTTPStatus?
	let frontend: FrontendStatus?
	let grammarCache: GrammarCache?
	let responseStore: ResponseStore?
	let imageCache: ImageCacheStats?
	let tokenizerCache: TokenizerCache?

	var body: some View {
		Form {
			if let http {
				Section("HTTP") {
					counterRow("Requests", http.requests)
					counterRow("Request Body Bytes", http.requestBodyBytes)
					StatusBytes(label: "Max Request Bytes", value: http.maxRequestBytes)
					counterRow("Token Counts", http.tokenCounts)
					counterRow("Connections", http.connections)
				}
			}
			if let frontend {
				Section("Frontend") {
					StatusNumber(label: "Preparation Capacity", value: frontend.preparationCapacity)
					StatusNumber(label: "Active", value: frontend.active)
					StatusNumber(label: "Waiting", value: frontend.waiting)
				}
			}
			if let grammarCache {
				Section("Grammar Cache") {
					StatusNumber(label: "Entries", value: grammarCache.entries)
					StatusNumber(label: "Capacity", value: grammarCache.capacity)
					StatusBytes(label: "Source Bytes", value: grammarCache.sourceBytes)
					StatusBytes(label: "Source Budget", value: grammarCache.sourceBudgetBytes)
					StatusNumber(label: "Hits", value: grammarCache.hits)
					StatusNumber(label: "Misses", value: grammarCache.misses)
				}
			}
			if let responseStore {
				Section("Response Store") {
					StatusNumber(label: "Entries", value: responseStore.entries)
					StatusBytes(label: "Bytes", value: responseStore.bytes)
					StatusBytes(label: "Budget", value: responseStore.budgetBytes)
					StatusNumber(label: "Evictions", value: responseStore.evictions)
					StatusNumber(label: "Hits", value: responseStore.hits)
					StatusNumber(label: "Misses", value: responseStore.misses)
				}
			}
			if let imageCache {
				Section("Image Cache") {
					StatusNumber(label: "Entries", value: imageCache.entries)
					StatusBytes(label: "Bytes", value: imageCache.bytes)
					StatusBytes(label: "Budget", value: imageCache.budgetBytes)
					StatusBytes(label: "Request Bytes", value: imageCache.requestBytes)
					StatusBytes(label: "Request Budget", value: imageCache.requestBudgetBytes)
				}
			}
			if let tokenizerCache {
				Section("Tokenizer Cache") {
					StatusBool(label: "Enabled", value: tokenizerCache.enabled)
					StatusNumber(label: "Entries", value: tokenizerCache.entries)
					StatusBytes(label: "Bytes", value: tokenizerCache.bytes)
					StatusBytes(label: "Budget", value: tokenizerCache.budgetBytes)
					StatusNumber(label: "Capacity", value: tokenizerCache.capacity)
					StatusNumber(label: "Hits", value: tokenizerCache.hits)
					StatusNumber(label: "Reused Tokens", value: tokenizerCache.reusedTokens)
				}
			}
			if http == nil && frontend == nil && grammarCache == nil && responseStore == nil && imageCache == nil && tokenizerCache == nil {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Process")
	}

	@ViewBuilder
	private func counterRow(_ label: String, _ counter: HTTPCounter?) -> some View {
		LabeledContent(label) {
			Text("\(counter?.active ?? 0) / \(counter?.capacity ?? 0)")
				.monospacedDigit()
		}
	}
}

// MARK: - Detail: Latency

private struct LatencyDetail: View {
	let latency: [String: LatencyHistogram]?

	var body: some View {
		Form {
			if let latency, !latency.isEmpty {
				Section("Stages (seconds)") {
					ForEach(latency.keys.sorted(), id: \.self) { stage in
						if let histogram = latency[stage] {
							LabeledContent(stage) {
								Text("\(histogram.count) samples · \(histogram.sum.formatted(.number.precision(.fractionLength(3)))) s total")
									.monospacedDigit()
							}
						}
					}
				}
			} else {
				noData
			}
		}
		.formStyle(.grouped)
		.navigationTitle("Latency")
	}
}

// MARK: - Shared row helpers

/// "No data" placeholder for detail views whose model is absent.
private var noData: some View {
	ContentUnavailableView {
		Label("No Data", systemImage: "tray")
	}
}

/// A `LatencyStats` block (p50/p95/p99/max/total/samples, ms) as one row.
@ViewBuilder
private func latencyStatsRow(_ name: String, _ stats: LatencyStats?) -> some View {
	if let stats {
		LabeledContent("\(name) p50/p95") {
			Text("\(stats.p50.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") / \(stats.p95.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") ms")
				.monospacedDigit()
		}
		LabeledContent("\(name) max") {
			Text(stats.max.map { $0.formatted(.number.precision(.fractionLength(1))) + " ms" } ?? "—")
				.monospacedDigit()
		}
		LabeledContent("\(name) total") {
			Text("\(stats.total.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") ms (\(stats.samples ?? 0) samples)")
				.monospacedDigit()
		}
	}
}

/// The pickup/work/resume host-step round trips as one row.
@ViewBuilder
private func hostStepsRow(_ name: String, _ steps: HostSteps?) -> some View {
	if let steps {
		LabeledContent("\(name) p50") {
			Text("\(steps.pickupMs?.p50.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") / \(steps.workMs?.p50.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") / \(steps.resumeMs?.p50.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—") ms")
				.monospacedDigit()
		}
	}
}

/// A row showing an optional locale-formatted number; an em dash when absent.
private struct StatusNumber<Value: BinaryInteger>: View {
	let label: LocalizedStringKey
	let value: Value?

	var body: some View {
		LabeledContent(label) {
			if let value {
				Text(value.formatted())
					.monospacedDigit()
			} else {
				dash
			}
		}
	}
}

/// A row showing an optional decimal value; an em dash when absent.
private struct StatusDouble: View {
	let label: LocalizedStringKey
	let value: Double?

	var body: some View {
		LabeledContent(label) {
			if let value {
				Text(value.formatted(.number.precision(.fractionLength(0...3))))
					.monospacedDigit()
			} else {
				dash
			}
		}
	}
}

/// A row showing an optional byte count in the locale's memory units.
private struct StatusBytes: View {
	let label: LocalizedStringKey
	let value: Int64?

	var body: some View {
		LabeledContent(label) {
			if let value {
				Text(value.formatted(.byteCount(style: .memory)))
					.monospacedDigit()
			} else {
				dash
			}
		}
	}
}

/// A row showing an optional string; an em dash when absent or empty.
private struct StatusText: View {
	let label: LocalizedStringKey
	let value: String?

	var body: some View {
		LabeledContent(label) {
			if let value, !value.isEmpty {
				Text(value)
			} else {
				dash
			}
		}
	}
}

/// A row showing an optional boolean as Yes/No.
private struct StatusBool: View {
	let label: LocalizedStringKey
	let value: Bool?

	var body: some View {
		LabeledContent(label) {
			switch value {
			case .some(true):
				Text("Yes")
			case .some(false):
				Text("No")
			case nil:
				dash
			}
		}
	}
}

/// A row showing an optional duration in ms.
private struct StatusMs: View {
	let label: LocalizedStringKey
	let value: Double?

	var body: some View {
		LabeledContent(label) {
			if let value {
				Text(value.formatted(.number.precision(.fractionLength(1))) + " ms")
					.monospacedDigit()
			} else {
				dash
			}
		}
	}
}

/// A row showing an optional ratio as a locale-formatted percent.
private struct StatusPercent: View {
	let label: LocalizedStringKey
	let value: Double?

	var body: some View {
		LabeledContent(label) {
			if let value {
				Text(value.formatted(.percent.precision(.fractionLength(1))))
					.monospacedDigit()
			} else {
				dash
			}
		}
	}
}

/// A row showing an optional throughput in tok/s.
private struct StatusSpeed: View {
	let label: LocalizedStringKey
	let value: Double?

	var body: some View {
		LabeledContent(label) {
			if let value {
				Text(value.formatted(.number.precision(.fractionLength(1))) + " tok/s")
					.monospacedDigit()
			} else {
				dash
			}
		}
	}
}

private var dash: some View {
	Text("—")
		.foregroundColor(.secondary)
}
