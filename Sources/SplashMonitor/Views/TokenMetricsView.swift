import SwiftUI

public struct TokenMetricsView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    
    public init(service: SplashService) {
        self.service = service
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Speed Hero Cards
            HStack(spacing: 12) {
                MetricCard(
                    title: tr(es: "DECODE (Salida)", en: "DECODE (Output)"),
                    value: "\(service.formattedDecodeSpeed)",
                    unit: "tok/s",
                    subtitle: "\(service.formattedTokensDecode) \(tr(es: "tokens", en: "tokens"))",
                    icon: "bolt.fill",
                    tint: .green
                )
                
                MetricCard(
                    title: tr(es: "PREFILL (Entrada)", en: "PREFILL (Input)"),
                    value: "\(service.formattedPrefillSpeed)",
                    unit: "tok/s",
                    subtitle: "\(service.formattedTokensPrefill) \(tr(es: "tokens", en: "tokens"))",
                    icon: "arrow.down.forward.circle.fill",
                    tint: .blue
                )
            }
            
            // Sparkline / Mini Speed History
            if !service.speedHistory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tr(es: "Historial de Velocidad (Decode)", en: "Decode Speed History"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(service.formattedDecodeSpeed) tok/s \(tr(es: "actual", en: "current"))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    SpeedMiniChart(data: service.speedHistory)
                        .frame(height: 38)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        .cornerRadius(6)
                }
                .padding(8)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                .cornerRadius(8)
            }
            
            // Efficiency Metrics (Prefix Cache & DFlash Speculative Decoding)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    MiniStatRow(
                        title: tr(es: "Caché KV Reutilizado", en: "Reused KV Cache"),
                        value: service.formattedTokensReused,
                        detail: "\(service.formattedCacheHitRate) \(tr(es: "acierto", en: "hit rate"))",
                        icon: "arrow.triangle.2.circlepath",
                        tint: .cyan
                    )
                    
                    MiniStatRow(
                        title: tr(es: "Especulación DFlash 2", en: "DFlash 2 Speculation"),
                        value: service.formattedDraftAcceptanceRate,
                        detail: tr(es: "Aceptación draft", en: "Draft acceptance"),
                        icon: "sparkles",
                        tint: .orange
                    )
                }
                
                HStack(spacing: 12) {
                    MiniStatRow(
                        title: tr(es: "Latencia TTFT (p50)", en: "Latency TTFT (p50)"),
                        value: String(format: "%.0f ms", service.status?.metrics?.ttftMs?.p50 ?? 0.0),
                        detail: tr(es: "Primer token", en: "Time to first token"),
                        icon: "timer",
                        tint: .purple
                    )
                    
                    MiniStatRow(
                        title: tr(es: "Latencia ITL (p50)", en: "Latency ITL (p50)"),
                        value: String(format: "%.1f ms", service.status?.metrics?.itlMs?.p50 ?? 0.0),
                        detail: tr(es: "Entre tokens", en: "Inter-token latency"),
                        icon: "waveform.path.ecg",
                        tint: .indigo
                    )
                }
            }
            
            // Hardware & Metal Memory Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label {
                        Text(tr(es: "Memoria Unificada Metal", en: "Unified Metal Memory"))
                            .font(.system(size: 11, weight: .medium))
                    } icon: {
                        Image(systemName: "memorychip")
                            .foregroundColor(.pink)
                    }
                    
                    Spacer()
                    
                    Text("\(service.formattedMemoryUsed) / \(service.formattedMemoryLimit)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .separatorColor))
                            .frame(height: 7)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: service.memoryUsageRatio > 0.85 ? [.orange, .red] : [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(service.memoryUsageRatio)), height: 7)
                    }
                }
                .frame(height: 7)
                
                if let dev = service.status?.memoryPlan?.device {
                    HStack {
                        Text("\(dev.deviceName ?? "Apple Silicon") · \(dev.gpuCoreCount ?? 0) Cores GPU")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        if let thermal = service.status?.thermalState {
                            Text("\(tr(es: "Térmico", en: "Thermal")): \(thermal.capitalized)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(thermal == "nominal" ? .green : (thermal == "fair" ? .yellow : .orange))
                            Text("·")
                                .foregroundColor(.secondary)
                        }
                        Text("\(tr(es: "Presión", en: "Pressure")): \(service.status?.memoryPressure?.capitalized ?? "Normal")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(service.status?.memoryPressure == "normal" ? .green : .orange)
                    }
                }
                
                // Estado de Pesos Metal y Presión del Sistema macOS
                HStack(spacing: 8) {
                    if let weights = service.status?.weights {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(weights.released == true ? Color.orange : Color.green)
                                .frame(width: 6, height: 6)
                            if weights.released == true {
                                Text(tr(es: "Pesos Liberados (Metal Desvinculado)", en: "Weights Released (Metal Unwired)"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.orange)
                            } else {
                                Text(tr(es: "Pesos Activos en VRAM", en: "Weights Active in VRAM"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            if let restores = weights.restores, restores > 0 {
                                Text("· \(restores) \(tr(es: "recuperaciones", en: "restores"))")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Aviso o Botón de Liberación Manual
                    if service.isRunning {
                        Button {
                            service.releaseMemoryNow()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 9))
                                Text(tr(es: "Liberar Memoria", en: "Free Memory"))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help(tr(
                            es: "Detiene el servidor y descarga inmediatamente toda la memoria unificada de Metal utilizada por el modelo.",
                            en: "Stops the server and immediately unloads all Metal unified memory used by the model."
                        ))
                    }
                }
                
                if let notice = service.memoryReliefNotice {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                        Text(notice)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            service.memoryReliefNotice = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(4)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(4)
                }
                
                if let ane = service.status?.aneFfn, let state = ane.state {
                    HStack {
                        Label {
                            Text(tr(es: "Apple Neural Engine (ANE)", en: "Apple Neural Engine (ANE)"))
                                .font(.system(size: 10, weight: .medium))
                        } icon: {
                            Image(systemName: "cpu")
                                .font(.system(size: 10))
                                .foregroundColor(.indigo)
                        }
                        Spacer()
                        if let share = ane.share {
                            Text("\(state.capitalized) · \(Int(share * 100))% share")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        } else {
                            Text(state.capitalized)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(10)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .cornerRadius(8)
            
            // Connected Applications Quick Bar
            if service.isRunning {
                HStack(spacing: 8) {
                    Image(systemName: "app.connected.to.app.below.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    
                    let activeApps = service.connectedApps.filter { $0.status == .active || $0.status == .idle }
                    if activeApps.isEmpty {
                        Text(tr(es: "Apps conectadas:", en: "Connected apps:"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(tr(es: "Ninguna activa (escuchando :\(service.activePort))", en: "None active (listening :\(service.activePort))"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text(tr(es: "Apps conectadas (\(activeApps.count)):", en: "Connected apps (\(activeApps.count)):"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(activeApps) { app in
                                    HStack(spacing: 4) {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: app.category.iconName)
                                                .font(.system(size: 9))
                                                .foregroundColor(.purple)
                                        }
                                        Text(app.name)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(5)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(8)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(6)
            }
            
            // Requests Overview
            let reqs = service.status?.requests
            HStack(spacing: 14) {
                RequestPill(title: tr(es: "Completadas", en: "Completed"), count: reqs?.completed ?? 0, color: .green)
                RequestPill(title: tr(es: "En Cola", en: "Queued"), count: service.status?.scheduler?.queued ?? 0, color: .blue)
                RequestPill(title: tr(es: "Canceladas", en: "Cancelled"), count: reqs?.cancelled ?? 0, color: .gray)
                RequestPill(title: tr(es: "Fallos", en: "Failed"), count: reqs?.failed ?? 0, color: .red)
            }
            .font(.system(size: 10))
            
            // JMGREP Developers signature
            HStack(spacing: 5) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                Text("JMGREP Developers")
                    .font(.system(size: 10, weight: .bold))
                Text("By Joan Gregorio Pérez - Ingeniero en software")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Subcomponents

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let icon: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

struct MiniStatRow: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(tint)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .cornerRadius(8)
    }
}

struct RequestPill: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(title):")
                .foregroundColor(.secondary)
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

struct SpeedMiniChart: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geo in
            let maxVal = max(data.max() ?? 10.0, 10.0)
            Path { path in
                guard data.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(data.count - 1)
                for (index, val) in data.enumerated() {
                    let normY = 1.0 - CGFloat(val / maxVal)
                    let pt = CGPoint(x: CGFloat(index) * stepX, y: max(2, min(geo.size.height - 2, normY * geo.size.height)))
                    if index == 0 {
                        path.move(to: pt)
                    } else {
                        path.addLine(to: pt)
                    }
                }
            }
            .stroke(
                LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
