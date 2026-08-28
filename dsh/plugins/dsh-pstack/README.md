# pstack-dsh

pstack-dsh is a DeepSeek Harness port of [pstack](https://github.com/cursor/plugins/tree/main/pstack), the coding-skills plugin by Lauren Tan. It keeps the same thesis. Go deep before going fast. Write less code. Prove it works. Parallelize only when the work remains reviewable.

The repository now ships as a native DSH plugin. The package owns the skills, model-role settings, packaged skill provider, live model catalog, and Web settings card.

**Status:** native plugin + core skill + 21 principles + 20 playbooks. The M2 skills remain short ports.

## Install in DSH

Mount `@wayanjimmy/dsh-pstack` as a file dependency in the target DSH profile and add it to `cordis.patch.yml`:

```json
{
  "dependencies": {
    "@wayanjimmy/dsh-pstack": "file:../../../clones/labs/pstack-dsh"
  }
}
```

```yaml
- insert:
    - id: pstack
      name: '@wayanjimmy/dsh-pstack'
```

Run `pnpm --dir ~/.dsh/profiles/web install`, then restart the existing `dsh web` process. The settings card appears under **Settings → Plugins → Plugin configuration → pstack**.

For agents that only implement the Agent Skills standard, standalone installation remains available:

```bash
npx skills add wayanjimmy/pstack-dsh
```

Standalone mode does not provide native model-role settings. See [INSTALL.md](./INSTALL.md) for migration and verification.

## Get started

1. Install the native plugin.
2. Configure model routes in Settings → Plugins → pstack.
3. Run `/poteto-mode` for work that needs rigorous investigation, implementation, or verification.

```text
/poteto-mode this PR has a subtle bug where the scroll drifts every 750ms even when idle. Reproduce it first, then fix and verify.
```

## Model routes

| role | default |
|---|---|
| code and delegated implementation | gpt-5.6-terra |
| judgment, review panels, forensics, orchestration | gpt-5.6-sol |
| swarm workers and cheap parallel work | gpt-5.6-luna |

Each route may use the current provider, an explicit provider/model pair, or the current chat model. The plugin appends the effective routes to every loaded pstack skill. Concrete model IDs no longer live in skill prose.

Legacy `~/.dsh/pstack-models.json` values fill only roles that are still absent from the native `pstack` settings section. Remove the legacy file only after the package-backed provider and effective routes are verified.

## Verification

```bash
pnpm install
pnpm verify
node scripts/verify-web.mjs
```

`pnpm verify` tests the host and loads every packaged skill. `verify-web.mjs` drives the existing GUI in headless Chrome and checks the pstack settings card on the real Web surface.

Runtime status is available at `http://127.0.0.1:3080/pstack/status`.

## PR flow

Use flat GitHub PRs through `gh`. Do not use Graphite or stacked-PR tooling.

## What changed from Cursor pstack

| Cursor pstack | pstack-dsh |
|---|---|
| Cursor plugin manifest | DSH npm plugin package and Cordis profile entry |
| `.cursor/rules/pstack-models.mdc` | native `pstack` settings namespace and settings card |
| Task and named subagent types | DSH workflow, subagent, and goal tools |
| Cursor sticky mode | explicit `/poteto-mode` invocation |
| Cursor model slug discovery | live DSH provider/model catalog |
| cloud/background split | one local DSH harness |
| Graphite-oriented helpers | flat GitHub PR flow |
