# Combined Code Review — Splash Monitor

Consolidated from four sequential skill-based reviews of the whole repo:

| Source tag | Report | Lens |
|---|---|---|
| `[tests]` | `.qwen/review-modernize-tests.md` | Test-suite modernization (XCTest → Swift Testing) — **authoritative for everything test-related** |
| `[swiftui-way]` | `.qwen/review-the-swiftui-way.md` | SwiftUI patterns/anti-patterns (through macOS 26) |
| `[whats-new-27]` | `.qwen/review-swiftui-whats-new-27.md` | SDK-27-era adoption (authoritative for 27-era items) |
| `[specialist]` | `.qwen/review-swiftui-specialist.md` | Apple SwiftUI best practices, macOS-27-updated (refines/supersedes `[swiftui-way]` on techniques) |

App baseline: macOS 26.4, Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
Verified: the app builds cleanly under Xcode 27.2 / macOS SDK 27.2 (`[whats-new-27]`),
so all 27-era recommendations below ship as `if #available(macOS 27, *)` dual paths —
the 26.4 baseline is never raised. Test target currently deploys 27.2, so test code
needs no availability gates.

---

## 1. Executive summary

The architecture is fundamentally sound: one `@Observable` service with
constructor-injected protocol seams (`StatusTransport`, `ServerTerminating`),
narrow value-input leaf views (`MetricCard`, `AgentButton`, `IntegrationGuideCard`…),
`LocalizedStringResource` used correctly on model/service types, and hardened,
well-tested process-termination code that should not be "simplified".

The problems cluster in five places:

1. **Zero tests compile or run.** The test target has **four independent
   compile blockers** (module-name mismatch in all 19 files, two tests calling
   a removed `isSpanish:` API, one test reading a deleted source path). This is
   the P0 for everything — see §2.
2. **Every tab is one invalidation boundary, and the poll defeats skipping
   even where views are factored.** Sections are computed properties, not
   structs, so any of ~15 read service props re-runs the whole screen 1.5 s
   apart. Worse, `SplashStatus` is a fresh non-`Equatable` JSON decode
   assigned unconditionally every poll, so the `@Observable` setter never
   short-circuits. **Adding `Equatable` to the `SplashStatus` tree is the
   single highest-leverage app fix** (one line per struct) — it restores
   invalidation skipping for all views at once.
3. **Live-behavior bugs a user can see today:** the port field
   auto-restarts the engine mid-keystroke; a literal `%%` renders in the ANE
   row; the context-size menu shows seven identical "1M tokens (YaRN)" rows;
   connected-app cards freeze ("Last seen"/status/socket count never update)
   because `ConnectedApp.==` only compares pid+name; three menu labels ignore
   their stored state; and the benchmark view presents fabricated TTFT values
   as measured.
4. **Work executed in view bodies / on the MainActor:** `getifaddrs()` per
   body eval (`localNetworkIP`), a socket `bind()` per body eval
   (`isPortListening`), `FileManager` stat scans per body eval
   (`isAgentInstalled`), synchronous lock-file I/O every poll tick, and an
   engine-stop escalation whose blocking `lsof`/`ps` spawns run on the main
   thread.
5. **Localization is broken in two directions at once:** the app's
   language-switch feature is dead code (nothing reads
   `Preferences.appLanguageMode` / `LocalizationService`), so the catalog's
   `es` translations and 6+ hardcoded-Spanish strings mix freely in the

**26.4 ↔ 27 interplay:** only two 27-era adoption sites exist today — the
duplicated `Alert`-returning `.alert(item:)` in two tabs (adopt 27
`alert(_:item:)` behind `#available`) and the delete-model alert
(`isPresented` + `presenting` → single optional). Everything else in the 27
release (AsyncImage caching, reorderable containers, toolbar overflow, swipe
actions outside List) has **no surface area** in this app — verified, no
action. `visibilityPriority` back-deploys to macOS 26.1 and would need no gate
*if* a real `toolbar { }` is ever added (the app currently has none).

---

## 2. P0 blockers — the test target cannot compile

**Resolved by W1 (2026-10-28):** all four P0 blockers — the `SplashMonitor`
module-name mismatch, the removed `title(isSpanish:)` /
`localizedName(isSpanish:)` APIs, the stale `Sources/SplashMonitor/…` SwiftPM
path in `VersionTests`, and Swift 6 strict-concurrency isolation errors — are
fixed; the test target compiles under Swift 6 and the full XCTest suite passes
(120/120).

---

## 3. Observation & rendering performance

### 3.1 Make the `SplashStatus` tree `Equatable` — the systemic fix · **High** `[specialist]` F-ST-1, `[swiftui-way]` P2-4
**Resolved by W4 (2026-10-29):** `Equatable` across the `SplashStatus` tree landed in `2a47963`; the redundant writes are now guarded — `checkServerStatus()` and `scanAndConnectPort()` assign `status`, `isRunning` and `activeModel` only when the decoded value differs, and the derived values views read are recomputed once per tick in `updateStatusDerivedCaches()` (see §3.4). `speedHistory` churn accepted (real sparkline data).

### 3.2 One invalidation boundary per tab — extract sections into structs · **High** `[specialist]` F-MW-1/F-SC-5/F-TM-2/F-MM-2/F-CA-1/F-MT-2/F-MB-4/F-DI-3, `[swiftui-way]` P1-8/P1-12/P2-8
All seven tab views factor their "sections" as private computed properties /
`@ViewBuilder` helpers. Computed props inline into the parent body and share
its dependency set, so any read service prop change re-runs the whole screen —
including *static* content (the 10 integration-guide cards in
`ConnectedAppsView`, the 8 agent buttons in `ServerControlView`,
`settingsDetailView` ~470 lines in `MainWindowView.swift:385`).
**Fix (both reviews agree):** one standalone `View` struct per banner/card with
narrow value inputs. Highest-impact extractions: `QuickConnectGuideSection`
(pure static content), `ServerControlView`'s `agentsLauncherView` /
`apiEndpointsView`, `ModelManagerView`'s `installationConsoleView`,
`TokenMetricsView`'s memory/quick-bar/request sections, `MenuBarView`'s
header (churned by `isRunning`/`activeModel`).
**Resolved by W5 (2026-10-29):** every tab view now projects narrow value inputs into extracted `private struct` sections — `MainWindowView.settingsDetailView` split into 9 `Settings*Card` structs, `ModelTestingView` into `TestingHeaderView`/`SmokeTestSection`/`SmokeTestRow`/`BenchmarkSection`/`BenchmarkMetricCard`/`PlaygroundSection`, `TokenMetricsView` into `ActiveRequestCard`/`SpeedHistoryCard`/`EfficiencyMetricsCard`/`MemorySectionCard`/`ConnectedAppsQuickBar`/`ConnectedAppChip`, `ServerControlView` into `AgentsLauncherView`/`APIEndpointsView`, `ModelManagerView`'s online rows into `OnlineModelRow`, `ConnectedAppsView`'s `Header`/`MetricsSummaryRow`/`QuickConnectGuideSection`/`StatBadgeCard`/`IntegrationGuideCard`, and `MenuBarView`'s `MenuBarHeaderView`. The two install consoles (model + dependency) share one `InstallConsole` view fed by monotonic-id `InstallLogLine`s. State that must survive tab switches (playground inputs, the delete-alert target) stays `@State` in the parent; everything else is value input + closure actions.

### 3.3 Migrate `ModelDiagnosticService` to `@Observable` and hoist the instance · **High** `[specialist]` F-MDS-2/F-MT-1, `[swiftui-way]` P1-6/P1-7, `[whats-new-27]` P3-4
**Resolved by W4+W5 (2026-10-29):** `ModelDiagnosticService` is now `@Observable` (zero `@Published` left in the codebase) and the instance is hoisted to a stable parent and injected via `@Environment(ModelDiagnosticService.self)`, so leaving the tab no longer destroys smoke-test/benchmark results; W5 extracted `ModelTestingView`'s subviews (including the old `metricCard(...)` helper, now `BenchmarkMetricCard`) into standalone structs — see §3.2.

### 3.4 Cache derived values on the service instead of reading the compound `status` · **Medium** `[specialist]` F-TM-3/F-SC-6/F-MW-2/F-CA-2
**Resolved by W4 (2026-10-29):** the service now caches every derived value views read — `ttftP50Ms`, `itlP50Ms`, `memoryDevice`, `thermalState`, `statusMemoryPressure`, `weights`, `aneFfn`, `requestsCompleted/Cancelled/Failed`, `schedulerQueued`, `statusVision` — recomputed once per tick in `updateStatusDerivedCaches()` (nilled on stop/reset), and `ConnectedAppsView`'s summary reads the stored `activeClientCount` / `totalSockets` maintained by `scanConnectedClients()`. All `status?.…` read sites in `TokenMetricsView` / `ServerControlView` / `ConnectedAppsView` were switched to the cached values. The `MainWindowView` sidebar badge intentionally keeps its `.active`-only filter (different semantics from `activeClientCount`, which includes idle).

### 3.5 Work in view bodies · **P0/Medium** `[swiftui-way]` P0-2/P1-1/P1-2, `[specialist]` F-SVC-2/F-AIV-1/F-SC-8/F-CA-5
- **`SplashService.localNetworkIP`** (`Splash/Services/SplashService.swift:145-147`,
  verified): a *computed* property doing `getifaddrs`/`getnameinfo` on every
  read, read directly in bodies (`ServerControlView.swift:224, 478, 479, 494`,
  `ConnectedAppsView.swift:112`), never observable (stale UI when the IP
  changes), with a `SplashService.shared.localNetworkIP!` force-unwrap at
  `ServerControlView.swift:479` one line below its guard. **Fix:** stored
  `private(set) var` refreshed during polling / on `listenOnAllInterfaces`
  change; drop the force-unwrap.
- **`isPortListening(port:)`** (`ServerControlView.swift:435`, verified):
  socket `bind()` syscall in the body, re-run every keystroke/tick. **Fix:**
  stored result refreshed via `.task(id: portString)` or `onChange` of port.
- **`isAgentInstalled(agent:)`** (`ServerControlView.swift:1004-1082`): sync
  `FileManager` stat scans (20–40 per eval × 8 `AgentButton`s) while the
  background `refreshAgentAvailability()` cache (`SplashService.swift:2162-2201`)
  exists but is bypassed by app-presence fallbacks. **Fix:** fold app-presence
  results into `installedAgents`; make `isAgentInstalled` a pure `Set.contains`.
- **`AppIconView.body`** (`Splash/Views/AppIconView.swift:12-17`): `Bundle`
  lookup + `NSImage(contentsOf:)` decode per evaluation; used in
  `MenuBarView`'s poll-churned header. **Fix:** `static let` cached `NSImage`.
- **`ConnectedAppCard.formattedTime`** (`ConnectedAppsView.swift:617-618`):
  fresh `DateFormatter` per card per poll tick. **Fix:** `Text(app.lastSeen,
  format: .dateTime.hour().minute().second())`.
- **Log sheet body** (`ServerControlView.swift:138`): reads the log file
  (`Data(contentsOf:)` + split) synchronously in the sheet body builder. **Fix:**
  load once into `@State` when the sheet opens.

**Resolved by W4+W5 (2026-10-29):** the service-side items landed in W4 (stored `localNetworkIP` refreshed during polling, `isAgentInstalled` a pure `installedAgents.contains` with the app-presence scan folded into `refreshAgentAvailability()` and run off-actor, `AppIconView` decoding its icon into a `static let`); W5 finished the view side — `ServerControlView` holds `@State portInUse` refreshed via `.task(id: portString)` (no more `bind()` syscall per keystroke), loads the log file once into `@State serverLogsText` when the sheet opens, commits the port on `onSubmit`/focus loss instead of per keystroke, and `ConnectedAppCard` renders `lastSeen` with `Text(_, format: .dateTime…)` instead of a fresh `DateFormatter` per card per tick.

### 3.6 Poll loop & per-tick I/O · **Medium** `[swiftui-way]` P2-1/P2-2
**Resolved by W4 (2026-10-29):** `checkServerStatus()` now has an in-flight guard (`isCheckingStatus`) so overlapping polls can't stack, and the lock-file read/decode/stale-cleanup runs off the main actor (`resolveActiveLock` in a `Task.detached` returning a `Sendable` `LockSnapshot`; only the resulting `activePort`/`activeModel`/`activePid` writes touch the service). The 10th-tick `refreshInstalledModels` disk walk moved to `nonisolated static scanInstalledModels` (value-captured directory/state, `ModelSizeCache` mutated by value and returned). `detectPortConflict()` runs its `lsof`/`ps` spawns in a `Task.detached`, and `startServer` only calls `launchServerProcess()` after that async check.

### 3.7 `ConnectedAppCard` frozen rows — value-comparison vs `==` · **High** `[swiftui-way]` P1-4, `[specialist]` F-CONN-1
`Splash/Models/ConnectedApp.swift:83-85` — custom `==` compares **only**
pid+name. Since the card takes the whole value, SwiftUI's value comparison
treats a row as *unchanged* when only `status`/`connectionCount`/`lastSeen`
change → **row body skipped: "Last seen" never advances, socket count frozen,
status badge never flips to "Recently Disconnected"**. For `ForEach` identity
(computed `"\(pid)-\(name)"`) the equality is fine. **Fix (split concerns —
both reviews converge):** keep pid+name for identity/array-skip, but pass the
displayed fields (status, count, lastSeen) as narrow separate inputs to the
card (or compare displayed fields with a quantized `lastSeen`). Secondary: the
card's `icon: NSImage?` input is non-POD, so reflected comparison can't prove
equality (`[specialist]` F-CA-6) — the narrow-input fix covers this.
**Resolved by W5 (2026-10-29):** `ConnectedAppCard` now takes the narrow value inputs (`pid`, `name`, `icon`, `category`, `status`, `connectionCount`, `bundleId`, `lastSeen`) with `var id: Int { pid }`, so per-poll `status`/`connectionCount`/`lastSeen` changes reach the row body and the row's `@State` (hover, termination-confirmation) survives. Actions (`activateApp`/`revealAppInFinder`/`terminateApp`) resolve the live `ConnectedApp` by PID (`connectedApps.first(where: { $0.pid == pid })`) before touching the service, so a stale displayed value can't terminate/activate the wrong process.

### 3.8 List identity & row structure · **Medium** `[swiftui-way]` P1-10/P1-11/P2-9, `[specialist]` F-MM-3/F-DI-2/F-MM-7/F-MM-8/F-MM-10
- **Offset-as-id in both live log consoles:**
  `ModelManagerView.swift:522` and `DependencyInstallView.swift:208` use
  `ForEach(Array(logs.enumerated()), id: \.offset)` + `.id(idx)`. After
  "Clear"/`removeAll()` offsets are reused → wrong rows animate/scroll.
  **Fix:** log entries as a small `Identifiable` struct (monotonic id) in the
  service; share one `InstallConsole` view (the two consoles are
  near-identical).
- **`isGatedError`** (`ModelManagerView.swift` bottom): scans the whole
  `installLogs` (4× `contains`) on every body eval during installs. **Fix:**
  `@State`/service cache updated on `onChange(of: installSuccess)`.
- **Online-model rows** (`ModelManagerView`, `onlineModelsList`): body-level
  `filter` + per-row `installedModels.contains { … }` (O(n·m)) with inline row
  content (no skip boundary); the tab `Picker` uses **Int tags 0/1/2**
  (`ModelManagerView.swift:20-22`, verified) — every other tab in the app uses
  an enum. **Fix:** row struct with value inputs (`item`, `isInstalled` from a
  precomputed `Set<repoId>`); enum for the tab.

**Resolved by W5 (2026-10-29):** both consoles now share the single `InstallConsole` view whose rows are `InstallLogLine`s (monotonic `Identifiable` ids owned by the service; in-place progress lines rewrite `text` of the same line instead of appending), so `ForEach(logs)` has stable identity across "Clear"/`removeAll()`. `isGatedError` is a `@State` cache recomputed on `onChange(of: installSuccess)`. Online rows are `OnlineModelRow(item:isInstalled:isInstalling:)` fed by a precomputed `Set<repoId>`, and the tab selector is a typed `ModelManagerTab` enum (as is `ModelTestingTab` in the testing tab).

---

## 4. Live-behavior bugs (user-visible, non-SwiftUI-idiom)

- **Port field auto-restarts the engine mid-keystroke · P0** `[swiftui-way]` P0-3, `[specialist]` F-SC-11 —
  `Splash/Views/ServerControlView.swift:974-981` (verified):
  `.onChange(of: portString)` calls `startServer(model:port:)` the moment the
  partially-typed text parses as a valid port ≠ active port; typing "9005" over
  "8005" restarts the live engine on intermediate values. Also interacts with
  the reverse-sync `onChange(of: activePort)` at `:57` that can overwrite
  in-progress input. **Fix:** commit on `onSubmit` / focus loss.
  **Resolved (in-tree since commit `2a47963`):** the port field now commits through `commitPort()` on `onSubmit` and focus loss, and the reverse-sync `onChange(of: activePort)` skips while the field is focused, so intermediate keystrokes never restart the engine.
- **Literal `%%` in the ANE row · High** `[swiftui-way]` addendum 1, `[specialist]` F-TM-1 —
  `Splash/Views/TokenMetricsView.swift:231` (verified):
  `Text("…\(Int(share * 100))%% share")` — Swift interpolation has no printf
  semantics → UI renders "… · 67%% share". **Fix:** single `%`.
  **Resolved (in-tree since commit `2a47963`):** the interpolation now uses a single `%`.
- **Seven identical "1M tokens (YaRN)" rows · High** `[swiftui-way]` addendum 2, `[specialist]` F-SC-2 —
  `ServerControlView.swift:530-540` (verified): `ForEach(["16K", …, "1M"])`
  but every row label is hardcoded `Text("1M tokens (YaRN)")`. **Fix:**
  `Text("\(ctx) tokens")` + the YaRN note for 1M only.
  **Resolved (in-tree since commit `2a47963`):** each row interpolates its own context label; the "(YaRN)" suffix appears only for 1M.
- **Three menu labels ignore their stored state · Medium** `[swiftui-way]` addendum 4, `[specialist]` F-SC-3 —
  **Resolved by W3 (2026-10-28):** already applied in-tree (commit `2a47963`) — GDN, modality and Verify menu labels now interpolate `Preferences.stateFormat` / `Preferences.languageOnly` / `Preferences.verifyRows`; verified in `ServerControlView.swift`.
- **Inconsistent validation gating · Medium** `[swiftui-way]` addendum 3 —
  **Resolved by W3 (2026-10-28):** already applied in-tree (commit `2a47963`) — "Start Server" is now gated on the same `customModelError` validation as "Switch Model"; verified in `ServerControlView.swift`.
- **Fabricated benchmark TTFT presented as measured · Medium (data-truthfulness)** `[swiftui-way]` addendum 5 —
  `Splash/Services/ModelDiagnosticService.swift`: `estimatedTTFTMs =
  max(15, totalElapsed * 0.35 * 1000)`, `playgroundTTFTMs = max(10, elapsed *
  0.25 * 1000)` — UI labels these "Cold TTFT (1st Token)". Relabel as estimates
  or remove.
  **Resolved by W5 (2026-10-29):** the estimates are now labeled as such — the benchmark card reads "Estimated Cold TTFT" with subtitle "Estimated from total response time", the playground row reads "Est. TTFT: … ms", and the service documents the factors at each computation site.
- **`SplashEngineIdentity.engineMarkers` contains bare "splash"** —
  **Resolved by W4 (2026-10-29):** the bare `splash` marker is gone — `engineMarkers` is now `["server.py", "serve-native", "/splash"]` (path-separated / engine-specific only), so this app's own binary (`SplashMonitor.app/…/Splash`) can no longer match; `ProcessIntrospectionTests` covers all three installed layouts. `[swiftui-way]` P3.

---

## 5. Deprecated / soft-deprecated APIs

### 5.1 Single-parameter `.onChange(of:)` — 5 sites (not 8) · **Medium** `[swiftui-way]` P1-13, `[specialist]` F-APP-1/F-MW-6/F-MM-6/F-DI-2/F-MB-1
**Resolved by W4+W5 (2026-10-29):** every `onChange` in the app is now the two-param form (grep-verified; the W5 rewrites of `ModelManagerView` / `DependencyInstallView`'s consoles — now the shared `InstallConsole` with `onChange(of: logs.count)` — removed the last two single-param sites), and the two `refreshInterval` slider sites (settings card, menu-bar view) commit via `onEditingChanged` + `startPolling()` instead of reacting per slider step.
Verified by grep: **5** single-param sites (AGENTS.md claims 8 — stale):
`SplashMonitorApp.swift:113`, `MainWindowView.swift:681`, `MenuBarView.swift:260`,
`ModelManagerView.swift:522`, `DependencyInstallView.swift:208`. Deprecated
since macOS 14; the app targets 26.4, and two-param forms are already used in
3 places (`ServerControlView.swift:57, 974`, `ModelManagerView.swift:330`).
**Fix:** two-param `onChange(of:initial:)`; for the two `refreshInterval`
slider sites, restart polling on `onEditingChanged` end instead of per slider
step.

### 5.2 `Alert`-returning `.alert(item:)` — duplicated in two tabs · **High** `[whats-new-27]` P1-1, `[specialist]` F-SC-1/F-MM-1, *conflicts with* `[swiftui-way]` (listed as a "good pattern")
**Resolved by W3 (2026-10-28):** factored into the shared `PortConflictAlertModifier` (`Splash/Views/PortConflictAlertModifier.swift`) with the dual `if #available(macOS 27, *)` path (27 `alert(_:item:actions:message:)` form, old `Alert`-returning form as fallback) and an optional `onUseSuggestedPort` hook; both `ServerControlView` and `ModelManagerView` now call `.portConflictAlert()` and the inline copies are deleted.

### 5.3 `.menuStyle(.borderlessButton)` ×~8 · **Medium** `[specialist]` F-SC-4
**Resolved by W3 (2026-10-28):** already applied in-tree (commit `2a47963`) — all `.menuStyle(.borderlessButton)` sites converted to `.menuStyle(.button)` + `.buttonStyle(.borderless)`; verified no remaining matches in `Splash/Views/`.

### 5.4 `Picker("empty", …)` ×~7 · **Low** `[specialist]` F-MW-8, `[swiftui-way]` P3
`Picker("empty", selection:).labelsHidden()` app-wide — the literal `"empty"`
lands in the string catalog as a key and VoiceOver reads "empty". **Fix:**
`Picker(selection:content:label:) { … } label: { EmptyView() }` (or a shared
empty label). Note the label-last `Picker.init(selection:label:content:)` is
the soft-deprecated spelling.
**Resolved by W5 (2026-10-29):** every segmented tab/menu picker now carries a meaningful accessible label ("Model catalog tab", "Model testing section", "Connected apps view", "Menu bar display mode", "Output tokens:", "API protocol", "Context window limit", …) that stays visible to VoiceOver while hidden in the UI via `.labelsHidden()` — the app owner's a11y preference over the `EmptyView()` label.

---

## 6. macOS 27 adoption (availability-gated)

All items here are **dual-path**: `if #available(macOS 27, *)` for the modern
form, existing behavior in the fallback branch — the 26.4 baseline is
preserved. The app already compiles under the 27 SDK (verified), so no
source-incompatibility risk (`@State` macro, `@ContentBuilder` unification)
remains. `[whats-new-27]` is authoritative for this section.

1. **Port-conflict `alert(_:item:)`** — see §5.2 (the main 27-era win;
   de-duplicates two copies at the same time).
2. **Delete-model alert → 27 `alert(_:item:)` · Low** `[whats-new-27]` P2-2 —
   `ModelManagerView.swift:11-12, 42-52, 156-157`: presentation driven by a
   separate `showingDeleteAlert: Bool` + `modelToDelete` optional via
   `alert(_:isPresented:presenting:)`. The 27 item overload lets the single
   optional drive presentation (SwiftUI resets it to `nil` on dismiss) — the
   Bool and half the trigger logic disappear. **Dual path:** gated
   `alert("Delete Model?", item: $modelToDelete)`; keep `showingDeleteAlert`
   alive for the 26.x branch (delete only when the target moves to 27).
   (Non-candidate, documented: the terminate-app `confirmationDialog` at
   `ConnectedAppsView.swift:583-596` captures `app` from the row's stored
   property — no optional to bind; its current form is correct.)
   **Resolved by W5 (2026-10-29):** `ModelManagerView`'s delete alert is now the dual path — the 27 branch drives presentation purely from `modelToDelete` via `alert("Delete Model?", item:)` (SwiftUI nils it on dismiss), the 26.x branch keeps `showingDeleteAlert` + `presenting:`; the delete button sets both, the bool only matters on 26.x. The terminate-app `confirmationDialog` now resolves the live app by PID (see §3.7) and was otherwise left as documented.
3. **`State(initialValue:)` seeding in the two `init(initialTab:)`s · Low** `[whats-new-27]` P3-3, *conflicts with* `[swiftui-way]` P1-9 —
   `MainWindowView.swift:47-49` and `ConnectedAppsView.swift:22-24` seed
   `@State` via the legacy projected-value form. Both inits have **no
   production call sites** — they exist solely for
   `ScreenshotGeneratorTests.swift:156, 192, 247` (verified).
   **Resolution (27-era guidance supersedes):** *keep* the inits (the
   screenshot generator needs them) and modernize to the macro-correct
   direct-assignment form — drop the inline default,
   `self.selectedSidebarItem = initialTab` — which compiles under the 27 SDK
   (verified) and keeps working at the 26.4 deployment target. Do **not**
   reorder or split init assignments across stored properties (the shape the
   `@State` macro turns into "used before being initialized" errors). Revisit
   deletion once the screenshot generator is quarantined (§8.2).
   **Resolved by W5 (2026-10-29):** both `init(initialTab:)`s now use the macro-correct direct-assignment form (`@State private var selectedTab: X = .default` + `self.selectedTab = initialTab` in init), single assignment, no projected-value seeding; the inits are kept because the screenshot generator still calls them.
4. **No adoption path — verified, no action** `[whats-new-27]` INFO-5/6:
   no `AsyncImage`, no reorder/drag-drop surface, no List swipe actions, and
   **no `toolbar { }` builders at all** (only `.windowToolbarStyle(.unified)`
   at `SplashMonitorApp.swift:118`) — so toolbar overflow/pinning APIs have
   nothing to attach to. The 43 `.background(Color…opacity(…))` sites are all
   safe under unified `@ContentBuilder` (every base is a concrete `Color`;
   clean 27-SDK build confirms). If a real toolbar is ever added,
   `visibilityPriority` needs **no gate** at the 26.4 baseline (back-deploys
   to 26.1).
5. **When the deployment target eventually moves to 27:** remove the gates
   from items 1–2, delete the fallback branches and `showingDeleteAlert`; the
   test target already deploys 27.2, so tests can adopt new forms
   unconditionally.

---

## 7. Concurrency & MainActor

- **`HardenedServerTerminator.stopEngine` runs its escalation on the main
  thread · Medium** `[swiftui-way]` P1-3 —
  **Resolved by W4 (2026-10-29):** `CommandRunner`, `HardenedServerTerminator`, `CommandResult`, `KillTargetResolver`, `SplashEngineIdentity`, `ListerOutput`/`EstablishedConnection` and `ServeLockStore` are now `nonisolated`, so the INT→TERM→KILL escalation (blocking `lsof`/`ps` spawns + sleeps) executes off the main actor; only the resulting state writes touch the MainActor. The consent/hardening logic (`ClientTerminationPolicy`, PID re-verification) is untouched.
- **`SystemMemoryPressureSentinel` · Low** `[swiftui-way]` P2-13 —
  **Resolved by W4 (2026-10-29):** `init()` has no side effects (monitoring starts via the idempotent `startMonitoring()`, called from `SplashService`); the utility-queue handler reads the source through a `Sendable` holder that is assigned *before* `resume()`, so no early events are dropped and no MainActor-isolated member is touched off-actor; the main-thread hop is now `Task { @MainActor in }`.
- **Static `@AppStorage` in `Preferences` may never invalidate the scene ·
  Medium** `[specialist]` F-APP-2/F-MB-3 —
  **Resolved by W4 (2026-10-29):** `SplashMonitorApp` now owns scene-level `@AppStorage("showMenuBarIcon")` / `@AppStorage("menuBarOnlyMode")` properties (same `UserDefaults` keys as the `Preferences` statics), so writing those keys re-evaluates the scene: `MenuBarExtra(isInserted: $showMenuBarIcon)` and the activation-policy `onChange(of: menuBarOnlyMode)` now fire. `AppDelegate` keeps reading `Preferences` (same store, always fresh).
- **Unmanaged `DispatchQueue.main.asyncAfter` (survives view disappearance, no
  cancellation) · Low** `[swiftui-way]` P3 — 6+ sites:
  `MainWindowView.swift:509`, `ServerControlView.swift:307, 1161`,
  `ConnectedAppsView.swift:415-431`, `ModelManagerView` copy-reset,
  `MenuBarView.swift:300-318` (double window scan). **Fix:** cancellable
  `Task` / `onChange`-driven flag. The `copyToClipboard`/`showCopied` pair is
  duplicated verbatim in ConnectedAppsView + ServerControlView — extract to a
  `View` extension (also resolves the locale-resolved-at-creation note,
  `[specialist]` F-SC-9/F-CA-7).
  **Resolved by W3+W5 (2026-10-29):** zero `DispatchQueue.main.asyncAfter` left in `Splash/` (grep-verified; the remaining mentions are comments) — the optimal-profile banner in `MainWindowView` and the menu-bar window-scan hide both use cancellable `Task`s (the banner one runs in the extracted `SettingsOptimalProfileCard`), and the copy-flash pair is the shared `ClipboardCopy.swift` helper (`copyToClipboard(_:flash:into:)` + `copiedFlashAutoClear($copied)`) with an auto-clearing `CopiedFlash`, used by the guide card, smoke-test report and API-endpoint rows.
- **Side-effecting inits · Low** `[swiftui-way]` P2-13/P2-14, `[swiftui-way]` P3 —
  **Resolved by W4 (2026-10-29):** `NotificationService.init`, `AutoLaunchService.init` and `SystemMemoryPressureSentinel.init` now assign values only; the permission prompt (only when `Preferences.systemNotificationsEnabled`) and the launch-at-login status refresh moved to `applicationDidFinishLaunching`.
- **`print(...)` instead of `os.Logger` · Low** `[swiftui-way]` P3 —
  **Resolved by W4 (2026-10-29):** every `print(...)` site (`SplashService` ×4, `NotificationService` ×2, `AutoLaunchService`) replaced with `Logger` calls (subsystem `do.jmgrep.splashmonitor`, per-class category); grep-verified zero `print(` left in `Splash/`.
- **`Task { await … }` fire-and-forget without re-entrancy guards · Info** `[swiftui-way]` P3 —
  **Resolved by W4 (2026-10-29):** `fetchOnlineModels()` got an in-flight guard (`isLoadingOnlineModels` is now checked *before* being set); `checkServerStatus()` likewise (see §3.6). The remaining user-initiated one-shots were left as-is per the pattern guide.
- **`AgentButton` stores `action: () -> Void` · Low** `[specialist]` F-SC-7 —
  **Resolved by W3 (2026-10-28):** `AgentButton` now takes the `Equatable` `CodingAgent` enum + plain value inputs (no closure property); the action lives in the `Button` of `AgentsLauncherView`, so unchanged buttons skip re-evaluation.

---

## 8. Testing (modernize-tests — authoritative)

Source: `[tests]` throughout. Severity per the test report (P0 → §2).

**Resolved by W2 (2026-10-28):** all 19 test files migrated to Swift
Testing (`@Suite`/`@Test`/`#expect`/`#require`, `@MainActor` kept on every
suite touching app types); the 13+ fixed sleeps replaced by condition waits
via the `TestSupport.waitFor` helper (`#require(where:timeout:)` does not
exist in this toolchain); `TestSupport.waitUntil` deleted, the duplicated
`makeService` helpers hoisted into the canonical `makeTestService`;
`ScreenshotGeneratorTests` env-gated behind `SPLASH_GENERATE_SCREENSHOTS`
with dedicated injected service, `Fixtures` reuse, temp-dir output and
singleton state restored in `deinit`; the UserDefaults/sentinel-delegate
polluters (ServerOptions, NotificationAndAutoLaunch, SystemMemoryPressure,
ShellEnvironment) run `@Suite(.serialized)` with globals restored in
`deinit`; `@Test(arguments:)` consolidations applied across all 8 target
suites; vacuous tests now assert real values (`doesNotCrash` smoke, the two
`XCTAssertTrue(true)`, DeepSeek-harness detection `enabled(if:)`);
audit-ID comments (P-xx / H-xx, Sonda V-4/V-7/V-8, F0.1) and the real 1.0.2
`/status` fixture preserved verbatim; `MARKETING_VERSION` aligned to
1.0.10-beta on both targets in the (gitignored) project file — full suite
passes, screenshot generator SKIPPED in the normal lane (see W2 report).

---

## 9. Localization

- **The language-switch feature is dead code · Medium** `[specialist]` F-SVC-LANG, `[swiftui-way]` P1-14 —
  `Preferences.appLanguageMode` (`Services/Preferences.swift:50`, default
  `"es"`) + `LocalizationService.AppLanguage`/`forceLanguage` are
  declaration-only: nothing in production reads them, there is no switch UI,
  and the app runs in system language only. This is the root cause of the
  EN-UI/ES-string mix. **Fix (feature decision — flagged, not mandated):**
  delete the dead pair (+ the `AppLanguage` enum), or implement the
  `Bundle`-override feature. Either way fix the docs (§10).
  **Resolved (in-tree since commit `2a47963`):** the dead `appLanguageMode`/`LocalizationService`/`AppLanguage` pair was deleted in the review-start commit; the AGENTS.md doc fix landed in W7.
- **Catalog has zero `fr` — AGENTS.md overstates coverage · Low** `[specialist]` + `[swiftui-way]` P2-15 —
  `Splash/Resources/Localizable.xcstrings`: 584 keys, 439 `es`, 9 explicit
  `en`, **0 `fr`** (verified programmatically by two workers). The "french"
  scheme is a personal `xcuserdata` artifact.
  **Deferred to W7 (2026-10-29):** the only action is the AGENTS.md coverage doc fix, handled in the W7 hygiene group.
- **Hardcoded Spanish in the English UI · High (user-visible)** `[specialist]` F-TM-6/F-DI-1/F-CA-3/F-MM-4/F-MDS-1/F-SCV-1/F-SVC-3, `[swiftui-way]` P3:
  - `TokenMetricsView.swift` — signature `"By Joan Gregorio Pérez - Ingeniero en software"`
  - `SplashService.swift:53` — `activeModel: String = "Ninguno"` (shown with no model loaded); `:2725` — `"Memoria liberada manualmente por el usuario."`
  - `ModelDiagnosticService.swift` — ~15 hardcoded Spanish smoke/benchmark strings rendered by `ModelTestingView` ("Código HTTP inesperado", "Ejecutando Ronda 1 (Cold Prefill - Sin Caché)…" etc.), while the *test names* in the same file are LSR
  - `ServerCLIValidator` — Spanish error strings returned as plain `String` (shown via `ServerControlView` `customFlagsError`); `ModelIDValidator.rejectionReason` right next to it already returns LSR — return LSR for consistency
  - `DependencyInstallView.swift` — `LocalizedStringResource("Instalado")`, `"Intel (No compatible)"`, plus console lines ("Iniciando instalación…")
  - `ConnectedAppsView.swift` — `"Copiar Configuración"` / `"cURL / Terminal Directo"`
  - `ModelManagerView.swift` — `"\(dlStr) recibidos"` in `formatDownloadProgress`
  **Fix:** LSR for every user-facing string (the app's own
  `ModelIDValidator`/`AgentButton`/`lastError` already show the pattern).
  **Resolved by W6 (2026-10-29):** every site listed now uses LSR, plus same-class sites found in the pass (agent-launch `lastError` strings, "Port out of range", "Invalid model identifier: %@", weights-released notice, and the full install/download console logs); `InstallLogLine.text`/`downloadPhase` stay `String` (tests construct them) and are localized at the emission site via `String(localized:)`.
- **Non-locale-aware formatting · Low** `[specialist]` F-MW-5/F-TM-4/F-MM-4/F-ST-2/F-MT-3, `[swiftui-way]` P3 —
  pervasive `String(format: "%.1f s"/"%.0f ms"/"%.2f GB")` and `%.0f MB/s`.
  **Fix:** `Text(…, format: .number.precision(.fractionLength(1)))` +
  localized units; `ByteCountFormatStyle` for sizes (note: `StatusModelTests`
  currently *pins* these locale-fixed outputs — update expectations when
  migrating).
  **Resolved by W6 (2026-10-29):** the flagged view/model sites now use `Text(…, format: .number.precision(…))` interpolation and `ByteCountFormatStyle` (`SplashStatus.formattedSize`, `InstallConsole.formatDownloadProgress`); the pre-cached `SplashService.formatted*` properties are intentionally kept as `String(format:)` — this review lists them as a good pattern and `StatusModelTests` pins their exact outputs, so no test expectations were changed.
- **Runtime case transforms · Low** `[specialist]` F-MW-4/F-TM-5/F-MB-2 —
  `.textCase(.uppercase)` on `Text("Running Model")` / `Text("brew")` forces
  the same casing on every translation and defeats catalog review (bake the
  case into the string); `thermal.capitalized` / `memoryPressure?.capitalized`
  on raw engine strings (`capitalized` uppercases *every* word, locale-dependent)
  → map engine strings to a small enum with an LSR label + color.
  **Resolved by W6 (2026-10-29):** "RUNNING MODEL"/"BREW" are now literals with the case baked in (no `.textCase`); engine thermal/pressure/ANE strings map through small LSR-label + color helpers (`thermalLabel`/`pressureLabel`/`aneLabel` in `TokenMetricsView`) instead of `.capitalized`.
- **Latent landmine** `[specialist]` F-PR-1 — `SystemMemoryPressureLevel` raw
  values are Spanish display strings (`"Advertencia"`, `"Crítica"`); no View
  renders them today (notification path uses its own localized strings), but
  if ever displayed, Spanish leaks into the EN UI.
  **Resolved by W6 (2026-10-29):** `SystemMemoryPressureLevel` raw values are now stable English identifiers ("Normal"/"Warning"/"Critical"); views render LSR labels mapped from them.
- **Also:** `ServerCLIValidator.validateThinkingBudget` replaces *any* "k" with
  "000" (`"1k2"` → `"10002"` accepted); `ModelIDValidator.rejectionReason` runs
  the no-slash check before the forbidden-char check (misleading message for
  values with both problems) `[swiftui-way]` P3.
  **Resolved by W6 (2026-10-29):** `validateThinkingBudget` only expands a trailing "k" after digits ("1k2" is rejected); `ModelIDValidator.rejectionReason` now runs the forbidden-character check before the missing-separator check.

---

## 10. Project hygiene & other

- **AGENTS.md corrections (verified by 2-3 workers; the next reviewer will be
  misled otherwise) · Medium:**
  - deprecated single-param `onChange` count is **5, not 8** (sites in §5.1);
  - the string catalog is **en + es only (0 `fr`)**; `AppLanguage` is es/en,
    not en/es/fr;
  - `ScreenshotGeneratorTests` renders via `NSHostingView`, not ImageRenderer;
  - `SplashService.shared` is declared `@Bindable private(set) static var
    shared = SplashService()` (`SplashService.swift:25`) — views get bindings
    via `SplashService.$shared.prop`;
  - add the two `isSpanish:` test blockers and the `ScreenshotGeneratorTests`
    lane problem to the "test target does not compile" note (it lists only
    the module name).
- **Stale release scripts · Low** `[swiftui-way]` addendum 7 —
  `scripts/build_app.sh`, `create_dmg.sh`, `install.sh` assume the removed
  SwiftPM layout (`Sources/SplashMonitor/…`, `swift build`);
  `docs/building.md` is authoritative. Treat as historical or delete.
- **Version drift · Low** `[tests]` / `[swiftui-way]` — project
  `MARKETING_VERSION = "1.0"` vs `SplashVersion.current = "1.0.10-beta"`.
  The scripts sed-extract the latter; keep the `static let current = "…"`
  literal intact and reconcile the project setting (or mark it decorative).
- **Dead code · Low** `[swiftui-way]` P3, `[specialist]` F-DE-1/F-AB-1 —
  `DominicanEmblem` (referenced nowhere — verify before deleting),
  `AboutView`'s empty `init()`, redundant `@Bindable` on the `shared` static
  if no view actually uses `$shared.` bindings for it (grep before removing).
  **Partially resolved by W5 (2026-10-29):** `AboutView`'s empty `init()` is removed; grep-verified `$shared.` bindings are used (5 sites: `ServerControlView`, `PortConflictAlertModifier` ×2, `MainWindowView` ×2), so the `@Bindable` on `shared` is **required — keep**. Remaining (W7): delete the unreferenced `DominicanEmblem`.
- **Accessibility · Low** `[swiftui-way]` P3 — icon-only buttons without text
  labels (`MenuBarView.swift:120-160`, `ConnectedAppCard:505-535`,
  TokenMetricsView free-memory/dismiss, AboutView): use
  `Button("Label", systemImage:) + .labelStyle(.iconOnly)` (`.help()` alone
  doesn't set the VoiceOver label); fixed point sizes
  (`.font(.system(size: 10/11/12…)`) app-wide (representative:
  `MainWindowView.swift:88, 96, 141`) break Dynamic Type — semantic fonts +
  `@ScaledMetric`. (The 11 pt menu-bar label size is arguably intentional —
  keep, `[specialist]` F-APP-3.)
  **Partially resolved by W5 (2026-10-29):** every icon-only button now uses the shared pattern `Button("Label", systemImage: "…") { … }.labelStyle(.iconOnly)` + `.help()` — the 5 menu-bar buttons, the `ConnectedAppCard` actions, the model rows (Reveal/Delete/Refresh), the memory-notice dismiss and the log-console buttons. Remaining: the app-wide fixed point-size → Dynamic Type migration (deliberately deferred: it would restyle every screen and the owner treats the current sizing as the design).
- **`SemanticVersion` prerelease comparison is lexicographic on the suffix** —
  `"1.0.10-beta.10"` sorts before `"-beta.2"`; harmless for current
  single-digit betas. `[swiftui-way]` P3.
- **`AboutView` hardcodes "© 2026"** — drifts. `[specialist]` F-AB-1.
  **Resolved by W5 (2026-10-29):** the year is now computed from `Calendar.current` and interpolated into the (localizable) copyright string.
- **Good patterns — keep** (all reviews converge): narrow value-input leaf
  views (`MetricCard`, `MiniStatRow`, `RequestPill`, `SpeedMiniChart`,
  `AgentButton`, `StatBadgeCard`, `IntegrationGuideCard`, `DiagnosticBadge`,
  `TechBadge`); `LocalizedStringResource` on non-view types
  (`ModelIDValidator.rejectionReason`, `SplashService.lastError`,
  `AgentButton(name:)`, `SmokeTestResult.name`, enum `title`/`localizedName`);
  pre-cached formatted service props (`memoryUsageRatio`,
  `InstalledSplashModel.formattedSize`); `StatusTransport`/`ServerTerminating`
  protocol seams with injected stubs; `ModelSizeCache` (value-type TTL cache,
  keeps disk walks out of the poll); `CommandRunner`'s pipe-read-before-
  `waitUntilExit` (avoids the 64 KB deadlock); the modern
  `alert(_:isPresented:presenting:)` delete alert, `confirmationDialog` with
  destructive role, segmented `Picker` tabs, element-direct `ForEach` with
  `Identifiable` models; the termination/consent hardening in
  `ServerTermination.swift`/`ProcessIntrospection.swift` (do not simplify).

---

## 11. Prioritized action plan

P0 first; effort estimates for a single experienced Swift developer.

1. **[P0, S] Unblock the test target — all 4 §2 blockers:** `PRODUCT_MODULE_NAME`
   on the Splash target; rewrite `ModelDiagnosticTests.swift:74-75` and
   `ServerOptionsTests.swift:142-143` to the zero-arg `title`/`localizedName`;
   repoint `VersionTests.swift:61-80` at `Splash/Services/Version.swift`.
   Then `xcodebuild test` until green *in XCTest*.
2. **[P0, S] Port keystroke auto-restart** → commit on `onSubmit`/focus loss
   (`ServerControlView.swift:974-981`). Live-behavior bug, trivial fix.
3. **[P0, S] `%% share` literal → `%`** (`TokenMetricsView.swift:231`) and
   **seven "1M tokens (YaRN)" rows** → interpolate `ctx`
   (`ServerControlView.swift:535`).
4. **[High, S] `Equatable` across the `SplashStatus` tree** + guard redundant
   `isRunning`/`activeModel` writes in the poll (`SplashService.swift:549-636`).
   One line per struct; restores Observation skipping app-wide. Update
   `StatusModelTests` expectations only if formatting changes.
5. **[High, M] Connected-app cards:** narrow inputs for status/count/lastSeen
   so "Last seen"/badges update (§3.7); share one `InstallConsole` +
   `Identifiable` log entries to kill both `id: \.offset` consoles (§3.8).
6. **[High, L] Extract tab sections into standalone structs** (§3.2), starting
   with `QuickConnectGuideSection`, `agentsLauncherView`/`apiEndpointsView`,
   `settingsDetailView` cards, `TokenMetricsView` sections, `MenuBarView`
   header. The single highest-leverage structural change for the 1.5 s cadence.
7. **[High, M] `ModelDiagnosticService` → `@Observable`**, `@StateObject` →
   `@State`, hoist the instance out of the tab `switch` (results survive tab
   switches); extract `ModelTestingView` subviews.
8. **[High, M] Quarantine `ScreenshotGeneratorTests`** out of the default test
   lane (custom action / script); dedicated injected `SplashService`; reuse
   `Fixtures`; temp-dir output.
9. **[High, L] Copy/label bugs:** stale GDN/modality/Verify menu labels;
   start-vs-switch validation gating; relabel fabricated TTFT as estimates.
10. **[Medium, S] Work out of bodies:** stored poll-refreshed `localNetworkIP`
    (+ drop the `:479` force-unwrap); `.task(id:)` for `isPortListening`; fold
    app-presence into `installedAgents`; `static let` `NSImage` in
    AppIconView; `Text(_:format:)` instead of per-card `DateFormatter`.
11. **[Medium, S] Deprecation sweep:** 5× single-param `onChange` → two-param
    (with slider `onEditingChanged` end-commit); `Picker("empty")` → empty
    label view; `.menuStyle(.borderlessButton)` ×8; `print` → `os.Logger`.
12. **[Medium, S] 27-era dual paths:** shared gated `PortConflictAlertModifier`
    (27 `alert(_:item:)` / fallback existing form); gated delete-model
    `alert(_:item:)`; modernize the two `initialTab:` inits to macro-correct
    direct-assignment `@State` seeding.
13. **[Medium, M] MainActor hygiene:** `nonisolated`/detached
    `stopEngine` escalation; `detectPortConflict` async; poll in-flight guard;
    sentinel source lifecycle; `asyncAfter` → cancellable tasks; verify/fix
    the static-`@AppStorage` scene-invalidation question (§7).
14. **[Medium, M] Localization:** delete (or implement) the dead
    `appLanguageMode`/`LocalizationService` pair; LSR-ize the hardcoded-Spanish
    strings in §9; format styles for numbers/sizes; resolve the fr-catalog
    claim in docs.
15. **[Medium, S] Test-target settings drift** → Swift 6.0 / macOS 26.4 /
    macosx-only (5→6 bump after migration edits; fix the
    `MockSentinelDelegate` cross-actor write).
16. **[M, then L] Swift Testing migration** per `[tests]` plan: pure-function
    suites first with `@Test(arguments:)` consolidations → stateful
    `@MainActor` `.serialized` suites with `#require(where:timeout:)` replacing
    the 13+ fixed sleeps and `deinit`-restored globals → delete
    `TestSupport.waitUntil`, hoist `makeService`, drop the `import XCTest`.
    Preserve audit-ID comments and the real-payload fixture.
17. **[Low, S] AGENTS.md corrections** (§10) so the next reviewer isn't
    misled; reconcile `MARKETING_VERSION`; a11y sweep
    (`Button(_:systemImage:)`, `@ScaledMetric`); delete dead code
    (`DominicanEmblem` after reference check).

*S = small (≤ half day) · M = medium (0.5–2 days) · L = large (2–5 days)*

---

## 12. Conflicts between the four reviews — resolutions

1. **`.alert(item:)` + `Alert(…)` — good pattern or anti-pattern?**
   `[swiftui-way]` lists it among "good patterns"; `[whats-new-27]` P1-1 and
   `[specialist]` F-SC-1/F-MM-1 flag both the overload and the struct as
   SDK-27 soft-deprecated and a named anti-pattern. → **Resolution:** the two
   later, more specific reviews win (precedence rules 3-4): adopt one shared
   gated `PortConflictAlertModifier` with the 27 form behind
   `#available(macOS 27, *)` and the existing form as the 26.x fallback.
2. **The two `init(initialTab:)`s — delete or modernize?** `[swiftui-way]`
   P1-9 calls them vestigial and suggests deleting unused inits;
   `[whats-new-27]` P3-3 says modernize to macro-correct direct assignment or
   delete. → **Resolution:** keep + modernize to direct `@State` assignment —
   the screenshot generator (`ScreenshotGeneratorTests.swift:156, 192, 247`)
   still calls them, and the modernized form works under the verified 27-SDK
   build at the 26.4 target; deletion is revisited once the generator is
   quarantined.
3. **`AppIconView` file I/O in body — P2 or Medium?** `[swiftui-way]` P2-12
   rates it minor (mitigated by the single `CGFloat` value input);
   `[specialist]` F-AIV-1 rates it Medium (used in the poll-churned
   MenuBarView header). → **Resolution:** `[specialist]` refines — Medium,
   `static let` cache (the fix is trivial either way).
4. **MenuBarExtra label invalidation — precompute or accept?** `[swiftui-way]`
   P2-5 wants a precomputed `@Observable menuBarText`; `[specialist]` F-APP-4
   deems it acceptable (tiny view). → **Resolution:** `[specialist]`
   precedence — accepted as-is; precomputing remains an optional cheap
   improvement, folded into §7 only if the static-`@AppStorage` scene question
   (§7 item 3) surfaces a real problem.
5. **`Binding(get:set:)` closures — anti-pattern or idiomatic?**
   `[swiftui-way]` P2-6 flags them; `[specialist]` F-MW-3 downgrades
   (re-verified against `AutoLaunchService`'s `private(set)` + `setEnabled`
   API — the closure *is* the idiomatic shape for a side-effectful setter).
   → **Resolution:** `[specialist]` refines — keep; consider a small reusable
   helper only.
6. **Deprecated-`onChange` count and fr-locale claim in AGENTS.md.**
   `[swiftui-way]` and `[specialist]` both verify 5 sites and 0 fr
   translations against AGENTS.md's 8 / en-es-fr. → **Resolution:** verified
   independently by this consolidation via grep — 5 single-param sites,
   0 fr keys; AGENTS.md correction listed in §10.
7. **Test-target blockers — one or four?** AGENTS.md and `[tests]` list only
   the module-name mismatch as the compile blocker; `[swiftui-way]` P0-1
   verified two additional dead-API call sites that would fail *after* the
   import fix. → **Resolution:** all four are independent compile blockers and
   are listed once each in §2 (module name is the *first* failure, the others
   are latent until it's fixed).
