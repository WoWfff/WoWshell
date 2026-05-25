# WoWshell Project Context

## Overview

WoWshell is a production-grade modular Quickshell desktop shell focused on:

- maintainability
- performance
- responsive reactive architecture
- elegant Material You inspired design
- subtle polished visual effects
- runtime stability
- long-term scalability

The project targets:

- Wayland-only architecture
- Niri compositor
- Qt6
- latest Quickshell version
- Arch Linux

Reference repositories:

- DankMaterialShell
- noctalia-shell

These repositories may be used for:

- architecture inspiration
- implementation inspiration
- reusable concepts
- adapted/refactored logic

Never blindly copy implementations.
Always analyze architecture and performance implications first.

---

## Engineering Philosophy

WoWshell prioritizes:

- maintainability over cleverness
- performance over unnecessary effects
- modularity over monolithic design
- predictable behavior over hidden magic
- clarity over abstraction
- production-grade reliability

The shell should feel:

- modern
- polished
- responsive
- elegant
- lightweight

Animations and effects are important, but must remain subtle and performant.

---

## Architecture Philosophy

Preferred architecture:

- modular component-based design
- isolated widgets
- lightweight centralized services
- reactive state updates
- explicit responsibilities
- composition over inheritance

Avoid:

- giant QML files
- tightly coupled modules
- hidden side effects
- overengineered state systems
- excessive reactive complexity
- duplicated logic

---

## Performance Philosophy

Performance is critical.

Optimize:

- startup speed
- memory usage
- redraw efficiency
- reactive update efficiency
- GPU usage
- animation smoothness

Avoid:

- excessive blur
- heavy polling
- unnecessary timers
- large reactive chains
- excessive redraws
- expensive property recalculations

Use lazy loading and deferred initialization where beneficial.

---

## Visual Design Philosophy

WoWshell follows:

- Material You inspired aesthetics
- subtle transparency
- soft rounded corners
- tasteful blur usage
- responsive animations
- wallpaper-based dynamic theming

Animations should:

- enhance usability
- improve perceived smoothness
- remain performant
- avoid distracting the user

---

## State Management

Use lightweight centralized state.

Recommended structure:

- services/
- state/
- theme/
- config/

Rules:

- services must not import UI modules
- widgets may use services
- modules compose widgets
- utils contain pure helper logic

---

## Modularity Rules

Preferred structure:

- components/
- widgets/
- modules/
- services/
- state/
- theme/
- utils/
- scripts/
- config/

Prefer focused modules.
Avoid meaningless micro-files.

---

## Validation Workflow

All changes should support:

- qmllint
- qmlformat
- qmlls
- pre-commit hooks

Before finalizing:

- verify bindings
- verify imports
- verify runtime consistency
- verify state synchronization
- verify object lifetimes
- verify signal connections

---

## Runtime Reliability

Always support:

- graceful degradation
- fallback behavior
- defensive runtime handling
- module isolation
- safe state transitions

Never assume ideal runtime conditions.
