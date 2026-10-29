# AGENTS.md — Reviewer Guide for Splash Monitor

Guide for the 4 sequential review workers reviewing this whole app. Do not
re-explore what is documented here; this file is the map.

## Overview

**Splash Monitor** is a native macOS menu-bar / window app (SwiftUI + AppKit)
that provides a GUI for Inco AI's **Splash** local-inference engine (installed
via `brew install incoai/tap/splash`). It is independent software, *not*
affiliated with Inco AI. Core features:

- Real-time token dashboard (prefill/decode `tok/s`, KV-cache hit rate, TTFT/ITL, ANE ratio) polled from the engine's `/status` HTTP endpoint
- Metal unified-memory gauge + macOS kernel memory-pressure alerts with on-demand flush
- Model manager (local catalog + Hugging Face `incoai` / `mlx-community` / NVIDIA explorer)
- Server controls (start/stop, model hot-swap, port/LAN bind, advanced flags) and **code agent launchers** (Claude Code, OpenCode, Codex, Hermes, Pi Agent, DeepSeek Harness)
- Connected-clients detection (apps talking to the inference port)
- Menu bar extra with 4 display modes (icon / speed / tokens / model) and menu-bar-only mode

The app is **not sandboxed** (`ENABLE_APP_SANDBOX = NO`) — it shells out to
launch/kill the `splash` CLI, polls localhost, and introspects network
connections.

## Architecture

```
SplashMonitorApp (@main) ── WindowGroup "main" ──> MainWindowView (sidebar, 7 tabs)
   └── MenuBarExtra ────────────────> MenuBarView
AppDelegate (NSApplicationDelegateAdaptor): activation policy (accessory/regular),
Cmd+Q interception for menu-bar-only mode, kills server on real quit.

MainWindowView tabs (SidebarItem): .dashboard, .connectedApps, .models,
.server, .modelTesting, .settings, .about
   └─> TokenMetricsView / ConnectedAppsView / ModelManagerView /
       ServerControlView / ModelTestingView / (inline settings) / AboutView
```

- **`SplashService`** (`Services/SplashService.swift`, **2,992 lines — the god object**)
  is the heart: `@Observable` class, singleton via `SplashService.shared`
  (declared `@Bindable private(set) static var` at l.26 — views obtain bindings
  as `SplashService.$shared.property`), polls
  `/status` via a `StatusTransport` protocol (production:
  `URLSessionStatusTransport`; tests inject `StubStatusTransport`), manages server
  lifecycle via a `ServerTerminating` protocol (production:
  `HardenedServerTerminator`). Constructor-injectable for tests.
- **`Preferences`** is a plain `enum` of static `@AppStorage` vars — the sole
  persistent-preference mechanism.
- **`SplashStatus`** (`Models/SplashStatus.swift`) mirrors the engine's real
  `/status` JSON (snake_case `Codable` structs: `MemoryPlan`, `MemoryGovernor`,
  metrics, ANE/FFN state, etc.). Tests validate it against a captured real
  1.0.2-engine payload.
- **Services** are mostly stateless `enum` namespaces of static functions
  (`SplashPaths`, `ShellEnvironment`, `ServerCLIValidator`, `ProcessIntrospection`,
  `ClientTerminationPolicy`…) — easy to unit test, and that is what the tests do.
- **Version** is the single source of truth in `Services/Version.swift`
  (`SplashVersion.current = "1.0.10-beta"`, bundle id `do.jmgrep.splashmonitor`);
  the release scripts extract it from that literal with `sed`.
- **Localization**: one string catalog `Splash/Resources/Localizable.xcstrings`
  (670 keys: 533 carry an `es` translation, 9 explicit `en`, **zero `fr`** —
  French falls back to English); `STRING_CATALOG_GENERATE_SYMBOLS` is ON, so
  views use `LocalizedStringResource` symbols. Interpolation keys are
  printf-style templates (`%lld`/`%d`/`%@`); a literal `%` in the source is
  written unescaped (the compiler doubles it to `%%` in the key). Note: code
  and test comments are a mix of English and Spanish.

## File Index

### Splash/ (33 Swift files)

| File | Lines | Role |
|---|---|---|
| `SplashMonitorApp.swift` | ~194 | `@main` App: WindowGroup + MenuBarExtra scene; `AppDelegate` (activation policy, Cmd+Q interception, quit handling) |
| **Models** | | |
| `Models/SplashStatus.swift` | 345 | Codable mirror of the engine `/status` payload (metrics, memory plan/governor, ANE, instance info, cache, requests) |
| `Models/ConnectedApp.swift` | 100 | `ConnectedApp` model + `AppCategory` / `AppConnectionStatus` enums |
| **Services** | | |
| `Services/SplashService.swift` | 2992 | **Core service**: polling, server start/stop, model ops, agent launches, memory flush; `@Observable`, injectable transport/terminator; `PortConflictInfo` |
| `Services/ModelDiagnosticService.swift` | 570 | `@Observable @MainActor` for model install/download diagnostics + telemetry |
| `Services/ModelIDValidator.swift` | 121 | Validates Hugging Face model IDs (owner/repo, GGUF, NVFP4/FP8) |
| `Services/ServerTermination.swift` | 145 | `ServerTerminating` protocol, `CommandRunner`, `HardenedServerTerminator`, `ClientTerminationPolicy`, `CommandResult` |
| `Services/ProcessIntrospection.swift` | 103 | `EstablishedConnection`, engine-identity detection, kill-target resolution from process tables |
| `Services/SystemMemoryPressureSentinel.swift` | 102 | Kernel memory-pressure monitoring + level enum |
| `Services/ServerCLIValidator.swift` | 95 | Validates splash CLI advanced flags before launching |
| `Services/ShellEnvironment.swift` | 84 | Resolves the user's shell env for launched agents, consent state |
| `Services/NotificationService.swift` | 111 | User notifications (pressure alerts, download events) |
| `Services/Version.swift` | 122 | `SplashVersion` (single version/bundle-id/build-number source) + `SemanticVersion` comparison |
| `Services/SplashPaths.swift` | 61 | Resolves the `splash` binary and data-dir paths |
| `Services/ModelSizeCache.swift` | 55 | Disk-footprint cache for models |
| `Services/Preferences.swift` | 47 | Static `@AppStorage` preference keys (port, refresh interval, menu bar mode, etc.) |
| `Services/AutoLaunchService.swift` | 50 | Launch-at-login toggle |
| `Services/ServeLocks.swift` | 41 | `ServeLockStore`: lock files preventing double-serve |
| `Services/NetworkInterfaceHelper.swift` | 39 | LAN bind interface discovery |
| `Services/StatusTransport.swift` | 28 | `StatusTransport` protocol + `URLSessionStatusTransport` (seam for tests) |
| **Views** | | |
| `Views/MainWindowView.swift` | 1115 | Root window: 7-tab sidebar navigation, `SidebarItem` enum, wires tab views |
| `Views/ServerControlView.swift` | 1242 | Server start/stop UI, port/bind/flags, **agent launcher buttons** (`AgentButton`), endpoint copy |
| `Views/ConnectedAppsView.swift` | 755 | Connected-clients list: `ConnectedAppCard`, `StatBadgeCard`, `IntegrationGuideCard` |
| `Views/ModelManagerView.swift` | 437 | Local model catalog + HF explorer, download UI, GGUF/gated guidance |
| `Views/TokenMetricsView.swift` | 728 | Dashboard: `MetricCard`, `MiniStatRow`, `RequestPill`, `SpeedMiniChart` sparklines |
| `Views/ModelTestingView.swift` | 617 | Model benchmarking/testing UI |
| `Views/MenuBarView.swift` | 345 | Menu bar extra window: 4 display modes, 1-click memory flush |
| `Views/DependencyInstallView.swift` | 228 | Splash-engine install/diagnostic UI (`DiagnosticBadge`) |
| `Views/AboutView.swift` | 187 | About/credits window (`TechBadge`) |
| `Views/InstallConsole.swift` | 267 | Shared install/download log console (`formatDownloadProgress`), gated-model guidance |
| `Views/ClipboardCopy.swift` | 45 | `CopiedFlash` copied-flash state via `.task(id:)` |
| `Views/PortConflictAlertModifier.swift` | 67 | Shared 27-gated port-conflict alert: macOS 27 `alert(_:item:)` + 26.x fallback |
| `Views/AppIconView.swift` | 47 | Renders the app icon in views |

Resources: `Resources/Localizable.xcstrings` (string catalog),
`Resources/App Icon.icon/` (icon assets).

### SplashTests/ (19 files, **Swift Testing**, 199 tests, heavy Spanish comments)

| File | Lines | What it tests |
|---|---|---|
| `TestSupport.swift` | 215 | `TempDirectory` (isolated temp dirs), `StubStatusTransport`, `RecordingServerTerminator` doubles, `Fixtures` |
| `ServerOptionsTests.swift` | 311 | CLI flag generation for server start options |
| `ScreenshotGeneratorTests.swift` | 283 | Renders views via **NSHostingView** (not ImageRenderer) with mock `/status` payloads; **skipped unless `SPLASH_GENERATE_SCREENSHOTS=1` env is set** |
| `PollingTests.swift` | 273 | Polling lifecycle with injected transport (dead-poll prevention, "P-02/H-01" probes) |
| `ServerCLIValidatorTests.swift` | 144 | Flag validation rules |
| `ShellEnvironmentTests.swift` | 156 | Shell env resolution |
| `ModelIDValidatorTests.swift` | 127 | Model ID validation |
| `StatusModelTests.swift` | 80 | Codable contract vs real 1.0.2 engine payload ("Sonda V-4") |
| `ProcessIntrospectionTests.swift` | 106 | Connection/process introspection, kill-target resolution |
| `VersionTests.swift` | 103 | `SemanticVersion` parsing/ordering (fixes "P-07/H-08" lexicographic bug) |
| `ModelDiagnosticTests.swift` | 79 | Diagnostics service logic |
| `ClientTerminationPolicyTests.swift` | 96 | Policy for killing client vs engine processes |
| `SystemMemoryPressureTests.swift` | 100 | Pressure level mapping |
| `AgentLaunchTests.swift` | 66 | Agent launch command construction |
| `ModelSizeCacheTests.swift` | 72 | Size cache persistence |
| `SplashPathsTests.swift` | 57 | Path resolution |
| `ServeLockTests.swift` | 50 | Lock-file semantics |
| `NotificationAndAutoLaunchTests.swift` | 62 | Notification + auto-launch toggles |
| `HarnessTests.swift` | 16 | DeepSeek harness behavior |

## Conventions & Deployment Target

- **Deployment: macOS 26.4 (Tahoe)+, Apple Silicon (M3+ only)** — app target
  `MACOSX_DEPLOYMENT_TARGET = 26.4`, `SUPPORTED_PLATFORMS = macosx`.
- **App target: Swift 6.0**, with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  and `SWIFT_APPROACHABLE_CONCURRENCY = YES` (files are MainActor by default).
- **Test target matches the app**: `SplashTests` is **Swift 6.0**, deployment
  **26.4**, `SUPPORTED_PLATFORMS = macosx` — aligned with the app target
  (the old Swift 5.0 / 27.2 / iOS-xros template leftovers were fixed in W3/W4).
  All 19 test files use **Swift Testing** and do `@testable import Splash`
  (module = target name). **199 tests, all green** (verified 2026-10-29).
  `ScreenshotGeneratorTests` is gated behind the
  `SPLASH_GENERATE_SCREENSHOTS=1` env var (it writes PNGs and mutates
  `SplashService.shared` — keep it out of the normal test lane).
- App target compiles cleanly under **Xcode 27.2 / macOS SDK 27.2** (verified
  2026-10-28): the SDK-27 SwiftUI source changes (@State macro, unified
  @ContentBuilder) trigger no incompatibilities in this codebase.
- Project format: `Splash.xcodeproj/project.xcproj` (JSON, Xcode 27-era
  "last-upgrade 27.2"). Two schemes: `Splash` (shared) and `Splash (french)`
  (personal, in `xcuserdata` — ignore).
- Model layer: everything `@Observable` (Observation framework), including
  `SplashService` and `ModelDiagnosticService`.
- State: `@AppStorage` for all preferences; views mostly stateless wrappers over
  `SplashService.shared`.
- Localization via string catalog with generated symbols; user-facing strings
  through `LocalizedStringResource`.
- **Stale scripts**: `scripts/build_app.sh`, `create_dmg.sh`, `install.sh`
  assume the *old* SwiftPM layout (`Sources/SplashMonitor/…`, `swift build`)
  that no longer matches the repo (`Splash/…`, Xcode project). Each carries a
  HISTORICAL header (W7). Treat as historical; `docs/building.md` is the
  authoritative build doc.
- `.agents/rules/` does not exist (removed in commit "Remove stale agent rules").

## Build & Test Commands

Identified from project files (do NOT assume SPM):

```bash
# Build (Debug, via Xcode tooling)
xcodebuild -project Splash.xcodeproj -scheme Splash -configuration Debug build

# Release build
xcodebuild -project Splash.xcodeproj -scheme Splash -configuration Release build

# Run the test target (test-hosted in the app bundle)
xcodebuild -project Splash.xcodeproj -scheme Splash test
# (or narrow with -only-testing:SplashTests/<TestClass>)
```

All builds are extremely light, you can do them in foreground.

Schemes available: `Splash`, `Splash (french)`. Configurations: Debug, Release.
The release bundle lands in DerivedData at
`Build/Products/Release/Splash.app` (product name = target name "Splash";
verified via build). Requires Xcode 26+/27 on an
Apple-Silicon Mac running macOS 26.4+. A live Splash engine
(`brew install incoai/tap/splash`) is only needed to exercise the app, not to
build or unit-test it.

## Reviewer Notes (for the 4 upcoming workers)

**General**
- Start navigation from this file's File Index; the two heaviest files to
  understand are `Services/SplashService.swift` (2,992 lines) and
  `Views/MainWindowView.swift` (1,115 lines).
- The app's production behavior contract is partly captured in
  **SplashTests fixtures** (real `/status` payload) — treat them as specs.
- **User-facing documentation**: a wiki exists at
  `/Users/lancelot/Developer/AI/splash-app.wiki` with `Home.md`,
  `Visual-Tour.md` (screenshots + description of **every app module** — best
  reference for intended user-facing behavior), `Installation.md`,
  `Troubleshooting.md` (port conflicts, agent-launch errors), `About.md` —
  all in English **and** Spanish (`.es.md` variants). Consult it before
  flagging "suspicious" UX decisions.
- Comments mix English/Spanish; some tests are annotated with audit IDs
  (e.g. "P-07 / H-08", "Sonda V-4") referencing past bug audits.

**modernize-tests worker**
- **Swift Testing migration: DONE (W3/W4).** All 19 test files are Swift
  Testing (199 tests, green 2026-10-29); the test target is Swift 6.0 /
  26.4 / macosx-only and the files do `@testable import Splash`.
- The former P0 blockers are fixed: the `SplashMonitor`-module import
  mismatch, the old-SwiftPM path in
  `VersionTests.testVersionExistsOnceAndScriptsAgreeWithIt` (now reads
  `Splash/Services/Version.swift`), and the deployment-target / platform
  leftovers. `ScreenshotGeneratorTests` is gated behind
  `SPLASH_GENERATE_SCREENSHOTS=1` (it writes PNGs and mutates
  `SplashService.shared` — keep it out of the normal lane).
- Keep the audit-ID comments ("P-07/H-08", "Sonda V-4") and the real
  1.0.2-engine `/status` payload fixture — they are the behavior spec.
- Tests are well factored around the `StatusTransport` / `ServerTerminating`
  seams in `TestSupport.swift`; use those when suggesting rewrites.

**SwiftUI workers (the-swiftui-way, swiftui-specialist, swiftui-whats-new-27)**
- **No deprecated single-parameter `onChange(of:)` remains** — all 6 usages
  are the two-parameter form (fixed in W5).
- Large view files with multiple sub-views per file (e.g.
  `TokenMetricsView.swift` has 4+ view structs); check `ForEach` identity,
  `@State` placement, and observation granularity.
- `SplashService.shared` is an `@Observable` singleton read directly in many
  views — check for over-broad invalidation on the 1.5 s polling cadence
  (`Preferences.refreshInterval`).
- `ModelDiagnosticService` is now `@Observable` too (W5) — the whole model
  layer is Observation-framework-based.
- Menu bar uses `MenuBarExtra` with `.window` style; window uses
  `.windowStyle(.titleBar)` + unified toolbar; 7-tab sidebar in
  `MainWindowView`.
- App is macOS 26.4+ only, so everything in the 2027-release (iOS 27 / macOS
  27) "what's new" skill is fair game *only if* it back-deploys to 26.4 — check
  availability annotations before recommending any 27-era API.
- Default MainActor isolation + approachable concurrency: be careful about
  recommending `nonisolated`/`Sendable` changes in a codebase that relies on
  default MainActor for safety (see the explicit `Task { @MainActor in }`
  sites in SplashService.swift).

**General correctness context**
- Non-sandboxed app; it terminates processes (`HardenedServerTerminator`,
  `ClientTerminationPolicy`) and shells out via `ShellEnvironment` — do not
  "simplify" away the consent/hardening logic in those files.
- `SplashVersion` in `Services/Version.swift` must stay the *only* version
  source (release scripts `sed`-extract its literals); keep the literal format
  `static let current = "…"` intact.
