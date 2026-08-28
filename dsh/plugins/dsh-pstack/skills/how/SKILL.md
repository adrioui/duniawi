---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Can critique architecture. Use why for motivation."
---

# How

Status: stub — full port lands in M2.

Approximate behavior until then:

- Two modes: **Explain** (default) and **Critique**.
- Explain: parse the question, state your best-guess scope, don't ask. Simple (one module, narrow question): explore and explain in one pass. Complex (subsystem, cross-cutting flow): fan out 2-4 parallel explorers, one distinct slice each (data model, request path, config/metrics), each tracing entry point to effect in real code and noting what a newcomer would get wrong; then one synthesizer reconciles the slices into a single explanation.
- Output format: Overview, Key Concepts, How It Works (prose, cite files and functions), Where Things Live, Gotchas.
- Critique: explain first, then N critics (different models) independently flag architectural issues; the lead sorts Act on / Consider / Noted / Dismissed. Present the explanation, then the verdict below it.
- DSH mechanics: explorers / synthesizer / critics are `workflow` agents or `subagent` calls. Cheap exploration on configured workers route, explanation and judgment on configured judgment route.
