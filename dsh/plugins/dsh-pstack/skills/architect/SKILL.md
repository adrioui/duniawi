---
name: architect
description: "Sketch types, signatures, and module structure before code, then stay in the loop while implementation fills in. Use for /architect, 'architect this', 'design this', or non-trivial work where jumping to code would lock in the wrong shape."
---

# Architect

Status: stub — full port lands in M2.

Approximate behavior until then:

- Five phases: **Ground → Sketch → Agree → Implement → Scrap**.
- Ground: run `how` over every system the new code touches; run `why` too when the design redefines ownership or layering. Naming a file isn't grounding. Skip only for greenfield.
- Sketch: design it twice: at least two structurally distinct candidates via arena-style fan-out; screen against design red flags (shallow modules, information leakage, temporal decomposition, pass-through methods); prefer the design that hides more complexity behind a smaller public surface.
- Agree: proceed by default; hold a human checkpoint only when asked ("with checkpoint").
- Implement against the sketch; deviations are signal, surface them, don't bolt them on.
- Scrap when friction repeats as a pattern (workaround shapes, escape-hatch types, repeated deviations): re-ground, redesign from first principles, subtract, re-sketch.
- DSH mechanics: candidates are parallel agents on the judgment role (poteto-mode MODEL TABLE; remap via `Settings > Plugins > pstack`), the lead synthesizes the decision.
