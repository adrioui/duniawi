---
name: why
description: "Use for \"why does X work this way\", \"why we picked Y\", design rationale, regressions, postmortems, or data-backed thresholds. Discovers available MCPs and queries each evidence category (source control, issue tracker, long-form docs, real-time chat, infrastructure observability, error tracking, product analytics warehouse) in parallel, then returns a cited read on decisions and tradeoffs. Use how for runtime behavior."
---

# Why

Status: stub — full port lands in M2.

Approximate behavior until then:

- Posture: evidence before narrative, cite everything, prefer "appears to" over "because", name gaps, no shortcut by code-reading. The code says what it does, rarely why it exists.
- Anchor first: `git blame` / `git log --follow` on the target, then pull PR bodies and discussion via `gh pr view`.
- Fan out one investigator per available evidence category: source control (git + gh, always), issue tracker, long-form docs, team chat, infra observability, error tracking, analytics warehouse. Null results are first-class evidence; skip a category only with a written justification.
- Synthesize into: What We Found (direct, cited), What We Can Reasonably Infer (hedged), Competing Hypotheses, What We Don't Know, Sources Consulted. When presenting, never rewrite the confidence language.
- DSH mechanics: investigators are `workflow` fan-out agents or parallel `subagent` calls; web search via executor MCP `tools.search`. Investigators on configured workers route, synthesis on configured judgment route.
