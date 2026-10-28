import SwiftUI
import AppKit

public struct DependencyInstallView: View {

	public var body: some View {
		VStack(spacing: 16) {
			// Header
			HStack(spacing: 14) {
				ZStack {
					RoundedRectangle(cornerRadius: 12)
						.fill(Color.orange.opacity(0.15))
						.frame(width: 48, height: 48)

					Image(systemName: "exclamationmark.triangle.fill")
						.font(.system(size: 24))
						.foregroundColor(.orange)
				}

				VStack(alignment: .leading, spacing: 3) {
					HStack(spacing: 8) {
						Text("Required Dependency: Splash Engine")
							.font(.system(size: 16, weight: .bold))

						Text("brew")
							.font(.system(size: 10, weight: .bold, design: .monospaced))
							.padding(.horizontal, 6)
							.padding(.vertical, 2)
							.background(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
							.cornerRadius(4)
					}

					Text("Splash Monitor requires the official Splash CLI installed on your Mac to manage servers, monitor tokens, and serve models.")
						.font(.system(size: 11))
						.foregroundColor(.secondary)
						.lineLimit(2)
				}

				Spacer()
			}

			// Command snippet card
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("Official Installation Command:")
						.font(.system(size: 11, weight: .semibold))
						.foregroundColor(.secondary)
					Spacer()
					Link(destination: URL(string: "https://github.com/incoai/splash")!) {
						HStack(spacing: 3) {
							Text("github.com/incoai/splash")
							Image(systemName: "arrow.up.right.square")
						}
						.font(.system(size: 10))
					}
				}

				HStack {
					Text("brew install incoai/tap/splash")
						.font(.system(size: 12, weight: .medium, design: .monospaced))
						.foregroundColor(.primary)

					Spacer()

					Button {
						let pb = NSPasteboard.general
						pb.clearContents()
						pb.setString("brew install incoai/tap/splash", forType: .string)
					} label: {
						Label("Copy", systemImage: "doc.on.doc")
							.font(.system(size: 10))
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}
				.padding(8)
				.background(Color.black.opacity(0.2))
				.cornerRadius(6)
			}
			.padding(12)
			.background(Color(nsColor: .controlBackgroundColor))
			.cornerRadius(8)

			// System Diagnostics
			HStack(spacing: 12) {
				DiagnosticBadge(
					title: LocalizedStringResource("Homebrew"),
					status: SplashService.shared.hasHomebrew ? LocalizedStringResource("Detected") : LocalizedStringResource("Not found"),
					icon: SplashService.shared.hasHomebrew ? "checkmark.circle.fill" : "xmark.circle.fill",
					isSuccess: SplashService.shared.hasHomebrew
				)

				DiagnosticBadge(
					title: LocalizedStringResource("Apple Silicon"),
					status: isAppleSilicon ? LocalizedStringResource("ARM64 Metal") : LocalizedStringResource("Intel (No compatible)"),
					icon: isAppleSilicon ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
					isSuccess: isAppleSilicon
				)

				DiagnosticBadge(
					title: LocalizedStringResource("Splash CLI"),
					status: SplashService.shared.isSplashInstalled ? (SplashService.shared.splashVersion.map { "\($0)" } ?? LocalizedStringResource("Instalado")) : LocalizedStringResource("Not installed"),
					icon: SplashService.shared.isSplashInstalled ? "checkmark.circle.fill" : "clock.arrow.circlepath",
					isSuccess: SplashService.shared.isSplashInstalled
				)
			}

			// Actions
			HStack(spacing: 10) {
				if SplashService.shared.isInstallingDependency {
					Button(role: .destructive) {
						SplashService.shared.cancelDependencyInstall()
					} label: {
						Label("Cancel Installation", systemImage: "xmark.circle")
							.font(.system(size: 11, weight: .semibold))
					}
					.buttonStyle(.bordered)
					.controlSize(.regular)
				} else {
					Button {
						SplashService.shared.installSplashDependency()
					} label: {
						HStack(spacing: 6) {
							Image(systemName: "arrow.down.circle.fill")
							Text("Install Splash Automatically")
						}
						.font(.system(size: 11, weight: .bold))
					}
					.buttonStyle(.borderedProminent)
					.tint(.blue)
					.controlSize(.regular)
					.disabled(!SplashService.shared.hasHomebrew)
				}

				Button {
					SplashService.shared.installSplashInTerminal()
				} label: {
					Label("Install in Terminal", systemImage: "terminal")
						.font(.system(size: 11))
				}
				.buttonStyle(.bordered)
				.controlSize(.regular)

				Spacer()

				Button {
					SplashService.shared.checkDependencies()
				} label: {
					Label("Verify", systemImage: "arrow.clockwise")
						.font(.system(size: 11))
				}
				.buttonStyle(.bordered)
				.controlSize(.regular)
			}

			// Live Installation Console
			if SplashService.shared.isInstallingDependency || !SplashService.shared.dependencyInstallLogs.isEmpty {
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						if SplashService.shared.isInstallingDependency {
							ProgressView()
								.scaleEffect(0.6)
							Text("Installing Splash...")
								.font(.system(size: 11, weight: .medium))
								.foregroundColor(.orange)
						} else if SplashService.shared.dependencyInstallSuccess == true {
							Image(systemName: "checkmark.circle.fill")
								.foregroundColor(.green)
							Text("Installation completed successfully!")
								.font(.system(size: 11, weight: .medium))
								.foregroundColor(.green)
						} else if SplashService.shared.dependencyInstallSuccess == false {
							Image(systemName: "exclamationmark.triangle.fill")
								.foregroundColor(.red)
							Text("Installation error")
								.font(.system(size: 11, weight: .medium))
								.foregroundColor(.red)
						}

						Spacer()

						if !SplashService.shared.isInstallingDependency {
							Button("Clear") {
								SplashService.shared.dependencyInstallLogs.removeAll()
								SplashService.shared.dependencyInstallSuccess = nil
							}
							.buttonStyle(.borderless)
							.font(.system(size: 10))
						}
					}

					ScrollViewReader { proxy in
						ScrollView {
							VStack(alignment: .leading, spacing: 2) {
								ForEach(Array(SplashService.shared.dependencyInstallLogs.enumerated()), id: \.offset) { idx, log in
									Text(log)
										.font(.system(size: 9, design: .monospaced))
										.foregroundColor(.white.opacity(0.9))
										.frame(maxWidth: .infinity, alignment: .leading)
										.id(idx)
								}
							}
							.padding(8)
						}
						.frame(height: 90)
						.background(Color.black.opacity(0.85))
						.cornerRadius(6)
						.onChange(of: SplashService.shared.dependencyInstallLogs.count) {
							if let last = SplashService.shared.dependencyInstallLogs.indices.last {
								proxy.scrollTo(last, anchor: .bottom)
							}
						}
					}
				}
			}
		}
		.padding(16)
		.background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
		.cornerRadius(12)
		.overlay(
			RoundedRectangle(cornerRadius: 12)
				.stroke(Color.orange.opacity(0.35), lineWidth: 1)
		)
	}

	private var isAppleSilicon: Bool {
#if arch(arm64)
		return true
#else
		return false
#endif
	}
}

struct DiagnosticBadge: View {
	let title: LocalizedStringResource
	let status: LocalizedStringResource
	let icon: String
	let isSuccess: Bool

	var body: some View {
		HStack(spacing: 6) {
			Image(systemName: icon)
				.font(.system(size: 11))
				.foregroundColor(isSuccess ? .green : .orange)

			VStack(alignment: .leading, spacing: 1) {
				Text(title)
					.font(.system(size: 9))
					.foregroundColor(.secondary)
				Text(status)
					.font(.system(size: 10, weight: .semibold))
					.foregroundColor(.primary)
			}

			Spacer()
		}
		.padding(8)
		.frame(maxWidth: .infinity)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(6)
	}
}
