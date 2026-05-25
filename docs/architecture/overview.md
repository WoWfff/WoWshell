# WoWshell Architecture Overview

## Architecture Goals

WoWshell prioritizes:

- maintainability
- modularity
- performance
- runtime stability
- responsive UI
- predictable behavior

---

## Architectural Style

WoWshell uses:

- modular component-based architecture
- lightweight centralized services
- reactive UI updates
- isolated widgets
- composition over inheritance

---

## Layering

### Services

Responsible for:

- DBus integration
- media
- network
- notifications
- wallpaper
- power management

Services must never depend on UI modules.

---

### Widgets

Reusable UI components.

Widgets may depend on:

- services
- theme
- state
- utils

Widgets should remain focused and isolated.

---

### Modules

Compose widgets into larger shell features.

Examples:

- bar
- launcher
- dashboard
- notifications

---

### Theme

Responsible for:

- Material You palette
- spacing
- radii
- blur rules
- animation constants

---

## Runtime Philosophy

If one module fails:

- the shell should continue running
- fallback behavior should activate
- failures should remain isolated
