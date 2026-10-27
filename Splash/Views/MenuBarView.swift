import SwiftUI
import AppKit

public struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var activeTab: AppTab = .metrics
    
    public enum AppTab: String, CaseIterable, Identifiable {
        case metrics
        case models
        case server
        case settings
        case about
        
        public var id: String { rawValue }
        
        public var title: LocalizedStringResource {
            switch self {
            case .metrics: return LocalizedStringResource("Metrics")
            case .models: return LocalizedStringResource("Models")
            case .server: return LocalizedStringResource("Server")
            case .settings: return LocalizedStringResource("Settings")
            case .about: return LocalizedStringResource("About")
            }
        }
        
        public var icon: String {
            switch self {
            case .metrics: return "speedometer"
            case .models: return "shippingbox"
            case .server: return "server.rack"
            case .settings: return "gearshape"
            case .about: return "info.circle"
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            // Tab Selector Bar
            tabSelectorBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Main Content Area
            ScrollView {
                VStack(spacing: 12) {
                    if !SplashService.shared.isSplashInstalled {
                        DependencyInstallView()
                    }
                    
                    switch activeTab {
                    case .metrics:
                        TokenMetricsView()
                    case .models:
                        ModelManagerView()
                    case .server:
                        ServerControlView()
                    case .settings:
                        settingsView
                    case .about:
                        AboutView()
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 460)
            
            Divider()
            
            // Footer
            footerView
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        }
        .frame(width: 440)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 8) {
            AppIconView(size: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text("Splash Monitor")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("BETA")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange)
                        .cornerRadius(3)
                    
                    if !SplashService.shared.isSplashInstalled {
                        Text("brew")
                            .textCase(.uppercase)
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.red)
                            .cornerRadius(3)
                    }
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(SplashService.shared.isRunning ? Color.green : (SplashService.shared.isSplashInstalled ? Color.red : Color.orange))
                        .frame(width: 6, height: 6)
                    
                    if !SplashService.shared.isSplashInstalled {
                        Text("Needs Splash")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    } else {
                        Text(SplashService.shared.isRunning ? SplashService.shared.activeModel.components(separatedBy: "/").last ?? SplashService.shared.activeModel : String(localized: "Offline"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Free memory button if running
            if SplashService.shared.isRunning {
                Button {
                    SplashService.shared.releaseMemoryNow()
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Release memory (Unload model weights)")
            }
            
            // Stop server button if running
            if SplashService.shared.isRunning {
                Button {
                    SplashService.shared.stopServer()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Stop Splash Server")
            }
            
            // Open full window button
            Button {
                openMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Open full application window")
            
            Button {
                Task {
                    await SplashService.shared.checkServerStatus()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Refresh now")
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Splash Monitor (Exit app)")
        }
    }
    
    // MARK: - Tab Selector Bar
    private var tabSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeTab = tab
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10))
                            Text(tab.title)
                                .font(.system(size: 11, weight: activeTab == tab ? .semibold : .regular))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(activeTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                        .foregroundColor(activeTab == tab ? .accentColor : .secondary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Settings View
    @ViewBuilder
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar Configuration")
                .font(.system(size: 12, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Information shown in top bar:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Picker("empty", selection: Preferences.$menuBarDisplayMode) {
                    Text("Icon Only").tag("icon")
                    Text("Icon + Speed (tok/s)").tag("speed")
                    Text("Icon + Tokens Used").tag("tokens")
                    Text("Icon + Active Model").tag("model")
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: 11))
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Refresh Interval")
                    .font(.system(size: 11, weight: .semibold))
                
                HStack {
                    Slider(value: Preferences.$refreshInterval, in: 0.5...5.0, step: 0.5)
                        .onChange(of: Preferences.refreshInterval) {
                            SplashService.shared.startPolling()
                        }
                    Text(String(format: "%.1f s", Preferences.refreshInterval))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 45)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            // Open full window button
            Button {
                openMainWindow()
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Full Main Window")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Link("inco.ai/blog/splash", destination: URL(string: "https://inco.ai/blog/splash/")!)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Link("Hugging Face incoai", destination: URL(string: "https://huggingface.co/incoai")!)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let existing = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
            existing.makeKeyAndOrderFront(nil)
            return
        }
        openWindow(id: "main")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}
