import SwiftUI
import AppKit

/// §3.8: línea del registro de instalación con identidad monótona.
///
/// Las dos consolas en vivo (`ModelManagerView` y `DependencyInstallView`) usaban
/// `ForEach(…, id: \.offset)`: tras un «Clear»/`removeAll()` los offsets se
/// reutilizaban y las filas nuevas animaban/scroll sobre filas equivocadas.
/// El id monótono lo emite el servicio; la fila conserva su identidad aunque
/// su texto se reescriba in situ (barra de progreso de descarga).
struct InstallLogLine: Identifiable, Equatable {
	let id: Int
	var text: String
}

/// §3.2/§3.8: consola de instalación compartida por `ModelManagerView`
/// (descarga de modelos) y `DependencyInstallView` (instalación del motor).
///
/// Entradas de valor: el cuerpo de ninguna de las dos pestañas vuelve a correr
/// por cada línea nueva; solo la consola re-evalúa.
struct InstallConsole: View {
	let isInstalling: Bool
	let installingModelId: String?
	let installSuccess: Bool?
	let logs: [InstallLogLine]
	let downloadPhase: String
	let downloadSpeedMBs: Double
	let downloadedBytes: Int64
	let totalExpectedBytes: Int64
	let progressFraction: Double?
	let isGatedError: Bool
	let targetModelId: String?
	/// Solo la descarga de modelos muestra el banner de repositorio restringido.
	var showsGatedBanner: Bool = false
	let onCancel: () -> Void
	let onClose: () -> Void

	@State private var copied: CopiedFlash?

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				if isInstalling {
					ProgressView()
						.scaleEffect(0.6)
					Text("Installing: \(installingModelId ?? "")...")
						.font(.system(size: 11, weight: .medium))
						.foregroundColor(.orange)
				} else if installSuccess == true {
					Image(systemName: "checkmark.circle.fill")
						.foregroundColor(.green)
					Text("Installation completed")
						.font(.system(size: 11, weight: .medium))
						.foregroundColor(.green)
				} else if installSuccess == false {
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundColor(.red)
					Text("Installation failed")
						.font(.system(size: 11, weight: .medium))
						.foregroundColor(.red)
				}

				Spacer()

				if !logs.isEmpty {
					Button {
						copyToClipboard(logs.map(\.text).joined(separator: "\n"),
										flash: "Logs copied!",
										into: $copied)
					} label: {
						HStack(spacing: 3) {
							Image(systemName: copied != nil ? "checkmark" : "doc.on.doc")
							Text("Copy Logs")
						}
						.font(.system(size: 10, weight: .medium))
						.foregroundColor(copied != nil ? .green : .cyan)
					}
					.copiedFlashAutoClear($copied)
					.buttonStyle(.borderless)
				}

				if isInstalling {
					Button(role: .destructive) {
						onCancel()
					} label: {
						Text("Cancel Download")
							.font(.system(size: 10, weight: .semibold))
							.foregroundColor(.red)
					}
					.buttonStyle(.borderless)
				} else {
					Button("Close") {
						onClose()
					}
					.buttonStyle(.borderless)
					.font(.system(size: 10))
				}
			}

			// Gated Repository Help Banner
			if isGatedError && showsGatedBanner {
				gatedModelHelpBanner
			}

			// Live Download Telemetry Banner
			if isInstalling {
				VStack(spacing: 6) {
					HStack(spacing: 8) {
						// Fase actual del proceso
						HStack(spacing: 5) {
							Image(systemName: "arrow.down.circle.fill")
								.foregroundColor(.cyan)
								.font(.system(size: 11))
							Text(downloadPhase.isEmpty ? String(localized: "Downloading components...") : downloadPhase)
								.font(.system(size: 10, weight: .semibold))
								.foregroundColor(.white.opacity(0.95))
								.lineLimit(1)
						}

						Spacer()

						// Velocidad en tiempo real (MB/s)
						if downloadSpeedMBs > 0.05 {
							HStack(spacing: 3) {
								Image(systemName: "bolt.fill")
									.foregroundColor(.yellow)
									.font(.system(size: 9))
								Text("\(downloadSpeedMBs, format: .number.precision(.fractionLength(1))) MB/s")
									.font(.system(size: 10, weight: .bold, design: .monospaced))
									.foregroundColor(.yellow)
							}
							.padding(.horizontal, 6)
							.padding(.vertical, 2)
							.background(Color.yellow.opacity(0.18))
							.cornerRadius(4)
						}

						// Bytes transferidos / Total esperado
						if downloadedBytes > 0 {
							Text(formatDownloadProgress(downloaded: downloadedBytes, total: totalExpectedBytes))
								.font(.system(size: 10, weight: .semibold, design: .monospaced))
								.foregroundColor(.cyan.opacity(0.9))
						}
					}

					// Barra de progreso elegante
					if let fraction = progressFraction {
						ProgressView(value: fraction, total: 1.0)
							.progressViewStyle(.linear)
							.tint(.cyan)
					} else {
						ProgressView()
							.progressViewStyle(.linear)
							.tint(.cyan)
					}
				}
				.padding(8)
				.background(Color.black.opacity(0.45))
				.cornerRadius(6)
				.overlay(
					RoundedRectangle(cornerRadius: 6)
						.stroke(Color.cyan.opacity(0.25), lineWidth: 1)
				)
			}

			ScrollViewReader { proxy in
				ScrollView {
					VStack(alignment: .leading, spacing: 2) {
						ForEach(logs) { line in
							Text(line.text)
								.font(.system(size: 10, design: .monospaced))
								.foregroundColor(.white.opacity(0.92))
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
					.padding(8)
					.textSelection(.enabled)
				}
				.frame(height: 140)
				.background(Color.black.opacity(0.85))
				.cornerRadius(6)
				.onChange(of: logs.count) { _, _ in
					if let lastId = logs.last?.id {
						withAnimation(.easeOut(duration: 0.1)) {
							proxy.scrollTo(lastId, anchor: .bottom)
						}
					}
				}
			}
		}
		.padding(8)
		.background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
		.cornerRadius(8)
	}

	private func formatDownloadProgress(downloaded: Int64, total: Int64) -> String {
		// §9: ByteCountFormatStyle (localizable) en lugar de String(format:).
		if total > 0 {
			let pct = min(100, Int((Double(downloaded) / Double(total)) * 100))
			return String(localized: "\(downloaded.formatted(.byteCount(style: .file))) of \(total.formatted(.byteCount(style: .file))) (\(pct)%)")
		} else {
			return String(localized: "\(downloaded.formatted(.byteCount(style: .file))) downloaded")
		}
	}

	// MARK: - Gated Model Guidance (solo modelos)
	private var gatedModelHelpBanner: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 8) {
				Image(systemName: "lock.shield.fill")
					.foregroundColor(.orange)
					.font(.system(size: 18))

				VStack(alignment: .leading, spacing: 2) {
					Text("Restricted Access Model ('Gated')")
						.font(.system(size: 11, weight: .bold))
						.foregroundColor(.white)

					Text("Hugging Face requires you to authorize access with your account before downloading.")
						.font(.system(size: 10))
						.foregroundColor(.white.opacity(0.85))
				}

				Spacer()

				if let modelId = targetModelId,
				   let url = URL(string: "https://huggingface.co/\(modelId)") {
					Button {
						NSWorkspace.shared.open(url)
					} label: {
						HStack(spacing: 4) {
							Image(systemName: "safari")
							Text("Request Access on HF")
						}
						.font(.system(size: 10, weight: .semibold))
					}
					.buttonStyle(.borderedProminent)
					.tint(.orange)
					.controlSize(.small)
				}
			}

			HStack(alignment: .top, spacing: 6) {
				Image(systemName: "lightbulb.fill")
					.foregroundColor(.yellow)
					.font(.system(size: 10))
					.padding(.top, 1)

				Text("Most of these models have instant approval ('auto'). Once you click 'Agree and access repository' in your browser, your account is enabled and you can click 'Download' again.")
					.font(.system(size: 9.5))
					.foregroundColor(.white.opacity(0.92))
					.fixedSize(horizontal: false, vertical: true)
			}
			.padding(6)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color.black.opacity(0.35))
			.cornerRadius(6)
		}
		.padding(10)
		.background(Color.orange.opacity(0.2))
		.cornerRadius(8)
		.overlay(
			RoundedRectangle(cornerRadius: 8)
				.stroke(Color.orange.opacity(0.55), lineWidth: 1)
		)
	}
}
