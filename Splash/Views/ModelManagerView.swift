import SwiftUI
import AppKit

struct ModelManagerView: View {
	enum ModelManagerTab: Hashable, CaseIterable {
		case installed
		case huggingFace
		case install
	}

	@State private var selectedTab: ModelManagerTab = .installed
	@State private var customRepoId: String = ""
	@State private var customModelLanguageOnly: Bool = false
	@State private var searchText: String = ""
	// §3.2: la detección de repositorio restringido se calcula cuando cambia
	// `installSuccess`, no en cada evaluación del cuerpo (antes leía y filtraba
	// todo el log en cada render).
	@State private var isGatedError: Bool = false

	// Model deletion alert state (§6.2: en macOS 27 el optional presenta la
	// alerta por sí solo; el bool solo sostiene el fallback 26.x).
	@State private var showingDeleteAlert: Bool = false
	@State private var modelToDelete: InstalledSplashModel? = nil

	var body: some View {
		Group {
			if #available(macOS 27, *) {
				mainContent
					.alert("Delete Model?", item: $modelToDelete) { model in
						Button("Delete from Splash", role: .destructive) {
							SplashService.shared.deleteModel(repoId: model.repoId)
						}
						Button("Cancel", role: .cancel) {}
					} message: { model in
						Text("Are you sure you want to delete '\(model.shortName)'? It will be unlinked from the Splash engine to free up disk space (\(model.formattedSize)).")
					}
			} else {
				mainContent
					.alert(
						"Delete Model?",
						isPresented: $showingDeleteAlert,
						presenting: modelToDelete
					) { model in
						Button("Delete from Splash", role: .destructive) {
							SplashService.shared.deleteModel(repoId: model.repoId)
						}
						Button("Cancel", role: .cancel) {}
					} message: { model in
						Text("Are you sure you want to delete '\(model.shortName)'? It will be unlinked from the Splash engine to free up disk space (\(model.formattedSize)).")
					}
			}
		}
		.onChange(of: SplashService.shared.installSuccess) { _, success in
			isGatedError = success == false &&
				SplashService.shared.installLogs.contains { $0.text.contains("gated repo") || $0.text.contains("Access to model") || $0.text.contains("403") || $0.text.contains("Gated") }
		}
		// §5.2: alerta de conflicto de puerto compartida (PortConflictAlertModifier).
		.portConflictAlert()
	}

	private var mainContent: some View {
		VStack(spacing: 12) {
			Picker("Model catalog tab", selection: $selectedTab) {
				Text("Installed Models (\(SplashService.shared.installedModels.count))").tag(ModelManagerTab.installed)
				Text("Hugging Face").tag(ModelManagerTab.huggingFace)
				Text("Install").tag(ModelManagerTab.install)
			}
			.pickerStyle(.segmented)
			.labelsHidden()

			// Tab Content
			switch selectedTab {
			case .installed:
				installedModelsList
			case .huggingFace:
				onlineModelsList
			case .install:
				customInstallView
			}

			// §3.2/§3.8: consola de instalación compartida con entradas de valor.
			if SplashService.shared.isInstalling || !SplashService.shared.installLogs.isEmpty {
				InstallConsole(
					isInstalling: SplashService.shared.isInstalling,
					installingModelId: SplashService.shared.installingModelId,
					installSuccess: SplashService.shared.installSuccess,
					logs: SplashService.shared.installLogs,
					downloadPhase: SplashService.shared.downloadPhase,
					downloadSpeedMBs: SplashService.shared.downloadSpeedMBs,
					downloadedBytes: SplashService.shared.downloadedBytes,
					totalExpectedBytes: SplashService.shared.totalExpectedBytes,
					progressFraction: SplashService.shared.downloadProgressFraction,
					isGatedError: isGatedError,
					targetModelId: targetGatedModelId,
					showsGatedBanner: true,
					onCancel: {
						SplashService.shared.cancelModelInstall()
					},
					onClose: {
						SplashService.shared.installLogs.removeAll()
						SplashService.shared.installSuccess = nil
						isGatedError = false
					}
				)
			}
		}
	}

	// MARK: - Installed Models Tab
	private var installedModelsList: some View {
		VStack(spacing: 8) {
			if SplashService.shared.installedModels.isEmpty {
				VStack(spacing: 6) {
					Image(systemName: "shippingbox")
						.font(.system(size: 24))
						.foregroundColor(.secondary)
					Text("No models installed in Splash yet.")
						.font(.system(size: 11))
						.foregroundColor(.secondary)
					Text("Browse the Hugging Face catalog to download your first model.")
						.font(.system(size: 10))
						.foregroundColor(.secondary)
				}
				.frame(maxWidth: .infinity, minHeight: 90)
			} else {
				ScrollView {
					VStack(spacing: 6) {
						ForEach(SplashService.shared.installedModels) { model in
							HStack(spacing: 10) {
								Image(systemName: model.isCurrentlyActive ? "checkmark.circle.fill" : "cube.box")
									.font(.system(size: 15))
									.foregroundColor(model.isCurrentlyActive ? .green : .secondary)

								VStack(alignment: .leading, spacing: 2) {
									HStack {
										Text(model.shortName)
											.font(.system(size: 12, weight: .semibold))
											.lineLimit(1)
										if model.isCurrentlyActive {
											Text("ACTIVE")
												.font(.system(size: 9, weight: .bold))
												.padding(.horizontal, 5)
												.padding(.vertical, 1)
												.background(Color.green.opacity(0.2))
												.foregroundColor(.green)
												.cornerRadius(4)
										}
										if let variant = model.variant {
											Text(variant)
												.font(.system(size: 8, weight: .semibold, design: .monospaced))
												.padding(.horizontal, 4)
												.padding(.vertical, 1)
												.background(Color.blue.opacity(0.15))
												.foregroundColor(.blue)
												.cornerRadius(4)
										}
										if model.isCoderFineTune {
											Text("CODER")
												.font(.system(size: 8, weight: .bold))
												.padding(.horizontal, 4)
												.padding(.vertical, 1)
												.background(Color.orange.opacity(0.15))
												.foregroundColor(.orange)
												.cornerRadius(4)
										}
									}

									HStack(spacing: 8) {
										Text(model.repoId)
											.font(.system(size: 10))
											.foregroundColor(.secondary)
										Text(verbatim: "·")
											.foregroundColor(.secondary)
										Text(model.formattedSize)
											.font(.system(size: 10, weight: .medium, design: .monospaced))
											.foregroundColor(.primary)
									}
								}

								Spacer()

								// §10: etiqueta de accesibilidad en los botones de icono.
								Button("Reveal in Finder", systemImage: "folder") {
									SplashService.shared.openModelInFinder(repoId: model.repoId)
								}
								.labelStyle(.iconOnly)
								.font(.system(size: 11))
								.foregroundColor(.secondary)
								.buttonStyle(.borderless)
								.help("Reveal folder in Finder")

								// Delete Model button
								Button("Delete model", systemImage: "trash") {
									modelToDelete = model
									// Solo el fallback 26.x necesita el bool.
									showingDeleteAlert = true
								}
								.labelStyle(.iconOnly)
								.font(.system(size: 11))
								.foregroundColor(.red.opacity(0.8))
								.buttonStyle(.borderless)
								.help("Delete model to free up space")

								if !model.isCurrentlyActive {
									Button {
										SplashService.shared.switchModel(to: model.repoId)
									} label: {
										if SplashService.shared.isStartingServer && SplashService.shared.startingModelId == model.repoId {
											HStack(spacing: 5) {
												ProgressView()
													.controlSize(.mini)
												Text("Switching...")
													.font(.system(size: 10, weight: .semibold))
											}
										} else {
											Label(
												SplashService.shared.isRunning ? LocalizedStringResource("Switch") : LocalizedStringResource("Start"),
												systemImage: SplashService.shared.isRunning ? "arrow.triangle.2.circlepath" : "play.fill"
											)
											.font(.system(size: 10, weight: .semibold))
										}
									}
									.buttonStyle(.borderedProminent)
									.tint(SplashService.shared.isRunning ? .purple : .green)
									.controlSize(.small)
									.disabled(SplashService.shared.isStartingServer)
								}
							}
							.padding(8)
							.background(Color(nsColor: .controlBackgroundColor))
							.cornerRadius(8)
						}
					}
				}
				.frame(maxHeight: 200)
			}
		}
	}

	// MARK: - Online Models Tab
	private var onlineModelsList: some View {
		VStack(spacing: 8) {
			HStack {
				HStack(spacing: 4) {
					Image(systemName: "magnifyingglass")
						.foregroundColor(.secondary)
						.font(.system(size: 11))
					TextField("Search models...", text: $searchText)
						.textFieldStyle(.plain)
						.font(.system(size: 11))
				}
				.padding(5)
				.background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
				.cornerRadius(6)

				// §10: etiqueta de accesibilidad en el botón de icono.
				Button("Refresh catalog", systemImage: "arrow.clockwise") {
					Task {
						await SplashService.shared.fetchOnlineModels()
					}
				}
				.labelStyle(.iconOnly)
				.font(.system(size: 11))
				.buttonStyle(.borderless)
				.disabled(SplashService.shared.isLoadingOnlineModels)
				.help("Refresh Hugging Face catalog")
			}

			if SplashService.shared.isLoadingOnlineModels {
				HStack {
					ProgressView()
						.scaleEffect(0.7)
					Text("Loading Hugging Face catalog...")
						.font(.system(size: 11))
						.foregroundColor(.secondary)
				}
				.frame(maxWidth: .infinity, minHeight: 90)
			} else {
				let filtered = SplashService.shared.availableOnlineModels.filter {
					searchText.isEmpty || $0.id.localizedCaseInsensitiveContains(searchText)
				}
				// §3.2: un solo set por render en vez de `installedModels.contains`
				// dentro de cada fila.
				let installedRepoIDs = Set(SplashService.shared.installedModels.map(\.repoId))

				ScrollView {
					VStack(spacing: 6) {
						ForEach(filtered) { item in
							OnlineModelRow(
								item: item,
								isInstalled: installedRepoIDs.contains(item.id),
								isInstalling: SplashService.shared.isInstalling
							)
						}
					}
				}
				.frame(maxHeight: 200)
			}
		}
	}

	// MARK: - Custom Install Tab
	private var customInstallView: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Install model from Hugging Face")
				.font(.system(size: 12, weight: .semibold))

			Text("Enter the Hugging Face repository (e.g. mlx-community/Qwen3.8-27B-4bit) or GGUF fine-tune with variant (e.g. peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL).")
				.font(.system(size: 10))
				.foregroundColor(.secondary)

			HStack {
				TextField("owner/repo[:variant] (e.g. mlx-community/Qwen3.8-27B-4bit)", text: $customRepoId)
					.textFieldStyle(.roundedBorder)
					.font(.system(size: 11, design: .monospaced))
					.onChange(of: customRepoId) { _, newVal in
						let lower = newVal.lowercased()
						if lower.contains("coder") || lower.contains("code") {
							customModelLanguageOnly = true
						}
					}

				Button {
					let trimmed = customRepoId.trimmingCharacters(in: .whitespacesAndNewlines)
					guard !trimmed.isEmpty else { return }
					SplashService.shared.installModel(repoId: trimmed, languageOnly: customModelLanguageOnly)
				} label: {
					Text("Download")
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.regular)
				.disabled(SplashService.shared.isInstalling || customRepoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
			}

			Toggle(isOn: $customModelLanguageOnly) {
				HStack(spacing: 4) {
					Image(systemName: "doc.text")
						.font(.system(size: 10))
						.foregroundColor(.orange)
					Text("Text/code-only mode (--language-only, required for Coder models without mmproj)")
						.font(.system(size: 10))
				}
			}
			.toggleStyle(.checkbox)

			HStack(spacing: 6) {
				Image(systemName: "info.circle")
					.foregroundColor(.secondary)
					.font(.system(size: 10))
				Text("Weights download directly to the Hugging Face cache and configure with precompiled Metal kernels.")
					.font(.system(size: 9))
					.foregroundColor(.secondary)
			}
		}
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
	}

	/// §3.2: fila del catálogo online con entradas de valor. La acción del
	/// botón llama al servicio directamente (no lee estado por render).
	private struct OnlineModelRow: View {
		let item: HuggingFaceModelItem
		let isInstalled: Bool
		let isInstalling: Bool

		var body: some View {
			HStack(spacing: 10) {
				Image(systemName: item.isOfficial ? "sparkles" : "cube")
					.font(.system(size: 14))
					.foregroundColor(item.isOfficial ? .blue : .purple)

				VStack(alignment: .leading, spacing: 2) {
					HStack {
						Text(item.displayName)
							.font(.system(size: 11, weight: .semibold))
							.lineLimit(1)
						if item.isOfficial {
							Text("OFFICIAL")
								.font(.system(size: 8, weight: .bold))
								.padding(.horizontal, 4)
								.padding(.vertical, 1)
								.background(Color.blue.opacity(0.2))
								.foregroundColor(.blue)
								.cornerRadius(3)
						} else if item.id.hasSuffix("-Splash") {
							Text("DEPRECATED")
								.font(.system(size: 8, weight: .bold))
								.padding(.horizontal, 4)
								.padding(.vertical, 1)
								.background(Color.red.opacity(0.2))
								.foregroundColor(.red)
								.cornerRadius(3)
						}
					}

					Text(item.id)
						.font(.system(size: 9))
						.foregroundColor(.secondary)
				}

				Spacer()

				if isInstalled {
					Text("Installed")
						.font(.system(size: 10, weight: .medium))
						.foregroundColor(.green)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(Color.green.opacity(0.15))
						.cornerRadius(4)
				} else {
					Button {
						SplashService.shared.installModel(repoId: item.id)
					} label: {
						Label("Install", systemImage: "arrow.down.circle")
							.font(.system(size: 10))
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
					.disabled(isInstalling)
				}
			}
			.padding(8)
			.background(Color(nsColor: .controlBackgroundColor))
			.cornerRadius(8)
		}
	}

	private var targetGatedModelId: String? {
		if let current = SplashService.shared.installingModelId, !current.isEmpty {
			return current
		}
		let custom = customRepoId.trimmingCharacters(in: .whitespacesAndNewlines)
		return custom.isEmpty ? nil : custom
	}
}
