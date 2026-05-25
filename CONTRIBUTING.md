# Contributing to WoWshell

## Engineering Standards

WoWshell follows strict engineering and maintainability principles.

All contributions must prioritize:

- readability
- modularity
- performance
- runtime stability
- predictable behavior

---

## Clean Code Rules

Strictly follow:

- DRY (Don't Repeat Yourself)
- KISS (Keep It Simple, Stupid)
- Separation of Concerns
- Composition over Inheritance
- Explicit Responsibilities

Avoid:

- giant monolithic files
- duplicated logic
- hidden side effects
- unnecessary abstractions
- speculative implementations
- placeholder code
- fake APIs

---

## QML Rules

Use:

- PascalCase for components
- camelCase for properties/functions
- descriptive IDs

Avoid:

- deeply nested bindings
- excessive reactive chains
- unnecessary redraw triggers
- hidden implicit behavior

---

## Commit Rules

Prefer:

- small scoped commits
- incremental refactors
- atomic changes

Avoid:

- giant rewrites
- unrelated changes in one commit

---

## Validation Requirements

Before committing:

- run qmllint
- run qmlformat
- validate runtime behavior
- verify startup safety
- verify module isolation

Never bypass validation hooks.

---

## Animation Philosophy

Animations should:

- improve usability
- feel polished
- remain subtle
- avoid distracting the user
- preserve runtime responsiveness

---

## Performance Philosophy

Always optimize:

- startup speed
- memory usage
- redraw efficiency
- reactive update efficiency

Avoid unnecessary allocations and expensive visual effects.
