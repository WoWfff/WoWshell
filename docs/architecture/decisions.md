# WoWshell Architecture Decisions

## Purpose

This document is the authoritative architecture reference for WoWshell.
Every section states finalized rules that all code must follow. When a
new contribution conflicts with this document, the document wins until
explicitly updated.

For the reasoning and reference-shell evidence behind these decisions,
see `research-analysis.md`.

---

## Runtime Architecture

Four strict layers, dependencies flow downward only:

```
shell.qml
    │
    ▼ instantiates per-screen
modules/      Bar, Launcher, Dashboard, Notifications, OSD
    │
    ▼ composes
widgets/      Clock, BatteryIndicator, NetworkBadge, …
    │
    ▼ composes
components/   Surface, Pill, Glyph, IconLabel, PopoutWindow
    │
    ▼ reads
theme/   services/   state/   utils/
```

- The root `shell.qml` owns screen instantiation and panel registration.
- Modules own panel geometry and feature scope.
- Widgets own shell-domain visual state (one widget, one purpose).
- Components own reusable visual primitives.
- Leaves (theme, services, state, utils) own no UI and no domain logic.

---

## Layering Rules

| From | May import | Must not import |
|---|---|---|
| `theme/` | nothing | anything else |
| `utils/` | nothing | anything else |
| `state/` | `utils/` | `theme/`, `services/`, UI |
| `services/` | `theme/`, `state/`, `utils/` | UI (modules, widgets, components) |
| `components/` | `theme/`, `utils/` | `services/`, `state/`, domain |
| `widgets/` | `components/`, `theme/`, `services/`, `state/`, `utils/` | other widgets, modules |
| `modules/<x>/` | all of the above | other modules |

- No cyclic dependencies. Ever.
- No `import qs.Modules.<Other>` between sibling modules.
- A widget may not import another widget. Composition happens in the
  module above.

---

## Components vs Widgets vs Modules

Three tiers, separated by what they know about:

### `components/`

- **Visual primitives only.** Reusable in any shell.
- Know about theme, geometry, animation, layout.
- Do not know about battery, network, workspace, notifications.
- Examples: `Surface.qml`, `Pill.qml`, `IconLabel.qml`, `Slider.qml`,
  `PopoutWindow.qml`, `Glyph.qml`.

### `widgets/`

- **Shell-domain widgets.** One service, one purpose.
- Read theme and exactly one service (or one cluster of related state).
- Expose visual state; do not own panel geometry.
- Examples: `ClockWidget.qml`, `BatteryWidget.qml`, `NetworkWidget.qml`,
  `AudioVolumeWidget.qml`, `WorkspaceWidget.qml`.

### `modules/`

- **Self-contained shell features.** Compose widgets and primitives.
- Own a `PanelWindow` or `PopupWindow`, manage geometry and lifecycle.
- Independently disable-able via `Config.modules.<name>.enabled`.
- Examples: `Bar.qml`, `Launcher.qml`, `Dashboard.qml`,
  `NotificationLayer.qml`, `MediaOverlay.qml`.

When in doubt: if a file mentions a Quickshell service by name, it is at
least a widget. If a file owns a `PanelWindow`, it is a module.

---

## Startup Philosophy

Startup is staged. Each stage gates on a ready signal from the previous.

### Stage 0 — Critical foundations (blocks first paint)

- `Config` loads (`FileView` + `JsonAdapter`).
- `ShellState` loads.
- `Theme` aggregator initializes from `Config` and any cached palette.
- `Logger` ready.

### Stage 1 — Per-screen UI (blocks first paint)

- `Variants { model: Quickshell.screens }` instantiates per-screen UI.
- `Bar` loads on each screen.
- Bar registers with `PanelService`.

### Stage 2 — Non-critical services (deferred via `Qt.callLater`)

- Audio, Network, Notifications, Media, Wallpaper start.
- Matugen invocation runs only if wallpaper requires re-extraction.
- Pre-warmed Loaders for Launcher, Dashboard, OSD start with
  `asynchronous: true`.

### Stage 3 — Background workers (further deferred)

- Power, idle, brightness services.
- Anything that touches disk repeatedly.

### Rules

- No `Component.onCompleted` chains between services.
- No `typeof X !== "undefined"` guards in user code; foundations are
  guaranteed available by the time anything in Stage 1+ runs.
- A single `services/ServiceRegistry.qml` enumerates services declaratively
  with `{ name, lazy, critical }`. Adding a service is one registry entry,
  not a new `init()` call site.

---

## Service Architecture

### Canonical shape

Every service is `pragma Singleton` `Singleton` with this exact contract:

- `readonly property bool available` — backing API reachable?
- `readonly property <T> <state>` — derived, never mutated externally.
- `property var _<name>` — internal state, underscore-prefixed.
- `signal <event>(…)` — coarse events for non-property changes.
- Optional `function init()` only when warmup is non-trivial.
- One `Connections` block per external dependency, not chained.

### Size cap

A service file exceeding ~300 lines must be split by sub-domain. No
exceptions for "this one is special" — every singleton monolith started
as a small file.

### v1 service inventory

| Service | Backing API | Critical |
|---|---|---|
| `Config` | `FileView` + `JsonAdapter` | yes |
| `ShellState` | `FileView` (cache dir) | yes |
| `Niri` | Niri IPC (`niri msg`) | yes |
| `Audio` | `Quickshell.Services.Pipewire` | no |
| `Network` | `Quickshell.Services.NetworkManager` | no |
| `Battery` | `Quickshell.Services.UPower` | no |
| `Brightness` | `brightnessctl` via `Process` | no |
| `Notifications` | `Quickshell.Services.Notifications` | no |
| `Media` | `Quickshell.Services.Mpris` | no |
| `Wallpaper` | file watch + matugen | no |
| `MatugenBridge` | `Process` invoking matugen CLI | no |

Out of v1 scope: plugin system, multi-compositor support, theme
hot-switching mid-session, GitHub/update services.

### Degradation rule

`available === false` means widgets render a fallback or hide. There is
no exception-based error path. No try/catch over the DBus or Process
layer in user code.

---

## Theme Architecture

A small aggregator pattern, not a monolith.

### Files

```
theme/
  qmldir
  Theme.qml          aggregator facade — what consumers import
  Palette.qml        colors (defaults + matugen-injected)
  Typography.qml     font families, sizes, weights
  Spacing.qml        spacing scale
  Radius.qml         corner radii
  Motion.qml         durations + easing curves
  matugen/
    config.toml
    templates/
```

### Rules

- `Theme.qml` exposes nested properties (`Theme.colors.primary`,
  `Theme.spacing.md`). Consumers import only `Theme`.
- `Palette.qml` watches `$XDG_CACHE_HOME/wowshell/palette.json` and
  updates color properties on change.
- Matugen runs **out of process**, invoked by the `Wallpaper` service.
  No color math in QML.
- `Theme.isTransitioning` is true during palette swap. Animations and
  expensive bindings check this flag.
- `Theme` reads `Config`. `Config` never reads `Theme`. Strictly
  one-way.

---

## State Management

Two stores, two purposes. Nothing else lives in `state/`.

| Store | File | Purpose | Write frequency |
|---|---|---|---|
| `Config` | `$XDG_CONFIG_HOME/wowshell/config.json` | User intent: enabled modules, bar layout, keybinds, theme prefs | rare, on user action |
| `ShellState` | `$XDG_CACHE_HOME/wowshell/state.json` | Ephemeral: launcher MRU, last-seen notifications, restored values | frequent, debounced |

### Rules

- Services own their own runtime state. `Audio.volume`,
  `Network.activeConnection`, `Battery.level` live on the service,
  not in `state/`.
- No global mutable property bag.
- Writes go through a debounced `save()` (250ms batch window).
- Atomic writes (write-temp-then-rename) for crash safety.
- JSON only. No TOML. (Existing `config/*.toml` files must be converted
  or removed.)
- Unknown keys are preserved on round-trip; defaults fill missing keys.
- No schema validation framework in v1.

---

## Reactive Flow Philosophy

Three rules govern reactivity.

### 1. Bindings are the default; signals are the exception

Property bindings (`property color bg: Theme.colors.surface`) are the
preferred mechanism. Use `Connections { … function on…() { … } }` only
when the reaction is imperative (start a `Process`, write a file) or
the dependency is a signal.

### 2. Derived state lives once, in the source

A widget that needs "battery icon name" does not compute it locally.
`Battery.iconName` is a `readonly property string` on the service. This
centralizes the mapping and removes recomputation in N widgets.

### 3. No reactive chain deeper than three hops

A → B → C → UI is acceptable. A → B → C → D → E → UI is not. If depth
is unavoidable, the upstream service is too coarse — split it.

### Concrete techniques

- Stable `ListModel` with index-based mutation for repeated UI.
- Debounce external file watches at 200–300ms.
- Avoid imperative `Binding { … restoreMode: … }` glue except where
  conditional binding is genuinely needed.
- No polling timer for state already published by DBus or compositor IPC.

---

## Module Boundaries

Each module under `modules/<name>/` follows this contract:

- Exports one root file named after the module (`Bar.qml`,
  `Launcher.qml`).
- Receives a `screen` reference (or null for full-screen modules).
- Reads its own settings from `Config.modules.<name>`.
- Owns its panel geometry through `PanelWindow` or `PopupWindow`.
- Disable-able via `Config.modules.<name>.enabled`.

### Modules must not

- Import other modules.
- Hold state that belongs in a service.
- Mutate `Config` or `ShellState` outside explicit user actions.
- Register global keybindings directly (handled by a dedicated
  `Keybinds` service reading from `Config`).

Removing `modules/launcher/` must not break the bar.

---

## Performance Constraints

Explicit budgets. Code that violates these requires justification.

### Startup

- First paint within 200ms of process start on reference hardware.
- Stage 0 + Stage 1 must not invoke `Process`, network, or full file
  reads beyond `Config` and `ShellState`.

### Memory

- No persistent hidden widgets. Use Loader with `active` gating.
- No widget caching beyond what `Repeater`/`ListView` already provides.
- No image decoding at theme-aggregator load.

### CPU

- One polling timer maximum per service, and only when no signal-based
  alternative exists.
- No binding chain longer than three hops.
- File watchers debounced 200–300ms.

### GPU

- Blur restricted to an allowlist of surfaces (bar background and one
  popout root per module).
- No full-screen blur layers.
- No shader effects in widgets (only in `components/`).

### Reactive

- Singletons capped at ~300 lines. Split by sub-domain past that.
- Theme palette swap suppresses non-essential animations via
  `Theme.isTransitioning`.

---

## Animation Philosophy

Subtle motion supporting comprehension. Never decorative.

### Duration tiers (from `Motion.qml`)

- `fast` — 120ms. Hover states, micro-feedback.
- `normal` — 220ms. Most transitions, panel reveals.
- `slow` — 320ms. Full-page panel transitions only.

### Rules

- Easing: prefer `Easing.OutCubic` or `OutQuad` for entrances,
  `InCubic` for exits.
- No animation longer than 320ms.
- No animation under 80ms (perceived as a flicker, not a transition).
- No simultaneous animations on more than ~5 properties.
- No animation during `Theme.isTransitioning`.
- Animations follow `Config.animations.enabled`; respect user choice.

---

## Multi-Monitor Strategy

Per-screen `Variants` from day one. Not retrofitted later.

### Pattern

```
Variants {
  model: Quickshell.screens
  delegate: Item { property var screen: modelData; … }
}
```

- Each module that has per-screen presence (Bar, Notifications, OSD)
  is instantiated via `Variants`.
- Module configuration is looked up by stable screen identifier (prefer
  `screen.name` plus a content-hash fallback for ambiguous setups).
- Panel registration with `PanelService` is scoped per (module, screen).
- No assumption of monitor count, position, scale, or DPI at module level.

### Ultrawide and scaling

- Bar widget layouts use stable `ListModel`s; bar adapts to width via
  spacing and overflow, not hidden states.
- Component sizing uses `Theme.spacing` and `Theme.radius` scales — no
  hardcoded pixel literals.

---

## Anti-Patterns to Avoid

Ranked by likelihood and impact. Each is grounded in real precedent
from the reference shells.

### High impact

1. **Singleton monolith drift.** A 200-line `Theme.qml` becomes a
   2500-line one if no cap is enforced. Hard limit: ~300 lines.
2. **Bidirectional dependencies producing `typeof undefined` guards.**
   Symptom of undefined load order and missing one-way rule. Foundations
   are guaranteed available before consumers run.
3. **First-frame contention** from eager service starts. Only `Config`,
   `ShellState`, `Theme`, `Logger`, `Niri`, and the Bar may block first
   paint.
4. **Configuration via unsupported formats.** JSON only. Qt has no
   native TOML reader.

### Medium impact

5. **Components and widgets collapsing.** Without the three-tier rule,
   the boundary erodes irreversibly within weeks.
6. **Reactive cascades on theme reload.** Aggregate colors under one
   object, guard expensive bindings with `isTransitioning`.
7. **Per-monitor state leaks.** Strategy on monitor hot-plug must be
   decided up front (prune-on-load preferred).
8. **Polling timer accumulation.** One per service, justified, or none.

### Low impact

9. **Plugin system creep.** Defer until three real plugins are
   requested.
10. **Per-compositor branching.** Niri-only by policy; no abstraction
    until a second compositor is actually targeted.
11. **Excessive blur layers.** Allowlist surfaces; do not blur every
    popout root.
12. **Lint configured but ineffective.** `qmllint` must run with `-I`
    paths and a project `qmldir`; otherwise it silently skips singleton
    resolution.

---

## Repository Conventions

### File and directory naming

- Components, widgets, modules: PascalCase QML filenames (`Surface.qml`,
  `BatteryWidget.qml`, `Bar.qml`).
- Singletons: PascalCase with `pragma Singleton` and a `qmldir` entry.
- JavaScript helpers: lowercase or kebab-case `.js` files.
- Module directories: lowercase (`modules/bar/`, `modules/launcher/`).

### `qmldir` requirements

- One root `qmldir` for project-wide singletons.
- Per-directory `qmldir` files registering local types where needed.
- `scripts/lint.sh` must include `-I .` and a real `qmllint` config.

### Imports

- Project-local imports use a stable namespace (e.g.,
  `import qs.theme`, `import qs.services`).
- Quickshell and Qt imports first, project imports second, blank line
  between.

### Comments

- English only.
- Comment the why, not the what.
- No TODOs in committed code. Open an issue instead.

### Commits

- Atomic, single-concern.
- Conventional structure encouraged but not enforced.
- Pre-commit hooks (qmllint, qmlformat, validate) must pass.

### Reference repositories

- `DankMaterialShell/` and `noctalia-shell/` are in `.gitignore` and
  pruned from lint/format paths.
- They are documentation-only — no runtime code imports from them.
- Consider extracting to git submodules outside the working tree.
