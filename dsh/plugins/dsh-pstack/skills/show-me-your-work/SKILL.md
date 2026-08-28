---
name: show-me-your-work
description: "Keep a reviewable decision trail for long-running or unattended work: a TSV log with one row per decision (what, why, evidence, result). Local by default; commit it when a reviewer needs the trail to trust the result. Use for /show-me-your-work, autonomous or multi-phase runs, or work a human reviews after stepping away."
---

# Show me your work

Status: stub — full port lands in M2.

Approximate behavior until then:

- One canonical TSV log, one row per decision or checkpoint: `ts / phase / decision / why / evidence / result`. Evidence is a pointer (commit SHA, PR number, `file:line`, artifact path), never a paragraph.
- Local by default: `decisions.tsv` in the work dir, or `.audit/<task-slug>.tsv` for several efforts. Commit it only when a reviewer needs the trail to trust the result; GitHub renders the TSV as a table in the PR.
- Log forks chosen, units completed with their verification result, pivots and reverts with their trigger, blockers, gates fixed. Append-only: a wrong call gets a superseding row, never an edit or delete.
- Before handing back, audit the log against the transcript: every row maps to a real action, each evidence pointer resolves, missing pivots get added. Fix the log, not the story.
- Then a cross-model review: a subagent on a different model reads the trail and transcript and flags weak evidence, skipped verification, hindsight-risky choices; end with an "Attention" section (`reviewed by <model>`, then the flags). "No flags" is valid; the model name is not.
- DSH mechanics: rows via the log script or a plain `printf` append; reviewer on the judgment role (poteto-mode MODEL TABLE, remap via `Settings > Plugins > pstack`). When default IDs are absent, any two distinct models you do have preserve the cross-model check.
