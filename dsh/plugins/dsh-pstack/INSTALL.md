# Install pstack-dsh

## Requirements

- DeepSeek Harness with an initialized profile.
- Node.js 22 or newer.
- pnpm for checkout-based installation.
- Bun only for the optional `orch` and `watch-pr` helpers.
- Authenticated `gh` for PR playbooks.

## Install the native plugin

The package has a host entry and a Web client entry. Add the package to the target profile and mount it in Cordis.

Add this dependency to `~/.dsh/profiles/web/package.json`:

```json
{
  "dependencies": {
    "@wayanjimmy/dsh-pstack": "file:../../../clones/labs/pstack-dsh"
  }
}
```

Add this entry to `~/.dsh/profiles/web/cordis.patch.yml`:

```yaml
- insert:
    - id: pstack
      name: '@wayanjimmy/dsh-pstack'
```

Install and restart the existing Web process:

```bash
pnpm --dir ~/.dsh/profiles/web install
```

Repeat the dependency and patch for another initialized profile, such as `headless`, when it should expose the packaged skills.

## Configure model routes

Open **Settings → Plugins → Plugin configuration → pstack**.

The card configures Code, Judgment, and Workers. A route may use a model on the current provider, an explicit provider/model pair, or the current chat model.

The defaults are `gpt-5.6-terra`, `gpt-5.6-sol`, and `gpt-5.6-luna`. The live catalog comes from DSH. Provider discovery failures remain isolated.

Settings are stored under the `pstack` namespace in `~/.dsh/settings.yaml` and apply to later skill loads.

## Migrate a filesystem installation

The plugin imports only missing roles from `~/.dsh/pstack-models.json`; native user settings win per role. It does not delete the legacy file.

Verify the package first:

```bash
curl -fsS http://127.0.0.1:3080/pstack/status
```

The response must report provider `pstack`, a path under `node_modules/@wayanjimmy/dsh-pstack/skills`, the packaged skill count, and the expected routes.

Preview the cutover first, then apply it:

```bash
node scripts/remove-legacy-install.mjs
node scripts/remove-legacy-install.mjs --apply
```

The script refuses migration unless the package-backed provider is active. It verifies unchanged legacy skills against a checked-in digest manifest and moves them, plus the legacy JSON mapping, into a recoverable `~/.dsh/pstack-legacy-backup/` directory. Modified matching skills are refused unless `--force-modified` is explicitly combined with `--apply`.

## Verify

```bash
pnpm install
pnpm verify
node scripts/verify-web.mjs
curl -fsS http://127.0.0.1:3080/pstack/models
curl -fsS http://127.0.0.1:3080/pstack/status
```

The Web verifier opens the sidebar, navigates to Plugins, and expands the pstack card in the existing GUI.

## Standalone Agent Skills mode

```bash
npx skills add wayanjimmy/pstack-dsh
```

Standalone mode has no native settings card. Model routing remains the responsibility of that agent environment.

## Known limitations

- `how`, `why`, `architect`, `unslop`, and `show-me-your-work` remain short M2 ports.
- `orchestrate` and `autopilot-*` playbooks are not yet ported.
- Cursor-only sticky mode, automations, and named subagent types have no direct DSH equivalent.
- The Web client bundle is checked in. File-dependency changes require reinstalling the package and restarting the existing Web process.
