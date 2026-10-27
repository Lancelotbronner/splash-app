import SwiftUI
import AppKit

public struct MainWindowView: View {
    @State private var notifications = NotificationService.shared
    @State private var autoLaunch = AutoLaunchService.shared
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    @State private var showOptimalAppliedFeedback: Bool = false

    
    public enum SidebarItem: String, CaseIterable, Identifiable {
        case dashboard
        case connectedApps
        case models
        case server
        case modelTesting
        case settings
        case about
        
        public var id: String { rawValue }
        
        public var title: LocalizedStringResource {
            switch self {
            case .dashboard: return "Token Dashboard" /*FIXME: "Dashboard de Tokens" */
            case .connectedApps: return "Connected Apps" /*FIXME: "Apps Conectadas" */
            case .models: return "Model Manager" /*FIXME: "Gestor de Modelos" */
            case .server: return "Server & Agents" /*FIXME: "Servidor y Agentes" */
            case .modelTesting: return "Model Testing" /*FIXME: "Test de Modelos" */
            case .settings: return "Settings" /*FIXME: "Configuración" */
            case .about: return "About" /*FIXME: "Acerca de" */
            }
        }
        
        public var icon: String {
            switch self {
            case .dashboard: return "speedometer"
            case .connectedApps: return "app.connected.to.app.below.fill"
            case .models: return "shippingbox"
            case .server: return "server.rack"
            case .modelTesting: return "testtube.2"
            case .settings: return "gearshape"
            case .about: return "info.circle"
            }
        }
    }
    
    public init(initialTab: SidebarItem = .dashboard) {
        self._selectedSidebarItem = State(initialValue: initialTab)
    }
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // App Branding Header
                HStack(spacing: 10) {
                    AppIconView(size: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text("Splash Monitor")
                                .font(.system(size: 15, weight: .bold))
                            
                            Text("BETA")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .cornerRadius(3)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(SplashService.shared.isRunning ? Color.green : Color.red)
                                .frame(width: 7, height: 7)
                            Text(SplashService.shared.isRunning ? ("Online" /*FIXME: "Activo" */) : ("Stopped" /*FIXME: "Detenido" */))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                
                Divider()
                
                // Navigation items
                VStack(spacing: 3) {
                    ForEach(SidebarItem.allCases) { item in
                        Button {
                            selectedSidebarItem = item
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedSidebarItem == item ? .accentColor : .secondary)
                                    .frame(width: 20, alignment: .center)
                                
                                Text(item.title)
                                    .font(.system(size: 13, weight: selectedSidebarItem == item ? .semibold : .regular))
                                    .foregroundColor(selectedSidebarItem == item ? .primary : .secondary)
                                
                                Spacer()
                                
                                if item == .connectedApps {
                                    let count = SplashService.shared.connectedApps.filter { $0.status == .active }.count
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.green)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selectedSidebarItem == item ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                
                Spacer()
                
                Divider()
                
                // Bottom Sidebar Controls (Language toggle & Status)
                HStack {
                    Spacer()
                    
                    Button {
                        Preferences.showMenuBarIcon.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: Preferences.showMenuBarIcon ? "menubar.rectangle" : "rectangle.slash")
                                .foregroundColor(Preferences.showMenuBarIcon ? .accentColor : .secondary)
                            Text(Preferences.showMenuBarIcon ? ("Menu: ON" /*FIXME: "Barra: ON" */) : ("Menu: OFF" /*FIXME: "Barra: OFF" */))
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderless)
                    .help("Toggle icon in top menu bar" /*FIXME: "Activar/Desactivar ícono en la barra de menú superior" */)
                }
                .padding(12)
            }
            .frame(minWidth: 220, idealWidth: 240)
        } detail: {
            VStack(spacing: 0) {
                // Dependency missing banner / wizard
                if !SplashService.shared.isSplashInstalled {
                    DependencyInstallView()
                        .padding(16)
                }
                
                // Splash CLI engine update banner
                if SplashService.shared.hasSplashCliUpdate {
                    splashCliUpdateBanner
                }
                
                // Update available banner
                if SplashService.shared.hasUpdate {
                    updateBanner
                }
                
                // First-launch or pending prompt to place icon in top menu bar
                if !Preferences.hasAskedAboutMenuBar {
                    menuBarPromptBanner
                }
                
                // Main Content View
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch selectedSidebarItem {
                        case .dashboard:
                            dashboardDetailView
                        case .connectedApps:
                            ConnectedAppsView()
                        case .models:
                            ModelManagerView()
                        case .server:
                            ServerControlView()
                        case .modelTesting:
                            ModelTestingView()
                        case .settings:
                            settingsDetailView
                        case .about:
                            AboutView()
                        }
                    }
                    .padding(24)
                }
            }
            .frame(minWidth: 560, minHeight: 480)
            .background(Color(nsColor: .windowBackgroundColor))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAboutView"))) { _ in
                selectedSidebarItem = .about
            }
        }
    }
    
    // MARK: - Splash CLI Engine Update Available Banner
    private var splashCliUpdateBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("New Splash engine version available" /*FIXME: "Nueva versión del motor Splash disponible" */)
                    .font(.system(size: 12, weight: .semibold))
                Text("Splash CLI \(SplashService.shared.latestSplashCliVersion.isEmpty ? "new version" : SplashService.shared.latestSplashCliVersion) is available (installed: \(SplashService.shared.installedSplashCliVersion.isEmpty ? "unknown" : SplashService.shared.installedSplashCliVersion))."
                    /*FIXME: "Splash CLI \(SplashService.shared.latestSplashCliVersion.isEmpty ? "nueva versión" : SplashService.shared.latestSplashCliVersion) está disponible (instalada: \(SplashService.shared.installedSplashCliVersion.isEmpty ? "desconocida" : SplashService.shared.installedSplashCliVersion))." */
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Upgrade Splash" /*FIXME: "Actualizar Splash" */) {
                SplashService.shared.upgradeSplashInTerminal()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
            
            if !SplashService.shared.latestSplashCliReleaseURL.isEmpty, let url = URL(string: SplashService.shared.latestSplashCliReleaseURL) {
                Button("View notes" /*FIXME: "Ver notas" */) {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Button("Skip" /*FIXME: "Omitir" */) {
                SplashService.shared.hasSplashCliUpdate = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Update Available Banner
    private var updateBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Update available" /*FIXME: "Nueva versión disponible" */)
                    .font(.system(size: 12, weight: .semibold))
                Text("Splash Monitor \(SplashService.shared.latestVersion ?? "new version") is available for download." /*FIXME: "Splash Monitor \(SplashService.shared.latestVersion ?? "nueva versión") está disponible para descargar." */)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Download" /*FIXME: "Descargar" */) {
                if let url = URL(string: SplashService.shared.latestReleaseURL ?? "https://github.com/hometrix/SplashMonitor/releases/latest") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            
            Button("Skip" /*FIXME: "Omitir" */) {
                SplashService.shared.hasUpdate = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.green.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Menu Bar Prompt Banner
    private var menuBarPromptBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "menubar.arrow.up.rectangle")
                .font(.system(size: 22))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Would you like to place the monitor in the top menu bar?" /*FIXME: "¿Deseas colocar el monitor en la barra de menú superior?" */)
                    .font(.system(size: 12, weight: .semibold))
                Text("You'll be able to see token speed in tok/s and token usage next to Bluetooth and Wi-Fi." /*FIXME: "Podrás ver la velocidad en tok/s y el uso de tokens junto a Bluetooth y Wi-Fi." */)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Yes, place in menu bar" /*FIXME: "Sí, colocar arriba" */) {
                Preferences.showMenuBarIcon = true
                Preferences.hasAskedAboutMenuBar = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button("Not now" /*FIXME: "No por ahora" */) {
                Preferences.showMenuBarIcon = false
                Preferences.hasAskedAboutMenuBar = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.accentColor.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Dashboard Detail View
    private var dashboardDetailView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Splash Local Inference Monitor" /*FIXME: "Monitor de Inferencia Local Splash" */)
                        .font(.system(size: 20, weight: .bold))
                    Text("Real-time token metrics, throughput, and Metal memory" /*FIXME: "Métricas de tokens, velocidad y memoria Metal en tiempo real" */)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        Task { await SplashService.shared.checkServerStatus() }
                    } label: {
                        Label("Refresh" /*FIXME: "Actualizar" */, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // MARK: Modelo activo
            activeModelCard
            
            Divider()
            
            // Embed the token metrics view
            TokenMetricsView()
        }
    }
    
    /// Tarjeta compacta que muestra el modelo en ejecución, puerto y versión de Splash.
    @ViewBuilder
    private var activeModelCard: some View {
        let isRunning = SplashService.shared.isRunning
        let modelRaw  = SplashService.shared.activeModel
        let modelShort = modelRaw.components(separatedBy: "/").last ?? modelRaw
        let modelClean = modelShort
            .replacingOccurrences(of: "-Splash", with: "")
            .replacingOccurrences(of: "-GGUF", with: "")
        
        HStack(spacing: 12) {
            // Estado indicator
            Circle()
                .fill(isRunning ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)
                .shadow(color: isRunning ? .green.opacity(0.6) : .clear, radius: 4)
            
            // Nombre del modelo
            VStack(alignment: .leading, spacing: 2) {
                Text("Running model" /*FIXME: "Modelo en ejecución" */)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                if isRunning {
                    Text(modelClean)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text(modelRaw)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Server stopped" /*FIXME: "Servidor detenido" */)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Puerto y versión Splash
            VStack(alignment: .trailing, spacing: 4) {
                if isRunning {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(":\(SplashService.shared.activePort)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                }
                
                if let splashVer = SplashService.shared.splashVersion {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Splash \(splashVer)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isRunning ? Color.green.opacity(0.35) : Color.secondary.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
    }

    
    // MARK: - Settings Detail View
    private var settingsDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Splash Monitor Settings" /*FIXME: "Configuración de Splash Monitor" */)
                .font(.system(size: 18, weight: .bold))
            
            Divider()
            
            // Perfil de Rendimiento Óptimo (Apple Silicon M4 Max / 64 GB)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Optimal Performance Profile" /*FIXME: "Perfil de Rendimiento Óptimo" */)
                                .font(.system(size: 13, weight: .bold))
                            
                            Text("M4 MAX / 64 GB")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.blue)
                                .cornerRadius(3)
                        }
                        
                        Text("Restores recommended high-speed and capacity settings for Apple Silicon: GDN BF16 (-50% RAM), Thinking Budget 8K, Persistent SSD cache, Context 128K, Idle off (Always in RAM), Port 8005, LAN 0.0.0.0, and open CORS (*)." /*FIXME: "Restablece los parámetros de máxima velocidad y capacidad recomendados para tu Apple Silicon: GDN BF16 (-50% RAM), Thinking Budget 8K, Caché SSD persistente, Contexto 128K, Inactividad off (Siempre en RAM), Puerto 8005, Red LAN 0.0.0.0 y CORS abierto (*)." */)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        SplashService.shared.restoreOptimalProfile()
                        Preferences.showMenuBarIcon = true
                        withAnimation {
                            showOptimalAppliedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                showOptimalAppliedFeedback = false
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                            Text("Restore Optimal Configuration" /*FIXME: "Restaurar Configuración Óptima" */)
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.regular)
                }
                
                if showOptimalAppliedFeedback {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text("Optimal configuration restored and saved successfully in UserDefaults (M4 Max / 64 GB)!" /*FIXME: "¡Configuración óptima restaurada y guardada con éxito en UserDefaults (M4 Max / 64 GB)!" */)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
                    .transition(.opacity)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
            )
            
            // Language Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Application Language" /*FIXME: "Idioma de la Aplicación" */)
                    .font(.system(size: 13, weight: .semibold))

                //FIXME:
//                Picker("", selection: $loc.languageMode) {
//                    let sysLang = Localization.detectSystemLanguage() == "es" ? "Español" : "English"
//                    Text("\("Automatic (macOS: " /*FIXME: "Automático (macOS: " */)\(sysLang))").tag("system")
//                    Text("🇩🇴 Español (República Dominicana)").tag("es")
//                    Text("🇬🇧 English").tag("en")
//                }
//                .pickerStyle(.radioGroup)
//                .font(.system(size: 11))
                
                Text("Automatically syncs with macOS system language or lets you choose manually." /*FIXME: "Sincroniza automáticamente con el idioma configurado en tu macOS o permite fijar uno manualmente." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Menu bar icon toggle
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Menu Bar (macOS Status Bar)" /*FIXME: "Barra de Menú Superior (macOS Status Bar)" */)
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle("Show icon and metrics in the top bar next to Bluetooth" /*FIXME: "Mostrar ícono y métricas en la barra superior junto al Bluetooth" */, isOn: Preferences.$showMenuBarIcon)
                    .font(.system(size: 12))
                
                if Preferences.showMenuBarIcon {
                    Text("Information in menu bar:" /*FIXME: "Información en la barra:" */)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: Preferences.$menuBarDisplayMode) {
                        Text("Icon only" /*FIXME: "Solo Ícono" */).tag("icon")
                        Text("Icon + Speed (tok/s)" /*FIXME: "Ícono + Velocidad (tok/s)" */).tag("speed")
                        Text("Icon + Tokens Used" /*FIXME: "Ícono + Tokens Usados" */).tag("tokens")
                        Text("Icon + Model" /*FIXME: "Ícono + Modelo" */).tag("model")
                    }
                    .pickerStyle(.radioGroup)
                    .font(.system(size: 11))
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Modo Solo Barra de Menú
                    Toggle(isOn: Preferences.$menuBarOnlyMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Menu Bar Only Mode" /*FIXME: "Modo Solo Barra de Menú" */)
                                .font(.system(size: 12))
                            Text("Cmd+Q hides the app from the Dock and task list instead of quitting. Use Cmd+Shift+Q to quit completely." /*FIXME: "Cmd+Q oculta la app del Dock y del listado de tareas en lugar de cerrarla. Usa Cmd+Shift+Q para salir completamente." */)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Inicio Automático al Encender el Mac (Launch at Login)
            VStack(alignment: .leading, spacing: 8) {
                Text("System Startup" /*FIXME: "Inicio del Sistema" */)
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle(isOn: Binding(
                    get: { autoLaunch.isEnabled },
                    set: { autoLaunch.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch Splash Monitor at startup" /*FIXME: "Iniciar Splash Monitor al encender el Mac" */)
                            .font(.system(size: 12))
                        Text("Automatically launch the app in background when logging in to macOS." /*FIXME: "Ejecuta automáticamente la aplicación en segundo plano al iniciar sesión en macOS." */)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 12))
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Notificaciones de macOS
            VStack(alignment: .leading, spacing: 8) {
                Text("macOS Notifications" /*FIXME: "Notificaciones de macOS" */)
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle(isOn: $notifications.isNotificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System alerts and notifications" /*FIXME: "Alertas y notificaciones del sistema" */)
                            .font(.system(size: 12))
                        Text("Receive alerts when the server starts, stops unexpectedly, or if unified memory enters critical pressure." /*FIXME: "Recibe avisos cuando el servidor se inicie, se detenga inesperadamente o si la memoria unificada del Mac entra en presión crítica." */)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 12))
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Shell integration (P-09)
            VStack(alignment: .leading, spacing: 8) {
                Text("Shell Integration" /*FIXME: "Integración con el Shell" */)
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle("Allow Splash Monitor to add a line to your ~/.zshrc" /*FIXME: "Permitir a Splash Monitor añadir una línea a tu ~/.zshrc" */,
                       isOn: Binding(
                            get: { Preferences.shellConfigConsent },
                            set: { allowed in
                                Preferences.shellConfigConsent = allowed
                                Preferences.shellConfigDeclined = !allowed
                                if allowed {
                                    SplashService.shared.syncShellEnvironment(port: SplashService.shared.activePort)
                                } else {
                                    SplashService.shared.clearShellEnvironment()
                                }
                            }
                       ))
                    .font(.system(size: 12))
                
                Text("Without this line, agents launched from an external terminal do not inherit the active port. The ~/.splash_monitor_env file is always written, with or without permission." /*FIXME: "Sin esta línea, los agentes lanzados desde una terminal externa no heredan el puerto activo. El fichero ~/.splash_monitor_env se escribe siempre, con o sin permiso." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if Preferences.shellConfigConsent {
                    Button("Undo changes to ~/.zshrc" /*FIXME: "Deshacer cambios en ~/.zshrc" */) {
                        SplashService.shared.clearShellEnvironment()
                        Preferences.shellConfigConsent = false
                        Preferences.shellConfigDeclined = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: 11))
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Refresh rate
            VStack(alignment: .leading, spacing: 8) {
                Text("Refresh Interval" /*FIXME: "Frecuencia de Actualización" */)
                    .font(.system(size: 13, weight: .semibold))
                
                HStack {
                    Slider(value: Preferences.$refreshInterval, in: 0.5...5.0, step: 0.5)
                        .onChange(of: Preferences.refreshInterval) {
                            SplashService.shared.startPolling()
                        }
                    Text(String(format: "%.1f s", Preferences.refreshInterval))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 50)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Server Network & Context Options
            VStack(alignment: .leading, spacing: 10) {
                Text("Inference Engine Options" /*FIXME: "Opciones del Motor de Inferencia" */)
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle("Allow incoming connections from local network (bind to 0.0.0.0)" /*FIXME: "Permitir conexiones entrantes desde la red local (enlazar a 0.0.0.0)" */,
                       isOn: Preferences.$listenOnAllInterfaces)
                    .font(.system(size: 12))
                
                Text("By default, Splash only listens on 127.0.0.1 (localhost). Enable this option to let other devices, servers, or agents on your local network (LAN) run inference on this Mac." /*FIXME: "Por defecto, Splash solo escucha en 127.0.0.1 (localhost). Activa esta opción para permitir que otros dispositivos, servidores o agentes en tu red local (LAN) realicen inferencias en tu Mac." */)
                    .font(.system(size: 10))
                if Preferences.listenOnAllInterfaces {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allowed Domains or Hosts (--allowed-host):" /*FIXME: "Dominios o Hosts Permitidos (--allowed-host):" */)
                            .font(.system(size: 11, weight: .medium))
                        
                        TextField("e.g. mydomain.duckdns.org, mymac.local" /*FIXME: "ej. midominio.duckdns.org, mimac.local" */, text: Preferences.$allowedHosts)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                        
                        Text("Splash blocks requests with unknown Host headers for security (DNS Rebinding protection). Enter your DDNS domains or hostnames separated by commas." /*FIXME: "Splash bloquea por seguridad cualquier petición con un Host desconocido (protección DNS Rebinding). Ingresa tus dominios DDNS o nombres de host separados por comas." */)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allowed Web Origins & Extensions (--allowed-origin):" /*FIXME: "Orígenes Web y Extensiones (--allowed-origin):" */)
                        .font(.system(size: 11, weight: .medium))
                    
                    TextField("e.g. * (for Chrome extension and local web)" /*FIXME: "ej. * (para extensión de Chrome y web local)" */, text: Preferences.$allowedOrigins)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    
                    Text("Allows browser extensions (Chrome, Arc, Brave), local web apps, and Tauri to interact with Splash via CORS. Default '*' allows any local origin or extension." /*FIXME: "Permite que extensiones de navegador (Chrome, Arc, Brave), aplicaciones Web locales y Tauri interactúen con Splash vía CORS. Por defecto '*' permite cualquier origen local o extensión." */)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                
                Divider()
                
                HStack {
                    Text("Context window limit:" /*FIXME: "Límite de ventana de contexto:" */)
                        .font(.system(size: 12))
                    
                    Spacer()
                    
                    Picker("", selection: Preferences.$maxContext) {
                        Text("Automatic (managed by Splash)" /*FIXME: "Automático (gestión de Splash)" */).tag("auto")
                        Text("16K (16,384 tokens)").tag("16K")
                        Text("32K (32,768 tokens)").tag("32K")
                        Text("64K (65,536 tokens)").tag("64K")
                        Text("128K (131,072 tokens)").tag("128K")
                        Text("256K (262,144 tokens)").tag("256K")
                        Text("512K (524,288 tokens)").tag("512K")
                        Text("1M (1,000,000 tokens · YaRN)" /*FIXME: "1M (1,000,000 tokens · YaRN)" */).tag("1M")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text("Configures the --max-context flag to limit or expand memory reserved for token history (Splash 1.4.0+ supports up to 1M with YaRN)." /*FIXME: "Configura el parámetro --max-context para limitar o expandir la memoria reservada para el historial de tokens (Splash 1.4.0+ soporta hasta 1M con YaRN)." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text("Idle memory release timeout:" /*FIXME: "Liberación de memoria por inactividad:" */)
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: Preferences.$idleRelease) {
                        Text("1 min (Fast saving)" /*FIXME: "1 min (Ahorro rápido)" */).tag("1m")
                        Text("2 min (Aggressive)" /*FIXME: "2 min (Agresivo)" */).tag("2m")
                        Text("5 min (Balanced)" /*FIXME: "5 min (Equilibrado)" */).tag("5m")
                        Text("10 min (Splash default)" /*FIXME: "10 min (Por defecto Splash)" */).tag("10m")
                        Text("30 min (Extended)" /*FIXME: "30 min (Extendido)" */).tag("30m")
                        Text("Disabled (Always in RAM)" /*FIXME: "Desactivado (Siempre en RAM)" */).tag("off")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text("Flag --idle-release: unwires and frees VRAM model weights when idle, restoring them on-the-fly when new queries arrive." /*FIXME: "Parámetro --idle-release: desvincula y libera los pesos en VRAM cuando no hay peticiones activas, restaurándolos al vuelo al recibir nuevas consultas." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text("Max Metal memory budget:" /*FIXME: "Presupuesto máximo de memoria Metal:" */)
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: Preferences.$maxMemory) {
                        Text("Automatic (unlimited)" /*FIXME: "Automático (sin límite)" */).tag("auto")
                        Text("16 GB").tag("16G")
                        Text("24 GB").tag("24G")
                        Text("28 GB").tag("28G")
                        Text("32 GB").tag("32G")
                        Text("40 GB").tag("40G")
                        Text("48 GB").tag("48G")
                        Text("64 GB").tag("64G")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text("Flag --max-memory: limits the Metal unified memory budget to avoid exhausting Mac RAM." /*FIXME: "Parámetro --max-memory: limita el techo de memoria unificada asignable a Metal para no copar la RAM disponible en el Mac." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                Toggle("Automatic protection under macOS critical memory pressure" /*FIXME: "Protección automática ante presión crítica de memoria macOS" */,
                       isOn: Preferences.$autoReleaseOnMemoryPressure)
                    .font(.system(size: 12))
                
                Text("Monitors macOS kernel events. If the system enters critical memory pressure and Splash is idle, frees resources to prevent system freezing." /*FIXME: "Monitorea eventos del kernel de macOS. Si el sistema entra en presión de memoria crítica y Splash está inactivo, libera los recursos para evitar bloqueos del sistema." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                Toggle("Language / Code Only mode (--language-only)" /*FIXME: "Modo Solo Lenguaje / Código (--language-only)" */,
                       isOn: Preferences.$languageOnly)
                    .font(.system(size: 12))
                
                Text("Disables vision projector (mmproj) loading. Required for GGUF coder models (like Tiel-Coder, Qwopus, Cyber-Tiel) that lack image weights." /*FIXME: "Desactiva la carga del proyector de visión (mmproj). Requerido para modelos de código GGUF (como Tiel-Coder, Qwopus, Cyber-Tiel) que no incluyen pesos de imágenes." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text("MoE Draft Verification (--verify-rows):" /*FIXME: "Verificación de Borrador MoE (--verify-rows):" */)
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: Preferences.$verifyRows) {
                        Text("Auto (Adaptive, +13–42% speed)" /*FIXME: "Auto (Adaptativa, +13–42% vel)" */).tag("auto")
                        Text("All (All rows, Deterministic)" /*FIXME: "All (Todas las filas, Determinista)" */).tag("all")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text("Flag --verify-rows (Splash 1.4.0+): 'auto' adapts speculative draft token verification for faster decode. 'all' ensures deterministic output reproducibility." /*FIXME: "Parámetro --verify-rows (Splash 1.4.0+): 'auto' adapta la verificación de tokens de borrador aumentando la velocidad de decodificación. 'all' garantiza reproducibilidad exacta de salidas." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text("MoE Experts RAM Budget (--expert-memory):" /*FIXME: "Memoria en RAM para Expertos MoE (--expert-memory):" */)
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: Preferences.$expertMemory) {
                        Text("Automatic (managed by Splash)" /*FIXME: "Automático (gestión de Splash)" */).tag("auto")
                        Text("Disabled (All resident in RAM)" /*FIXME: "Desactivado (Todos en RAM)" */).tag("off")
                        Text("4 GB (Streaming SSD)").tag("4G")
                        Text("8 GB (Streaming SSD)").tag("8G")
                        Text("12 GB (Streaming SSD)").tag("12G")
                        Text("16 GB (Streaming SSD)").tag("16G")
                        Text("24 GB (Streaming SSD)").tag("24G")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text("Flag --expert-memory (Splash 1.4.0+): retains active MoE experts in RAM and streams the rest on-the-fly from the high-speed SSD." /*FIXME: "Parámetro --expert-memory (Splash 1.4.0+): permite mantener expertos MoE en RAM y transmitir los restantes en streaming desde el SSD ultrarrápido sin saturar la memoria." */)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Additional Splash CLI Flags:" /*FIXME: "Flags CLI Adicionales de Splash:" */)
                        .font(.system(size: 11, weight: .medium))
                    
                    TextField("e.g. --no-webui --max-cache-disk 50GB" /*FIXME: "ej. --no-webui --max-cache-disk 50GB" */, text: Preferences.$customServerFlags)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    
                    Text("Arbitrary additional flags passed directly to 'splash serve'. Automatically sanitized to prevent command injection." /*FIXME: "Parámetros y banderas arbitrarias adicionales que se pasarán al final de 'splash serve'. Se sanean automáticamente para evitar inyección de comandos." */)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Check for updates
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Splash Monitor Updates" /*FIXME: "Actualizaciones de Splash Monitor" */)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if SplashService.shared.hasUpdate {
                        Text("New version: \(SplashService.shared.latestVersion ?? "")!" /*FIXME: "¡Nueva versión: \(SplashService.shared.latestVersion ?? "")!" */)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Text("You're up to date" /*FIXME: "Estás en la última versión" */)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Button {
                        Task { await SplashService.shared.checkForUpdate() }
                    } label: {
                        Label("Check for updates" /*FIXME: "Buscar actualizaciones" */, systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if SplashService.shared.hasUpdate, let url = SplashService.shared.latestReleaseURL {
                        Button {
                            if let releaseURL = URL(string: url) {
                                NSWorkspace.shared.open(releaseURL)
                            }
                        } label: {
                            Label("Download new version" /*FIXME: "Descargar nueva versión" */, systemImage: "arrow.down.circle")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Dependencies & CLI System Info
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Splash CLI Inference Engine" /*FIXME: "Motor de Inferencia Splash CLI" */)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if SplashService.shared.hasSplashCliUpdate {
                        Text("New version \(SplashService.shared.latestSplashCliVersion)!" /*FIXME: "¡Nueva versión \(SplashService.shared.latestSplashCliVersion)!" */)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(SplashService.shared.isSplashInstalled ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(SplashService.shared.isSplashInstalled 
                            ? (!SplashService.shared.installedSplashCliVersion.isEmpty ? "v\(SplashService.shared.installedSplashCliVersion)" : (SplashService.shared.splashVersion ?? ("Installed" /*FIXME: "Instalado" */))) 
                            : ("Not installed" /*FIXME: "No instalado" */))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(SplashService.shared.isSplashInstalled ? .green : .orange)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Splash CLI: \(SplashService.shared.splashExecutablePath)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("Python Backend: \(SplashService.shared.splashPythonPath)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("Models Directory: \(SplashService.shared.modelsDirectory.path)" /*FIXME: "Directorio de Modelos: \(SplashService.shared.modelsDirectory.path)" */)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    if SplashService.shared.isSplashInstalled {
                        if SplashService.shared.hasSplashCliUpdate {
                            Button {
                                SplashService.shared.upgradeSplashInTerminal()
                            } label: {
                                Label("Upgrade Splash (brew upgrade)" /*FIXME: "Actualizar Splash (brew upgrade)" */, systemImage: "arrow.up.circle")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        } else {
                            Button {
                                SplashService.shared.upgradeSplashInTerminal()
                            } label: {
                                Label("Upgrade Splash (brew upgrade)" /*FIXME: "Actualizar Splash (brew upgrade)" */, systemImage: "arrow.up.circle")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        Button {
                            SplashService.shared.installSplashDependency()
                        } label: {
                            Label("Install Splash (brew install)" /*FIXME: "Instalar Splash (brew install)" */, systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    Button {
                        Task {
                            SplashService.shared.checkDependencies()
                            SplashService.shared.refreshInstalledModels()
                            await SplashService.shared.checkSplashCliUpdate()
                        }
                    } label: {
                        if SplashService.shared.isCheckingSplashCliUpdate {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Check update" /*FIXME: "Buscar actualización" */, systemImage: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Link(destination: URL(string: "https://github.com/incoai/splash")!) {
                        HStack(spacing: 3) {
                            Text("GitHub incoai/splash")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.system(size: 10))
                    }
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}
