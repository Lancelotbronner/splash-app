import SwiftUI
import AppKit

public struct ServerControlView: View {
    @State private var portString: String = "8000"
    @State private var isCustomModel: Bool = false
    @State private var customModelText: String = ""
    @State private var copiedMessage: String? = nil
    @State private var showOptimalAppliedBanner: Bool = false
    
    // Agent alert state
    @State private var showingAgentOfflineAlert: Bool = false
    @State private var showingAgentNotInstalledAlert: Bool = false
    @State private var showingLogsSheet: Bool = false
    @State private var pendingAgentName: String = ""
    @State private var pendingAgentCommand: String = ""
    
    /// Error de validación del identificador personalizado (P-03).
    /// `nil` = válido o campo no utilizado. Misma regla que aplica el servicio.
    private var customModelError: String? {
        guard isCustomModel else { return nil }
        let value = customModelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return "Enter an owner/repo or owner/repo:variant identifier." /*FIXME: "Escribe un identificador owner/repo o owner/repo:variante." */
        }
        return ModelIDValidator.rejectionReason(value)
    }
    
    /// Error de validación de flags CLI adicionales (P-03).
    private var customFlagsError: String? {
        let (_, err) = ServerCLIValidator.validateAndTokenize(Preferences.customServerFlags)
        return err
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 0. Dependency missing alert if needed
            if !SplashService.shared.isSplashInstalled {
                dependencyWarningBanner
            }
            
            // 1. Current Status Banner
            statusBannerView
            
            // 2. Model Selection & Launch Section (FEATURED)
            modelSelectionAndLaunchView
            
            // 3. Coding Agents Launcher
            agentsLauncherView
            
            // 4. API Endpoints & Copy Helpers
            apiEndpointsView
        }
        .onAppear {
            portString = "\(SplashService.shared.activePort)"
        }
        .onChange(of: SplashService.shared.activePort) { _, newPort in
            portString = "\(newPort)"
        }
        .alert(
            "Splash Server Offline" /*FIXME: "Servidor Splash Apagado" */,
            isPresented: $showingAgentOfflineAlert
        ) {
            Button("Start Server First" /*FIXME: "Arrancar Servidor Primero" */) {
                let targetModel = isCustomModel ? customModelText.trimmingCharacters(in: .whitespacesAndNewlines) : SplashService.shared.selectedModelForLaunch
                let targetPort = Int(portString) ?? SplashService.shared.activePort
                SplashService.shared.startServer(model: targetModel, port: targetPort)
            }
            Button("Cancel" /*FIXME: "Cancelar" */, role: .cancel) {}
        } message: {
            Text("To connect \(pendingAgentName), the local Splash inference server must be running. Start the server first." /*FIXME: "Para conectar \(pendingAgentName), el servidor de inferencia local Splash debe estar activo. Arranca el servidor primero." */)
        }
        .alert(
            "\(pendingAgentName) Not Found" /*FIXME: "\(pendingAgentName) No Encontrado" */,
            isPresented: $showingAgentNotInstalledAlert
        ) {
            Button("Open Installation Guide" /*FIXME: "Abrir Guía de Instalación" */) {
                let url = SplashService.shared.agentInstallURL(agent: pendingAgentCommand)
                NSWorkspace.shared.open(url)
            }

            Button(
                pendingAgentCommand == "claude-cowork" ? "Open Claude Anyway" : (pendingAgentCommand == "chatgpt" ? "Open ChatGPT Anyway" : (pendingAgentCommand == "dsh" ? "Open DeepSeek Harness Anyway" : "Launch in Terminal Anyway"))
                   /*FIXME:
                    pendingAgentCommand == "claude-cowork" ? "Abrir Claude de Todos Modos" : (pendingAgentCommand == "chatgpt" ? "Abrir ChatGPT de Todos Modos" : (pendingAgentCommand == "dsh" ? "Abrir DeepSeek Harness de Todos Modos" : "Lanzar en Terminal de Todos Modos"
                    */
            ) {
                SplashService.shared.launchAgent(agent: pendingAgentCommand)
            }
            Button("Cancel" /*FIXME: "Cancelar" */, role: .cancel) {}
        } message: {
            Text(
                pendingAgentCommand == "claude-cowork" ? "Claude for Mac application was not detected on your system (/Applications/Claude.app). You can download it from the official Claude website." : (pendingAgentCommand == "chatgpt" ? "ChatGPT for Mac application was not detected on your system (/Applications/ChatGPT.app). You can download it from the official OpenAI website." : (pendingAgentCommand == "dsh" ? "DeepSeek Harness app (/Applications/DeepSeek Harness.app) or binary 'dsh' was not detected on your system. You can download the official app or install the CLI via 'npm i -g @deepseek-ai/dsh'." : "Command '\(pendingAgentCommand)' was not detected on your system. You can install it following the official guide."))
                /*FIXME:
                pendingAgentCommand == "claude-cowork" ? "No se detectó la aplicación Claude for Mac en tu sistema (/Applications/Claude.app). Puedes descargarla desde la web oficial de Claude." : (pendingAgentCommand == "chatgpt" ? "No se detectó la aplicación ChatGPT for Mac en tu sistema (/Applications/ChatGPT.app). Puedes descargarla desde la web oficial de OpenAI." : (pendingAgentCommand == "dsh" ? "No se detectó la aplicación DeepSeek Harness (/Applications/DeepSeek Harness.app) ni el binario 'dsh' en tu sistema. Puedes descargar la app oficial o instalar el CLI con 'npm i -g @deepseek-ai/dsh'." : "No se detectó el comando '\(pendingAgentCommand)' en tu sistema. Puedes instalarlo siguiendo la guía oficial."))
                 */
            )
        }
        .alert(
            item: SplashService.$shared.portConflict
        ) { conflict in
            Alert(
                title: Text("⚠️ Port \(conflict.port) In Use" /*FIXME: "⚠️ Puerto \(conflict.port) en Uso" */),
                message: Text("Process '\(conflict.processName)' (PID \(conflict.pid)) is currently using port \(conflict.port).\n\nWould you like to switch to suggested free port \(conflict.suggestedPort) or free port \(conflict.port)?" /*FIXME: "El proceso '\(conflict.processName)' (PID \(conflict.pid)) está utilizando el puerto \(conflict.port).\n\n¿Deseas cambiar al puerto libre sugerido \(conflict.suggestedPort) o liberar el puerto \(conflict.port)?" */),
                primaryButton: .default(Text("Use port \(conflict.suggestedPort)" /*FIXME: "Usar puerto \(conflict.suggestedPort)" */)) {
                    portString = "\(conflict.suggestedPort)"
                    SplashService.shared.useSuggestedPort(conflict.suggestedPort)
                },
                secondaryButton: .destructive(Text("Free port \(conflict.port)" /*FIXME: "Liberar puerto \(conflict.port)" */)) {
                    SplashService.shared.resolvePortConflict(killProcess: true)
                }
            )
        }
        .alert(
            "Configure your shell" /*FIXME: "Configurar tu shell" */,
            isPresented: Binding(
                get: { SplashService.shared.pendingShellConfigPort != nil },
                set: { presented in
                    if !presented { SplashService.shared.pendingShellConfigPort = nil }
                }
            )
        ) {
            Button("Allow and configure" /*FIXME: "Permitir y configurar" */) {
                SplashService.shared.resolveShellConfigPrompt(allow: true)
            }
            Button("No thanks" /*FIXME: "No, gracias" */, role: .cancel) {
                SplashService.shared.resolveShellConfigPrompt(allow: false)
            }
        } message: {
            Text("Splash Monitor can add a line to your ~/.zshrc so agents launched from a terminal inherit port \(SplashService.shared.pendingShellConfigPort ?? SplashService.shared.activePort). This writes to your personal configuration; you can undo it from Settings. The ~/.splash_monitor_env file is always written." /*FIXME: "Splash Monitor puede añadir una línea a tu ~/.zshrc para que los agentes lanzados desde una terminal hereden el puerto \(Preferences.pendingShellConfigPort ?? Preferences.activePort). Escribirá en tu configuración personal; podrás deshacerlo desde Configuración. El fichero ~/.splash_monitor_env se escribe siempre." */)
        }
        .sheet(isPresented: $showingLogsSheet) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Splash Server Logs" /*FIXME: "Registros del Servidor Splash" */, systemImage: "terminal.fill")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button("Close" /*FIXME: "Cerrar" */) {
                        showingLogsSheet = false
                    }
                    .buttonStyle(.bordered)
                }
                
                let logs = SplashService.shared.readRecentServerLogs(lines: 100)
                ScrollView {
                    Text(logs.isEmpty ? "No logs available yet." /*FIXME: "No hay registros disponibles aún." */ : logs)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                }
                .frame(minHeight: 280, maxHeight: 420)
            }
            .padding(16)
            .frame(width: 580)
        }
    }
    
    // MARK: - 0. Dependency Warning Banner
    private var dependencyWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Splash CLI is not installed on this Mac" /*FIXME: "Splash CLI no está instalado en este Mac" */)
                    .font(.system(size: 11, weight: .bold))
                Text("brew install incoai/tap/splash")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                SplashService.shared.installSplashDependency()
            } label: {
                Text("Install Now" /*FIXME: "Instalar Ahora" */)
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - 1. Status Banner
    private var statusBannerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(SplashService.shared.isRunning ? Color.green : Color.red)
                    .frame(width: 9, height: 9)
                
                Text(SplashService.shared.isRunning ? "Splash Server Active" /*FIXME: "Servidor Splash Activo" */ : "Splash Server Stopped" /*FIXME: "Servidor Splash Detenido" */)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if let pid = SplashService.shared.activePid {
                    Text("PID: \(pid)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Running Model" /*FIXME: "Modelo en Ejecución" */)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(SplashService.shared.isRunning ? SplashService.shared.activeModel : "None (server stopped)" /*FIXME: "Ninguno (servidor apagado)" */)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Active Port" /*FIXME: "Puerto Activo" */)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("\(SplashService.shared.activePort)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        if Preferences.listenOnAllInterfaces, let ip = SplashService.shared.localNetworkIP {
                            Text("(LAN: \(ip))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            if SplashService.shared.isRunning {
                HStack(spacing: 8) {
                    Button(role: .destructive) {
                        SplashService.shared.stopServer()
                    } label: {
                        Label("Stop Server" /*FIXME: "Detener Servidor" */, systemImage: "stop.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        SplashService.shared.switchModel(to: SplashService.shared.activeModel)
                    } label: {
                        Label("Restart" /*FIXME: "Reiniciar" */, systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        if let url = URL(string: "http://127.0.0.1:\(SplashService.shared.activePort)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("WebUI", systemImage: "safari")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if let vision = SplashService.shared.status?.vision {
                        HStack(spacing: 4) {
                            Image(systemName: vision ? "eye.fill" : "doc.text.fill")
                                .font(.system(size: 9))
                            Text(vision ? "Vision Active" /*FIXME: "Visión Activa" */ : "Text Only" /*FIXME: "Solo Texto" */)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(vision ? Color.purple.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundColor(vision ? .purple : .orange)
                        .cornerRadius(4)
                        .help(vision
                            ? "Model supports vision modalities (images and PDF)." /*FIXME: "El modelo soporta modalidades de visión (imágenes y PDF)." */
                            : "Model is running in text/code only mode (--language-only)." /*FIXME: "El modelo está corriendo en modo solo texto/código (--language-only)." */)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - 2. Model Selection & Launch Section
    private var modelSelectionAndLaunchView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(SplashService.shared.isRunning ? "Switch Model or Restart" /*FIXME: "Cambiar Modelo o Reiniciar" */ : "Start Server with Model" /*FIXME: "Arrancar Servidor con Modelo" */)
                    .font(.system(size: 11, weight: .semibold))
                
                Spacer()
                
                Button {
                    SplashService.shared.restoreOptimalProfile()
                    portString = "\(Preferences.lastUsedPort)"
                    withAnimation {
                        showOptimalAppliedBanner = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            showOptimalAppliedBanner = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                        Text("Optimal Profile" /*FIXME: "Perfil Óptimo" */)
                    }
                    .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Restores high-performance recommended configuration for Apple M4 Max (64 GB): GDN BF16, Thinking 8K, SSD Cache, Context 128K, Port 8005, and LAN 0.0.0.0." /*FIXME: "Restaura la configuración recomendada de alto rendimiento para Apple M4 Max (64 GB): GDN BF16, Thinking 8K, Caché SSD, Contexto 128K, Puerto 8005 y LAN 0.0.0.0." */)
                
                Toggle("Custom" /*FIXME: "Personalizado" */, isOn: $isCustomModel)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10))
            }
            
            if showOptimalAppliedBanner {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                    Text("Optimal M4 Max (64 GB) profile restored: Port 8005, GDN BF16, Thinking 8K, Ctx 128K, SSD Cache!" /*FIXME: "¡Perfil óptimo M4 Max (64 GB) restaurado: Puerto 8005, GDN BF16, Thinking 8K, Ctx 128K, Caché SSD!" */)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
                    Spacer()
                }
                .padding(6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
                .transition(.opacity)
            }
            
            if isCustomModel {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hugging Face Identifier (owner/repo):" /*FIXME: "Identificador de Hugging Face (owner/repo):" */)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    TextField("e.g. mlx-community/Qwen3.8-27B-4bit" /*FIXME: "ej. mlx-community/Qwen3.8-27B-4bit" */, text: $customModelText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    
                    // P-03: aviso inmediato; el botón de arranque queda bloqueado mientras
                    // el identificador no sea válido, así el usuario no descubre el error
                    // después de intentar arrancar el motor.
                    if let error = customModelError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text(error)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.orange)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select model for inference:" /*FIXME: "Selecciona el modelo para la inferencia:" */)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if SplashService.shared.installedModels.isEmpty {
                        HStack {
                            Text("No models installed." /*FIXME: "No hay modelos instalados." */)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Use 'Models' tab to download" /*FIXME: "Usa la pestaña 'Modelos' para descargar" */)
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                        .padding(6)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                        .cornerRadius(6)
                    } else {
                        Picker("", selection: SplashService.$shared.selectedModelForLaunch) {
                            ForEach(SplashService.shared.installedModels) { model in
                                HStack {
                                    Text(model.shortName)
                                    Text("(\(model.formattedSize))")
                                        .foregroundColor(.secondary)
                                }
                                .tag(model.repoId)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }
            
            // Configuration Rows: Row 1 (Network & Port) & Row 2 (Inference Options & Action)
            VStack(spacing: 9) {
                // Fila 1: Puerto y Configuración de Red / Host
                HStack(spacing: 8) {
                    Text("Port:" /*FIXME: "Puerto:" */)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    
                    TextField("8000", text: $portString)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 65)
                    
                    Button {
                        let suggested = SplashService.shared.findSuggestedFreePort()
                        portString = "\(suggested)"
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Suggest free" /*FIXME: "Sugerir libre" */)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                    .fixedSize()
                    .help("Scan and automatically suggest a free port on your system" /*FIXME: "Escanear y sugerir automáticamente un puerto libre en tu sistema" */)
                    
                    if let p = Int(portString) {
                        if SplashService.shared.isPortListening(port: p) && (!SplashService.shared.isRunning || p != SplashService.shared.activePort) {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Text("In use" /*FIXME: "En uso" */)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.orange)
                                    .lineLimit(1)
                            }
                            .fixedSize()
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                                Text("Free" /*FIXME: "Libre" */)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.green)
                                    .lineLimit(1)
                            }
                            .fixedSize()
                        }
                    }
                    
                    Spacer()
                    
                    // Selector de Host / Red (127.0.0.1 vs 0.0.0.0)
                    Menu {
                        Button {
                            Preferences.listenOnAllInterfaces = false
                        } label: {
                            HStack {
                                Text("127.0.0.1 (Localhost)")
                                if !Preferences.listenOnAllInterfaces {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button {
                            Preferences.listenOnAllInterfaces = true
                        } label: {
                            HStack {
                                let label = SplashService.shared.localNetworkIP != nil
                                    ? "0.0.0.0 (LAN: \(SplashService.shared.localNetworkIP!))" /*FIXME: "0.0.0.0 (Acceso LAN: \(Preferences.localNetworkIP!))" */
                                    : "0.0.0.0 (LAN Access)" /*FIXME: "0.0.0.0 (Acceso LAN)" */
                                Text(label)
                                if Preferences.listenOnAllInterfaces {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: Preferences.listenOnAllInterfaces ? "network" : "lock.laptopcomputer")
                                .font(.system(size: 10))
                                .foregroundColor(Preferences.listenOnAllInterfaces ? .blue : .secondary)
                            let hostText: String = {
                                if Preferences.listenOnAllInterfaces {
                                    if let ip = SplashService.shared.localNetworkIP {
                                        return "0.0.0.0 (\(ip))"
                                    }
                                    return "0.0.0.0 (LAN)"
                                }
                                return "127.0.0.1 (Localhost)"
                            }()
                            Text(hostText)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("127.0.0.1 only accepts connections from this Mac. 0.0.0.0 exposes the server to your local network (LAN) for other devices to connect." /*FIXME: "127.0.0.1 solo acepta conexiones en este Mac. 0.0.0.0 expone el servidor a tu red local (LAN) para que otros equipos puedan conectarse." */)
                }
                
                // Fila 2: Modalidad, Contexto Máximo y Botón de Acción Principal
                HStack(spacing: 8) {
                    // Selector de Contexto Máximo (--max-context)
                    Menu {
                        Button {
                            Preferences.maxContext = "auto"
                        } label: {
                            HStack {
                                Text("Auto (by memory)" /*FIXME: "Automático (por memoria)" */)
                                if Preferences.maxContext == "auto" {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Divider()
                        ForEach(["16K", "32K", "64K", "128K", "256K", "512K", "1M"], id: \.self) { ctx in
                            Button {
                                Preferences.maxContext = ctx
                            } label: {
                                HStack {
                                    Text(ctx == "1M" ? "1M tokens (YaRN)" : "\(ctx) tokens")
                                    if Preferences.maxContext == ctx {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10))
                                .foregroundColor(.purple)
                            Text(Preferences.maxContext == "auto" ? "Ctx: Auto" : "Ctx: \(Preferences.maxContext)")
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Maximum context token limit (--max-context) for Splash inference." /*FIXME: "Límite máximo de tokens de contexto (--max-context) para la inferencia de Splash." */)
                    
                    Divider()
                        .frame(height: 14)
                    
                    // Selector de Modalidad (Visión vs Solo Texto / --language-only)
                    Menu {
                        Button {
                            Preferences.languageOnly = false
                        } label: {
                            HStack {
                                Text("👁️ Vision + Text (Standard)" /*FIXME: "👁️ Visión + Texto (Normal)" */)
                                if !Preferences.languageOnly {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button {
                            Preferences.languageOnly = true
                        } label: {
                            HStack {
                                Text("📝 Text / Code Only (--language-only)" /*FIXME: "📝 Solo Texto / Código (--language-only)" */)
                                if Preferences.languageOnly {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: Preferences.languageOnly ? "doc.text" : "eye")
                                .font(.system(size: 10))
                                .foregroundColor(Preferences.languageOnly ? .orange : .teal)
                            Text(Preferences.languageOnly ? "Text Only" /*FIXME: "Solo Texto" */ : "Vision" /*FIXME: "Visión" */)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Configures whether Splash should initialize multimodal image support or text-only mode (--language-only, required for Coder models without mmproj projectors)." /*FIXME: "Configura si Splash debe inicializar soporte multimodal de imágenes o modo solo texto (--language-only, requerido para modelos Coder sin proyector mmproj)." */)
                    
                    Divider()
                        .frame(height: 14)
                    
                    // Selector de Liberación de Memoria por Inactividad (--idle-release)
                    Menu {
                        ForEach([
                            ("1m", "1 min (Fast saving)" /*FIXME: "1 min (Ahorro rápido)" */),
                            ("2m", "2 min (Aggressive)" /*FIXME: "2 min (Agresivo)" */),
                            ("5m", "5 min (Balanced)" /*FIXME: "5 min (Equilibrado)" */),
                            ("10m", "10 min (Default)" /*FIXME: "10 min (Por defecto)" */),
                            ("30m", "30 min (Extended)" /*FIXME: "30 min (Extendido)" */),
                            ("off", "Disabled (Always in RAM)" /*FIXME: "Desactivado (Siempre en RAM)" */)
                        ], id: \.0) { item in
                            Button {
                                Preferences.idleRelease = item.0
                            } label: {
                                HStack {
                                    Text(item.1)
                                    if Preferences.idleRelease == item.0 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text("Idle: \(Preferences.idleRelease)" /*FIXME: "Reposo: \(Preferences.idleRelease)" */)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Idle time before unwiring and releasing Metal unified memory weights (--idle-release). Weights are restored automatically on incoming requests." /*FIXME: "Tiempo de inactividad antes de desvincular y liberar la memoria unificada de Metal (--idle-release). Cuando llega una nueva consulta, Splash recarga los pesos al vuelo." */)
                    
                    Divider()
                        .frame(height: 14)
                    
                    // Selector de Límite de Memoria (--max-memory)
                    Menu {
                        Button {
                            Preferences.maxMemory = "auto"
                        } label: {
                            HStack {
                                Text("Auto (unlimited)" /*FIXME: "Automático (sin límite)" */)
                                if Preferences.maxMemory == "auto" {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Divider()
                        ForEach(["16G", "24G", "28G", "32G", "40G", "48G", "64G"], id: \.self) { mem in
                            Button {
                                Preferences.maxMemory = mem
                            } label: {
                                HStack {
                                    Text("\(mem) Metal")
                                    if Preferences.maxMemory == mem {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 10))
                                .foregroundColor(.indigo)
                            Text(Preferences.maxMemory == "auto" ? "RAM: Auto" : "RAM: \(Preferences.maxMemory)")
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Maximum Metal memory budget (--max-memory) to prevent hogging all unified memory." /*FIXME: "Presupuesto máximo de memoria Metal (--max-memory) para evitar acaparar toda la memoria unificada del Mac." */)
                    
                    Spacer()
                    
                    let targetModel = isCustomModel ? customModelText.trimmingCharacters(in: .whitespacesAndNewlines) : SplashService.shared.selectedModelForLaunch
                    let targetPort = Int(portString) ?? SplashService.shared.activePort
                    let isSameAsActive = (targetModel == SplashService.shared.activeModel && SplashService.shared.isRunning)

                    if SplashService.shared.isStartingServer {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Starting Server..." /*FIXME: "Iniciando Servidor..." */)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                        .fixedSize()
                    } else if SplashService.shared.isRunning {
                        if isSameAsActive {
                            Button {
                                SplashService.shared.switchModel(to: targetModel)
                            } label: {
                                Label("Restart" /*FIXME: "Reiniciar" */, systemImage: "arrow.clockwise")
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .fixedSize()
                        } else {
                            Button {
                                SplashService.shared.startServer(model: targetModel, port: targetPort)
                            } label: {
                                Label("Switch Model" /*FIXME: "Cambiar Modelo" */, systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .controlSize(.regular)
                            .disabled(targetModel.isEmpty || customModelError != nil || customFlagsError != nil)
                            .fixedSize()
                        }
                    } else {
                        Button {
                            SplashService.shared.startServer(model: targetModel, port: targetPort)
                        } label: {
                            Label("Start Server" /*FIXME: "Arrancar Servidor" */, systemImage: "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.regular)
                        .disabled(targetModel.isEmpty || customFlagsError != nil)
                        .fixedSize()
                    }
                }
            }
            
            // Fila 3: Optimizaciones Splash 1.3.2+ (Estado GDN BF16, Presupuesto Thinking y Caché SSD)
            HStack(spacing: 8) {
                // Selector de Formato de Estado Recurrente GDN (--state-format)
                Menu {
                    Button {
                        Preferences.stateFormat = "fp32"
                    } label: {
                        HStack {
                            Text("FP32 (Standard, maximum fidelity)" /*FIXME: "FP32 (Estándar, máxima fidelidad)" */)
                            if Preferences.stateFormat == "fp32" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button {
                        Preferences.stateFormat = "bf16"
                    } label: {
                        HStack {
                            Text("BF16 (-50% RAM in GDN states)" /*FIXME: "BF16 (-50% RAM en estados GDN)" */)
                            if Preferences.stateFormat == "bf16" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.pink)
                        Text(Preferences.stateFormat.uppercased() == "BF16" ? "GDN: BF16 (-50%)" : "GDN: FP32")
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Storage format for GDN recurrent states (--state-format). BF16 halves state memory in RAM (from 153 to 81 MiB on 27B) while keeping computation in FP32." /*FIXME: "Formato de almacenamiento para los estados recurrentes GDN (--state-format). BF16 reduce a la mitad el tamaño del estado en RAM (de 153 MiB a 81 MiB en 27B) manteniendo el cálculo en FP32." */)
                
                Divider()
                    .frame(height: 14)
                
                // Selector de Presupuesto de Razonamiento (--thinking-token-budget)
                Menu {
                    Button {
                        Preferences.thinkingTokenBudget = "auto"
                    } label: {
                        HStack {
                            Text("Uncapped (No limit)" /*FIXME: "Ilimitado (Sin tope)" */)
                            if Preferences.thinkingTokenBudget == "auto" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Divider()
                    ForEach(["2K", "4K", "8K", "16K", "32K"], id: \.self) { budget in
                        Button {
                            Preferences.thinkingTokenBudget = budget
                        } label: {
                            HStack {
                                Text("\(budget) tokens")
                                if Preferences.thinkingTokenBudget == budget {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button {
                        Preferences.thinkingTokenBudget = "off"
                    } label: {
                        HStack {
                            Text("Disabled (-1)" /*FIXME: "Desactivado (-1)" */)
                            if Preferences.thinkingTokenBudget == "off" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Text(Preferences.thinkingTokenBudget == "auto" ? "Thinking: Auto" : (Preferences.thinkingTokenBudget == "off" ? "Thinking: Off" : "Thinking: \(Preferences.thinkingTokenBudget)"))
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Maximum reasoning / thinking token budget (--thinking-token-budget) for chain-of-thought models." /*FIXME: "Presupuesto máximo de tokens de razonamiento / pensamiento (--thinking-token-budget) para modelos con cadena de pensamiento." */)
                
                Divider()
                    .frame(height: 14)
                
                // Toggle Caché SSD Persistente (--persistent-cache)
                Toggle(isOn: Preferences.$persistentCache) {
                    HStack(spacing: 4) {
                        Image(systemName: Preferences.persistentCache ? "internaldrive.fill" : "internaldrive")
                            .font(.system(size: 10))
                            .foregroundColor(Preferences.persistentCache ? .green : .secondary)
                        Text("Persistent SSD Cache" /*FIXME: "Caché SSD Persistente" */)
                            .font(.system(size: 10))
                    }
                }
                .toggleStyle(.checkbox)
                .help("Keeps prefix cache on SSD across restarts (--persistent-cache). In Splash 1.3.2+ SSD cache is on by default in 'auto' mode and adjusts to disk space." /*FIXME: "Mantiene la caché de prefijos en SSD a través de reinicios (--persistent-cache). En Splash 1.3.2+ la caché SSD viene activada en modo 'auto' y se adapta al disco." */)
                
                Divider()
                    .frame(height: 14)
                
                // Selector de Verificación de Borrador MoE (--verify-rows)
                Menu {
                    Button {
                        Preferences.verifyRows = "auto"
                    } label: {
                        HStack {
                            Text("Auto (Adaptive, +13–42% speed)" /*FIXME: "Auto (Adaptativa, +13–42% vel)" */)
                            if Preferences.verifyRows == "auto" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button {
                        Preferences.verifyRows = "all"
                    } label: {
                        HStack {
                            Text("All (All rows, Deterministic)" /*FIXME: "All (Todas las filas, Determinista)" */)
                            if Preferences.verifyRows == "all" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 10))
                            .foregroundColor(.indigo)
                        Text(Preferences.verifyRows == "all" ? "Verify: All" : "Verify: Auto")
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Speculative draft verification mode (--verify-rows). 'auto' adapts verification boosting decode speed. 'all' verifies all rows for determinism." /*FIXME: "Verificación de tokens de borrador especulativos (--verify-rows). 'auto' adapta la verificación aumentando la velocidad de decodificación. 'all' verifica todas las filas para determinismo." */)
                
                Spacer()
            }
            .padding(.top, 2)
            
            // Flags CLI adicionales (ej. --no-webui --max-cache-disk 50GB)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("Additional CLI flags:" /*FIXME: "Flags CLI adicionales:" */)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let err = customFlagsError {
                        Text(err)
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
                
                TextField(
                    "e.g. --no-webui --max-cache-disk 50GB" /*FIXME: "Ej: --no-webui --max-cache-disk 50GB" */,
                    text: Preferences.$customServerFlags
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10, design: .monospaced))
                .help("Additional flags and options passed directly at the end of the 'splash serve' command." /*FIXME: "Flags y opciones adicionales que se pasan directamente al final del comando 'splash serve'." */)
            }
            .padding(.top, 2)
            
            // Background / Silent mode & logs options
            HStack {
                Toggle(isOn: Preferences.$runInBackground) {
                    HStack(spacing: 4) {
                        Image(systemName: Preferences.runInBackground ? "speaker.slash.fill" : "terminal")
                            .font(.system(size: 10))
                        Text("Run silently in background" /*FIXME: "Ejecutar en silencio (segundo plano)" */)
                            .font(.system(size: 11))
                    }
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Button {
                    showingLogsSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Logs" /*FIXME: "Ver Registros" */)
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .onChange(of: portString) { _, newValue in
            guard let newPort = Int(newValue), newPort > 1024, newPort <= 65535 else { return }
            // If server is running on a different port, auto-restart on new port
            if SplashService.shared.isRunning && newPort != SplashService.shared.activePort {
                SplashService.shared.startServer(model: SplashService.shared.activeModel, port: newPort)
            }
        }
    }
    
    // MARK: - 3. Coding Agents Launcher
    private var agentsLauncherView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Connect Coding Agents" /*FIXME: "Conectar Agentes de Código" */)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !SplashService.shared.isRunning {
                    HStack(spacing: 3) {
                        Image(systemName: "info.circle")
                        Text("Server offline" /*FIXME: "Servidor inactivo" */)
                    }
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                }
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                AgentButton(
                    name: "Claude Code",
                    icon: "brain.head.profile",
                    command: "claude",
                    isInstalled: SplashService.shared.isAgentInstalled(agent: "claude"),
                    isServerRunning: SplashService.shared.isRunning
                ) {
                    handleAgentLaunch(name: "Claude Code", command: "claude")
                }
                
                AgentButton(
                    name: "Claude Cowork",
                    icon: "person.2.badge.gearshape",
                    command: "claude-cowork",
                    subtitle: "Claude for Mac",
                    isInstalled: SplashService.shared.isAgentInstalled(agent: "claude-cowork"),
                    isServerRunning: SplashService.shared.isRunning
                ) {
                    handleAgentLaunch(name: "Claude Cowork", command: "claude-cowork")
                }
                
                AgentButton(
                    name: "ChatGPT Desktop",
                    icon: "sparkles",
                    command: "chatgpt",
                    subtitle: "Codex & OWL (macOS)",
                    isInstalled: SplashService.shared.isAgentInstalled(agent: "chatgpt"),
                    isServerRunning: SplashService.shared.isRunning
                ) {
                    handleAgentLaunch(name: "ChatGPT Desktop", command: "chatgpt")
                }
                
                AgentButton(
                    name: "OpenCode",
                    icon: "chevron.left.forwardslash.chevron.right",
                    command: "opencode",
                    isInstalled: SplashService.shared.isAgentInstalled(agent: "opencode"),
                    isServerRunning: SplashService.shared.isRunning
                ) {
                    handleAgentLaunch(name: "OpenCode", command: "opencode")
                }
                
                AgentButton(
                    name: "Codex",
                    icon: "terminal",
                    command: "codex",
                    isInstalled: SplashService.shared.isAgentInstalled(agent: "codex"),
                    isServerRunning: SplashService.shared.isRunning
                ) {
                    handleAgentLaunch(name: "Codex", command: "codex")
                }
                
                AgentButton(
                    name: "Hermes",
                    icon: "bolt.horizontal",
                    command: "hermes",
                    isInstalled: SplashService.shared.isAgentInstalled(agent: "hermes"),
                    isServerRunning: SplashService.shared.isRunning
                ) {
                    handleAgentLaunch(name: "Hermes", command: "hermes")
                }
                
                AgentButton(
                    name: "Pi Agent",
                    icon: "character.cursor.ibeam",
                    command: "pi",
                    subtitle: "pi.dev (Splash 1.3+)",
                    isInstalled: SplashService.shared.isAgentInstalled(agent: "pi"),
                    isServerRunning: SplashService.shared.isRunning
                ) {
                    handleAgentLaunch(name: "Pi Agent", command: "pi")
                }
                
                AgentButton(
                    name: "DeepSeek Harness",
                    icon: "cpu.fill",
                    command: "dsh",
                    subtitle: "App / dsh (DeepSeek AI)",
                    isInstalled: SplashService.shared.isAgentInstalled(agent: "dsh"),
                    isServerRunning: SplashService.shared.isRunning
                ) {
                    handleAgentLaunch(name: "DeepSeek Harness", command: "dsh")
                }
            }
        }
    }
    
    private func handleAgentLaunch(name: String, command: String) {
        pendingAgentName = name
        pendingAgentCommand = command
        
        guard SplashService.shared.isRunning else {
            showingAgentOfflineAlert = true
            return
        }
        
        if !SplashService.shared.isAgentInstalled(agent: command) {
            showingAgentNotInstalledAlert = true
            return
        }
        
        SplashService.shared.launchAgent(agent: command)
    }
    
    // MARK: - 4. API Endpoints & Copy Helpers
    private var apiEndpointsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Integration Endpoints" /*FIXME: "Endpoints de Integración" */)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let msg = copiedMessage {
                    Text(msg)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            
            HStack(spacing: 8) {
                Button {
                    let host = SplashService.shared.preferredHostOrIP
                    copyToClipboard("http://\(host):\(SplashService.shared.activePort)/v1")
                    showCopied("OpenAI URL copied!" /*FIXME: "¡Copiado OpenAI URL!" */)
                } label: {
                    Label("Copy OpenAI URL" /*FIXME: "Copiar OpenAI URL" */, systemImage: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    let host = SplashService.shared.preferredHostOrIP
                    copyToClipboard("export OPENAI_BASE_URL=http://\(host):\(SplashService.shared.activePort)/v1\nexport ANTHROPIC_BASE_URL=http://\(host):\(SplashService.shared.activePort)")
                    showCopied("Env Vars copied!" /*FIXME: "¡Copiado Env Vars!" */)
                } label: {
                    Label("Copy Env Vars" /*FIXME: "Copiar Env Vars" */, systemImage: "terminal")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
    
    private func showCopied(_ message: String) {
        withAnimation {
            copiedMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                if copiedMessage == message {
                    copiedMessage = nil
                }
            }
        }
    }
}

struct AgentButton: View {
    let name: String
    let icon: String
    let command: String
    var subtitle: String? = nil
    let isInstalled: Bool
    let isServerRunning: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isServerRunning ? .accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.system(size: 11, weight: .medium))
                        
                        Circle()
                            .fill(isInstalled ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 5, height: 5)
                    }
                    
                    Text(subtitle ?? "splash \(command)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 9))
                    .foregroundColor(isServerRunning ? .secondary : .secondary.opacity(0.4))
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .opacity(isServerRunning ? 1.0 : 0.75)
        }
        .buttonStyle(.plain)
    }
}
