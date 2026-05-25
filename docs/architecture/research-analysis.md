# WoWshell Architecture Research and Analysis

## Purpose

This document preserves the architectural investigation that produced
`decisions.md`. It captures what was learned from the reference shells
(DankMaterialShell, noctalia-shell), what patterns were considered worth
adopting, what patterns were rejected, and the risk inventory that the
final architecture is designed to mitigate.

This document is descriptive and historical. `decisions.md` is prescriptive
and authoritative. Read this when context behind a decision is needed.

---

## Reference Repositories Surveyed

Two production Quickshell-based shells were studied in depth. Both are
vendored in-tree for offline inspection and excluded from lint/format and
git via `.gitignore`.

### DankMaterialShell

Quickshell shell with broad feature coverage (~350 QML files, 50k+ LOC).
Multi-compositor (Hyprland, Niri, Sway), full plugin SDK, matugen-driven
Material You theming, JSON-backed settings. Pragmatic but with significant
monolithic singletons.

### noctalia-shell

Quickshell shell with cleaner separation (~50k LOC total, smaller per-file
footprint). Multi-compositor with detection, staged startup via ready
signals, two-tier persistent state (Settings + ShellState), file watcher
debounce, per-screen `Variants` for multi-monitor.

---

## DankMaterialShell — Findings

### Directory Layout

Top-level Quickshell directories:

- `Common/` — global singletons (Theme, SettingsData, SessionData).
- `Services/` — 56+ `pragma Singleton` services bridging DBus and hardware.
- `Widgets/` — reusable controls AND domain components (no separation).
- `Modules/` — feature areas (DankBar, ControlCenter, Notifications, Dock).
- `Modals/` — full-screen overlays (Greeter, PowerMenu, Changelog).
- `Shaders/` — GLSL fragments.
- `matugen/` — Material You palette generation: templates + tooling.
- `PLUGINS/` — plugin SDK with examples.
- `scripts/`, `systemd/`, `translations/`, `assets/` — supporting assets.

### Startup

- Entry: `shell.qml` → `ShellRoot` with two synchronous Loaders gated by
  `DMS_RUN_GREETER` env (shell vs greeter).
- `DMSShell.qml` bootstraps:
  - Asynchronous `Instantiator` for daemon plugins (non-blocking).
  - Wallpaper background loaders mixed sync/async.
  - Lock, bars, modals loaded synchronously.
- No lazy loading at shell level; core infrastructure eager.
- Essential UI (bars, lock) blocks first paint; plugins and heavy image
  content load async.

### Services Pattern

All 56 services follow `pragma Singleton` with consistent shape:

- Wraps a Quickshell C++ binding (UPower, NetworkManager, etc.) or
  parses raw IPC.
- Exposes readonly computed properties (`batteryLevel`, `isCharging`).
- Aggregates via filters: `batteries.filter(b => b.ready)`.
- Defaults on missing dependencies: `batteries[0] || null`.
- No try/catch; trusts the C++ layer to suppress errors.

### Theme System

- `Theme.qml` is a 2496-line hub combining stock themes
  (`StockThemes.js`) with matugen output.
- Matugen workflow: wallpaper → palette generation → `dank.json` template
  → output files for qt5ct, gtk, kitty, etc.
- Templates use Jinja-style `{{colors.primary.dark.hex}}` placeholders.
- Reactivity: `SessionData.isLightModeChanged` triggers
  `setDesiredTheme`; colors propagate via property bindings.
- Pull model: components read `Theme.primary` at render time. Wallpaper
  change regenerates palette and all bindings fire.

### Modules vs Widgets

- Widgets are leaf controls (`DankButton`, `DankIcon`, `DankPopout`),
  zero internal state.
- Modules compose widgets through `WidgetHost.qml`, which uses 9+
  explicit `Binding` objects to inject context (parentScreen,
  barThickness, barConfig, axis) into widget instances.
- Composition via property injection, not nesting. Loose coupling.

### State Management

- `SettingsData.qml` — 3217-line singleton, JSON-backed config in
  `~/.config/DankMaterialShell/`, loaded once at startup. Auto-saved on
  property change.
- `SessionData.qml` — 1527-line singleton for runtime state (light mode,
  DND, wallpaperPath) in `~/.local/share/`.
- Schema in JS modules (`SettingsStore.js`, `SettingsSpec.js`) decoupled
  from persistence — a clean idea inside a bloated container.
- Runtime state mostly inside services; ad-hoc dicts
  (`ConnectedModeState`, `PopoutManager`) handle cross-cutting concerns.

### Reactive Patterns

- Heavy use of `Connections` and `Binding` objects.
- `WidgetHost.qml`: nine explicit `Binding`s with `restoreMode` per
  widget. Multiplied across widgets × bars, this is a binding pool of
  considerable size.
- Cascading update risk: wallpaper change → `setDesiredTheme` →
  `matugenColors` updated → 50+ property bindings fire across UI.
- No debounce visible; bindings may re-fire per property update.
- No reactive abstraction (no computed/watch helpers); direct
  signal-property chains.

### Patterns Worth Borrowing

1. **Schema in JS modules**, decoupled from persistence logic.
2. **Matugen template system** — adding a new integration (alacritty,
   emacs) is a config file, not a code change.
3. **Plugin Instantiator with async daemon load** — non-blocking
   self-registration.
4. **`Binding.restoreMode` for conditional context injection** —
   declarative, avoids JavaScript glue.
5. **Geometry cache separation** (`ConnectedModeState`): hot-path
   coordinates separate from full layout state, reducing binding churn.

### Patterns to Avoid

1. **Singleton monoliths**: `Theme.qml` (2496 lines),
   `SettingsData.qml` (3217 lines). Hard to navigate, test, refactor.
2. **`typeof X !== "undefined"` guards** (~50 occurrences). Symptom of
   bidirectional dependencies (Theme ↔ SessionData ↔ SettingsData) and
   undefined initialization order.
3. **Many `Binding` objects in tight loops** — re-evaluated per widget
   instance. Risk of jank on bar resize or monitor hot-plug.
4. **Manual state dict synchronization** without transaction guards;
   intermediate inconsistent state visible if a binding errors.
5. **No error boundary pattern**. DBus failures silently degrade to
   stale state; no retry, no user feedback.

---

## noctalia-shell — Findings

### Directory Layout

- `Assets/` — static resources, color schemes (JSON), fonts, shaders.
- `Commons/` — singletons (Settings, ShellState, Style, Color, I18n,
  Logger).
- `Helpers/` — pure JS utilities (color math, fuzzy sort, sha256).
- `Modules/` — UI components (Bar, Launcher, Settings, OSD, LockScreen,
  Dock).
- `Services/` — system integrations grouped by domain (Compositor,
  Hardware, Theming, Networking).
- `Widgets/` — reusable controls with `N` prefix (`NButton`, `NIcon`,
  `NBattery`).
- `Scripts/` — external bash and Python tools.
- `nix/` — flake-based dependency management.

### Startup

- Entry: `shell.qml` (259 lines).
- `ShellRoot` gates UI behind three ready signals: `i18nLoaded`,
  `settingsLoaded`, `shellStateLoaded`.
- Critical services (Wallpaper, ImageCache, AppTheme, Color, DarkMode)
  initialize synchronously before UI render.
- Deferred services (Location, NightLight, Idle, Power, GitHub) deferred
  via `Qt.callLater()` to unblock first frame.
- Delayed initialization at T+1.5s for non-critical services
  (HooksService, FontService, UpdateService).
- Multi-monitor: `Variants { model: Quickshell.screens }` instantiates
  per-screen bar + panel registry entries.

### Services Pattern

```
pragma Singleton
Singleton {
  id: root
  readonly property <T> derivedValue: …
  property var _internalState: null
  Connections { target: …; function on…() { … } }
  function init() { Logger.i(…); }
}
```

- Readonly computed properties; internal state prefixed `_`.
- Graceful degradation: missing DBus → properties null, no exception.
- Explicit `init()` called from `shell.qml` (staged). No implicit
  auto-start.

### Theme System

- `Style.qml` — spacing scales, radii, font sizes, animation timings.
  Reactive to `Settings.data.general` ratios.
- `AppThemeService.qml` — listens to `WallpaperService`, triggers
  palette regeneration on wallpaper change or scheme switch.
- `Colors.qml` — loads `colors.json` (Material 3 tokens), file watcher
  debounced (200ms).
- `TemplateRegistry` + `TemplateProcessor` — generate derived files
  (GTK4, Qt colors); skip-write-if-identical optimization.
- Consumers bind directly to `Color.mPrimary`, `Style.marginM`.
- `isTransitioning` flag suppresses animations during palette swap.

### Modules vs Widgets

- Module (`Bar.qml`, ~350 lines) — per-screen layout manager with three
  `ListModel`s (left/center/right widget slots).
- Widget (`Battery.qml`, `Clock.qml`) — individual mini-UIs exposing
  `widgetId` and optional `clicked()` signal. Consume services directly.
- `BarWidgetLoader.qml` — Loader bridge: registry lookup, plugin load,
  hot reload.
- Clear boundary: bar doesn't know widget internals; widgets are
  independently replaceable.

### State Management

- **Settings**: `~/.config/noctalia/settings.json`, ~600-line `Settings.qml`.
  `FileView` + `JsonAdapter` auto-reload on external change (200ms
  debounce).
- **ShellState**: `~/.cache/noctalia/shell-state.json`, ~200-line
  singleton. Ephemeral state (display scales, notification timestamps,
  launcher MRU) separated from settings to avoid frequent JSON rewrites.
- Runtime state owned by services; no central store.

### Reactive Patterns

- Heavy property bindings.
- 71+ `Connections` blocks across Services; used conservatively — chains
  rarely deep.
- `ListModel` sync in `Bar.qml`: explicit add/remove by index rather
  than full model replacement. Preserves `Repeater` delegate state,
  prevents flicker.
- Debounce timers protect against rapid external file change events.

### Multi-Monitor

- `Variants { model: Quickshell.screens; delegate: Item { … } }` —
  one delegate per screen at startup.
- Each monitor gets MainScreen, BarContentWindow, BarTriggerZone,
  PopupMenuWindow.
- Configuration looked up per screen via
  `Settings.getBarPositionForScreen(screen.name)`.
- `BarWidgetRegistry` dedupes widget components; `BarWidgetLoader`
  instantiates per (screen, widget) pair.

### Patterns Worth Borrowing

1. **Staged initialization via ready signals** — `i18nLoaded` +
   `settingsLoaded` + `shellStateLoaded` gate UI render via one Loader.
2. **Readonly computed properties** as the public service interface.
3. **Graceful missing-dependency handling** — null properties, not
   exceptions.
4. **Stable `ListModel`** with index-based mutation for repeated UI.
5. **File watcher debounce** — survives atomic file replacements
   (write-temp-then-rename) without duplicate reloads.

### Patterns to Avoid

1. **Plugin system complexity** — `PluginService.qml` is 2087 lines.
   Defer until plugin demand is concrete.
2. **Deep service dependency chains** (`AppThemeService` →
   `WallpaperService` → `Settings`) require careful init ordering.
3. **Manual per-service `init()` calls** — ~20 scattered across two
   Timer blocks. Easy to forget; fragile.
4. **Many small singletons** — namespace pollution and static load
   cost; consider grouping where related.
5. **Tight compositor coupling at init** — `CompositorService` branches
   per compositor; not designed for mid-session compositor change.

---

## Comparative Summary

| Concern | DankMaterialShell | noctalia-shell | WoWshell Direction |
|---|---|---|---|
| Service shape | `pragma Singleton`, often huge | `pragma Singleton`, focused | Adopt; cap ≤ ~300 lines |
| Persistent state | One 3217-line monolith | Split: Settings + ShellState | Borrow the split |
| Startup | Eager, synchronous | Staged via ready signals | Borrow staged gating |
| Theme | 2496-line hub + matugen | Color singleton + processor | Small aggregator; matugen out-of-process |
| Multi-monitor | `Variants` per screen | `Variants` per screen | Adopt |
| Plugins | Full SDK | Full SDK, ~2k LOC | Defer; not in v1 |
| Init ordering | Implicit | ~20 manual `init()` calls | Declarative registry |
| Compositor | Multi (Hyprland/Niri/Sway) | Multi with detection | Niri-only by policy |
| Reactive style | `Binding` + Connections heavy | Bindings primary, signals targeted | Bindings default, signals exception |

---

## Risk Inventory

Findings are ranked by likelihood and impact. The high-risk items shaped
the strongest design rules in `decisions.md`.

### High Risk

1. **Singleton monolith drift**. Both references show this happens
   gradually. `Theme.qml` at 2500+ lines began as a small file. Hard
   cap on singleton size and clear split criteria are essential.

2. **Bidirectional dependencies producing `typeof undefined` guards**.
   The DankMaterialShell `Theme ↔ Config ↔ Session` triangle is the
   canonical example. Once two singletons reference each other, every
   property access must guard, and load order becomes implicit.

3. **First-frame contention**. Eager loading of audio, network,
   notifications, MPRIS, and matugen at startup adds 200–500ms before
   the user sees the bar. The deferral pattern is the fix.

4. **Configuration format mismatch**. The scaffold ships `*.toml`
   configs but Qt has no native TOML reader. This is a blocker the
   first time the shell tries to load configuration.

### Medium Risk

5. **`components/` and `widgets/` collapse**. Without a written rule
   on what belongs where, the first domain widget lands in
   `components/` "because it's reusable", and the line is permanently
   gone. DankMaterialShell shows this end-state.

6. **Reactive cascades on theme reload**. A naive matugen integration
   triggers many binding updates per color change. Aggregating colors
   under one object and using an `isTransitioning` flag mitigates this.

7. **Per-monitor state leakage**. Writing to `Config` keyed by
   `screen.name` strands orphaned keys on monitor hot-plug. Strategy
   needs to be chosen up front: prune-on-load or namespace by stable id.

8. **Polling timer accumulation**. Each service that polls adds a
   wake-up. Budget needs to be explicit.

### Low Risk

9. **Plugin system creep**. Both references invested heavily in
   plugins. Defer until at least three real plugins are requested.

10. **Per-compositor branching**. WoWshell is Niri-only. Resisting
    `if (compositor == 'hyprland')` branches keeps the integration
    direct.

11. **Excessive blur**. Full-window blur behind every popout has
    known frame-pacing impact on integrated GPUs. Budget blur to a
    small allowlist of surfaces.

12. **Lint gap**. The current `scripts/lint.sh` doesn't pass `-I` or
    a project `qmldir`. It will silently miss singleton resolution
    failures. Worth fixing before adding code, not after.

---

## Inheritance Decisions

Explicit choices about what to take from each reference and what to leave.

### Taken from noctalia-shell

- Staged readiness signals at startup.
- Two-tier persistent state (Settings + ShellState).
- Service-as-singleton shape with readonly computed properties.
- File watcher debounce (200ms).
- `Variants` per-screen multi-monitor pattern.
- `ListModel` stability via index-based mutation.

### Taken from DankMaterialShell

- Matugen for color extraction (out-of-process invocation).
- Schema in JS modules pattern (only the idea, not the monolith).
- Async `Instantiator` for non-critical async loaders.

### Explicitly Rejected

- Multi-compositor abstraction (Niri-only by policy).
- Plugin system (deferred until real demand).
- Per-service manual `init()` calls (replaced by declarative registry).
- Monolithic singletons (hard cap enforced).
- In-process color math in QML (matugen handles it).
- Polling-first sensors where DBus or compositor IPC publishes the same
  data.
