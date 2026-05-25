# WoWshell State Management

## Philosophy

WoWshell uses lightweight centralized state.

Avoid:

- giant global stores
- excessive reactive dependencies
- hidden shared mutable state

---

## State Categories

### Persistent State

Examples:

- theme configuration
- monitor preferences
- enabled modules

---

### Runtime State

Examples:

- notifications
- media state
- network status
- active workspace

---

## Rules

- services own runtime data
- widgets consume state
- modules compose widgets
- utils remain pure
