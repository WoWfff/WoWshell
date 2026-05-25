# WoWshell Theming System

## Design Goals

The theme system should:

- support Material You inspired styling
- support wallpaper-based colors
- remain performant
- avoid excessive redraws
- support hot reload

---

## Theme Responsibilities

- colors
- spacing
- radii
- blur rules
- typography
- animation constants

---

## Performance Rules

Avoid:

- unnecessary full-theme recalculations
- excessive reactive propagation
- expensive color recomputation

Prefer:

- cached palette generation
- isolated theme updates
- efficient propagation
