# DSH delegation model

This replaces Cursor's Task-tool documentation. DSH has one local harness, no cloud split, no background-agent dashboard. Delegate through the tools below. There is no `subagent_type` to configure.

## When to use which tool

| Shape | Tool |
| --- | --- |
| Fan-out, pipelines, review panels, swarm grids | **workflow** (scripted orchestrator) |
| One or two one-off delegations | **subagent** (no shared context) or **subagent_fork** (inherits this conversation) |
| Autonomous / multi-round / long-running | **goal** tools (create_goal / get_goal / update_goal) |
| Long bash / script | background bash job (run_in_background: true) |
| Sidecar question to the human | **ask_user_question** |
| Resume / pickup / pause cleanly | **handoff** skill + goal pause/resume |

The rule of thumb. You fork into independent pieces → **workflow**. You need one extra brain on a defined task the current flow already framed → **subagent** or **subagent_fork**. You want to run until a predicate → **goal** tools.

## workflow tool

A scripted orchestrator. You write a plain-JS body (top-level `await`, no TS enums) that coordinates subagents and returns a JSON value. It fans work out, validates results, and reports phase progress. Identity rides the `meta` param as JSON: required `name` and `description`, optional `whenToUse` and `phases`. Meta is never code.

Hooks inside the script body.

- **agent(prompt, opts)**. Runs one subagent to completion. Without `opts.schema` it resolves to the child's final text; with `opts.schema` (an object-rooted JSON Schema using only type/properties/required/additionalProperties/items/enum/const/oneOf) it resolves to the validated object. A failed child resolves `null`; filter with `.filter(Boolean)`. Other opts: `label` (display), `phase` (progress group), independent `provider` / `model` overrides (either may stand alone). Anything else is rejected loudly.
- **pipeline(items, ...stages)**. Runs each item through the stages independently with no barrier between stages. Each stage receives `(prev, item, index)`. A stage throwing drops that item to `null` and skips its later stages.
- **parallel(thunks)**. Runs zero-argument functions concurrently and awaits all of them (a barrier). A throwing thunk resolves to `null`.
- **phase(title)** starts a progress phase; **log(message)** narrates progress; **args** is the tool call's args verbatim.

Constraints: concurrency and total-agent caps apply. No filesystem, network, timers, or Node APIs inside the script; the agents do the work, the script only coordinates.

## Model overrides

The native plugin appends `<pstack_model_routes>` to every loaded pstack skill. It contains code, judgment, and workers routes. A route is `provider/model`, a model on the current provider, or `inherit`. Spread the resolved route into each `agent` call. For `inherit`, omit both fields. An unavailable explicit route is a configuration error. Do not silently substitute another model. Configure routes under Settings > Plugins > pstack.

## subagent vs subagent_fork

- **subagent** starts a child with a self-contained prompt. It does not see this conversation. Use it for a task you can describe completely in the prompt. Runs in the background by default and returns a durable subagent id; a notice arrives when it settles.
- **subagent_fork** seeds a child with this conversation's completed turns (not the current in-flight turn). Use it for a follow-up, review, or continuation that builds on this context.

Set `run_in_background: false` only when the next action depends on the result. Otherwise run in the background and keep working.

## send_message / list_agents

- **send_message(subagent_id, message)**. Continues the same subagent conversation. If the target is still working, the message waits until its current turn finishes. Returns delivery confirmation, not an answer. A failure means not delivered.
- **list_agents()**. Recalls spawned subagents (children, or the full descendant tree). Status is informational; you are notified when a run settles. Use it to remember which you started, not to poll.

You own every worker's work regardless of tool. Review the diff, write your own summary, verify against the real artifact (**principle-prove-it-works**). Agreement across models is high-signal.

## Goal tools for long-running work

Autonomous continuation (the old `/loop`) is the goal tools. `create_goal` starts a persisted same-session completion goal with an objective and an optional `max_goal_rounds` cap. `get_goal` reads the current goal, its revision, rounds, and blocker. `update_goal` edits, pauses, resumes, completes, or marks it blocked. Automatic continuation rounds are driven by the goal machinery. For a task the human steps away from, pair the goal with a **handoff** doc so a resume or a successor picks up cleanly.

## Other tools

- **Background bash jobs.** For a long bash command, `run_in_background: true`. Returns a job id immediately. Read with `job_output`, stop with `job_kill`, list with `job_list`. You are notified when a job settles; don't busy-poll.
- **ask_user_question.** Ask the human only what an experiment cannot settle. Per Autonomy, reversible work proceeds without asking. Shape the ask as a stable-id question with options.

## Worked example

A complete workflow script body. Pass its identity and phases separately through the workflow tool's `meta` parameter. Resolve `judgmentRoute` from the appended model routes before constructing the script.

```js
const judgmentRoute = {}; // use { provider, model }, { model }, or {} for inherit

const findingSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    endpoint: { type: 'string' },
    ok: { type: 'boolean' },
    rootCause: { type: 'string' },
    whichCommit: { type: 'string' },
    artifacts: { type: 'array', items: { type: 'string' } }
  },
  required: ['endpoint', 'ok', 'rootCause', 'whichCommit']
};

const endpoints = ['/login', '/checkout', '/sync'];

const investigated = await parallel(endpoints.map((ep) => () =>
  agent(
    'Investigate endpoint ' + ep + ' against the flaky-service regression report. ' +
    'Trace logs and blame to a root cause and the commit that introduced it.',
    { ...judgmentRoute, label: ep, phase: 'investigate', schema: findingSchema }
  )
));

const found = investigated.filter(Boolean);
const faulty = found.filter((f) => !f.ok);

const decisionSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    blocking: { type: 'array', items: { type: 'string' } },
    fixUnits: { type: 'array', items: { type: 'string' } }
  },
  required: ['blocking', 'fixUnits']
};

const decision = await agent(
  'Reconcile these endpoint findings. List blocking root causes and the fix units ' +
  'that would address them, most severe first.',
  { ...judgmentRoute, phase: 'reconcile', schema: decisionSchema }
);

return { healthy: found.filter((f) => f.ok), faulty, decision };
```
