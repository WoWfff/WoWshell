# WoWshell Performance Philosophy

## Goals

Prioritize:

- low idle memory usage
- efficient rendering
- fast startup
- responsive animations
- stable frame pacing

---

## Avoid

- excessive blur
- expensive redraws
- heavy polling
- giant reactive chains
- persistent hidden widgets
- unnecessary allocations
- expensive property recalculations

---

## Preferred Patterns

- signal-driven updates
- lazy initialization
- deferred loading
- lightweight reusable widgets
- isolated reactive state

---

## Animation Rules

Animations should:

- remain subtle
- preserve responsiveness
- avoid excessive GPU load
- improve perceived smoothness
