# WoWshell Services Architecture

## Philosophy

Services provide centralized runtime functionality.

Services should:

- remain lightweight
- avoid UI logic
- expose explicit responsibilities
- isolate runtime state

---

## Service Rules

Services:

- must not import UI modules
- may expose reactive state
- should avoid hidden side effects
- should support graceful degradation

Widgets may consume services.

Modules compose widgets.

---

## Planned Services

Examples:

- audio service
- media service
- notification service
- network service
- wallpaper service
- power service
- brightness service
- workspace service

---

## Runtime Reliability

Services should:

- validate runtime dependencies
- tolerate missing DBus services
- tolerate disconnected hardware
- expose safe fallback state
