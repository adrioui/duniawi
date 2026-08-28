---
name: demo-script
description: Generate split-screen demo scripts pairing UI design screenshots with Swagger UI API walk-throughs. Use when you need to create an internal demo video script for a feature, showing design mockups alongside live API calls. Also generates a meta-prompt for endpoint verification. Triggers on "demo script", "create demo", "generate demo", "swagger demo", or "/demo-script". Also handles CLI-only features via Command/Env/stdout mapping.
---

# Demo Script Generator

Generate a narrated demo script that pairs design mockup screenshots (left) with Swagger UI API walk-throughs (right) in a split-screen format. Aimed at internal team demos. The human delivers the walkthrough; Swagger (or CLI stdout) is the source of truth — never an agent-run GIF/D3. Split-screen L/R layout is always preserved.

## Workflow

### Header Block (REQUIRED — every script MUST start here)

Every generated demo script MUST begin with a Header Block containing:

- **Audience** — Who the demo is for (e.g., internal team, stakeholders, onboarding).
- **Time-box** — One of 20 / 30 / 45 min. Drives segment depth and pacing.
- **Scope** — `full` (all flows discovered in the design directory) vs `single-flow` (one named flow).
- **Base URL + auth** — Target host, base path, and auth mechanism (e.g., `https://api.example.com/api/v1`, Bearer/JWT, API key).
- **Runbook / ADR links** — Links or paths to the runbook and ADR(s) governing the feature.

If any header field is unknown, leave it as `TBD` and call it out explicitly. Do not omit the header.

### Step 0: Setup & Teardown (MANDATORY before Step 1)

Before gathering design/API inputs, emit a Setup & Teardown block:

**Setup (run before recording):**
```bash
docker compose up -d
# run migrations
make migrate  # or: alembic upgrade head / ./manage.py migrate / etc. — adapt to repo
# seed data if applicable
make seed     # or: python scripts/seed.py
```

**Teardown (run after recording / to reset):**
```bash
docker compose down -v
# DB reset (adapt to repo)
make db:reset  # or: dropdb/createdb, docker volume rm, etc.
```

- Keep commands idempotent so the script can be re-run.
- State the idempotent re-run note explicitly in the output (e.g., "Re-running setup from a clean state yields the same demo.").
- This step is mandatory even for CLI-only features — setup still provisions the environment the CLI runs against.

### Step 1: Gather Inputs

Ask the user for (or detect from context):

1. **Design directory** — Path to a directory containing PNG/JPG screenshots of the UI design (e.g., `tmp/design/data lake/`). List its contents with subdirectories.
2. **API source files** — Path(s) to the backend `views.py` and `schemas.py` (e.g., `src/backend_data_house/api/data_lake/`). Read both files fully. For CLI-only features, this is the command entry point (e.g., `scripts/rotate_keys.py`).
3. **Scope** — Either:
   - **Full feature**: Generate segments for all flows discovered in the design directory.
   - **Single flow**: Generate a segment for one specific flow (user specifies which).

### Step 2: Discover & Map

1. **List all screenshots** in the design directory (recursively). Group by subdirectory or naming convention.
2. **Read `views.py`** to extract all route definitions: method, path, request/response schema names. For CLI-only features, read the CLI entry point (e.g., `scripts/rotate_keys.py`) to extract commands/subcommands, flags, and exit codes.
3. **Read `schemas.py`** to understand request/response shapes, field names, types, and nested structures. For CLI-only features, read the stdout/JSON shapes (e.g., `RotationStats`).
4. **Map each design screenshot to its corresponding API endpoint(s).** Use the screenshot filename and visual content to match against route paths. For CLI-only features, map Endpoint→Command, Response JSON→stdout JSON, status code→exit code, ID-chain→counter-chain. Document this mapping explicitly before generating.

### Step 3: Generate Demo Script

Using the segment format from `demo-script-format.md`:

1. **Order segments** following the convention in the format reference (empty state → create → browse → edit → access control → delete).
2. **Write each segment** with:
   - Design reference pointing to the actual screenshot file
   - Narration in present tense, second person, conversational tone
   - Swagger UI steps with realistic request/response JSON derived from the schemas (or Command + Env + stdout JSON for CLI-only)
   - Before/after pattern for all mutating operations
   - Transition sentence to the next segment
3. **For single-flow scope**, generate only the requested segment(s) but still include appropriate before/after context.

Output the complete demo script as a markdown document.

### Step 4: Generate Meta-Prompt

Using the template from `meta-prompt-template.md`:

1. **Convert every Swagger UI step** from the demo script into a curl command. For CLI-only features, convert to shell commands against the CLI entry point.
2. **Chain IDs** using shell variable exports (or counter-chain for CLI rotation flows).
3. **Add negative tests** for permission boundaries (e.g., viewer attempting admin actions; CLI: unauthorized role attempting rotation).
4. **Include cleanup** to delete all test-created resources.

Output the meta-prompt as a separate markdown document (or a clearly separated section).

### Step 5: Deliver

Present both outputs to the user:
- The demo script (for recording the video)
- The meta-prompt (for verifying endpoints work correctly)

Suggest the user review the demo script, then hand the meta-prompt to a separate agent or run it manually to validate responses before recording.

### Step 6: Rehearsal Gate (MANDATORY after Deliver — before recording)

Borrowing the warpdotdev validator-mandate pattern: do not record until the gate passes.

- **Run meta-prompt before recording; all Before/After deltas must pass; do not record if any fail.**
- Execute every curl/command chain from the meta-prompt against the setup environment from Step 0.
- Each mutating operation's Before/After delta (counts, fields, counters) must match the expected values in the demo script.
- If any delta fails, fix the script or the environment and re-run the full gate. Recording is blocked until 100% of deltas pass.
- Record the gate result (pass/fail per segment) in the script appendix or as a checklist.

## Handling Edge Cases

- **No design screenshots available**: Generate a Swagger-UI-only demo script (right side only). Skip design references and narration about visual elements.
- **API not yet implemented**: Note which endpoints are planned but not yet available. Mark those segments as "placeholder" with expected schemas from the plan.
- **Multiple connector types**: If the feature supports multiple backends, ask the user which connector to use for sample data. Default to the first/primary connector.
- **CLI-only (no Swagger)**: Some features expose no HTTP routes and are validated entirely via CLI. In that case:
  - **L (left)** = ADR / runbook panel — no screenshots. Reference the governing ADR/runbook directly.
  - **R (right)** = Command + Env + stdout `RotationStats` JSON + exit code (instead of Swagger request/response + HTTP status).
  - **Token mapping**: `Endpoint → Command`, `Response JSON → stdout JSON`, `HTTP status → exit code`, `ID-chain → counter-chain`.
  - Keep split-screen L/R intact; do not collapse to a single pane or convert to an agent-run GIF/D3.
  - **Canonical example**: `bliv-5622` key rotation — `0` Swagger routes, validated via `scripts/rotate_keys.py` with subcommands `status | verify | sweep` (see `hack/bliv-5622-swagger-demo.md:48` where the Swagger gap was proved).

## References

- `~/.maka/skills/demo-script/references/demo-script-format.md` — Segment template and ordering conventions (split-screen L/R, Before/After pattern, single-flow vs full; **CLI-Only Segment Variant** for features with no Swagger)
- `~/.maka/skills/demo-script/references/meta-prompt-template.md` — Meta-prompt template for endpoint verification (curl chains, negative tests, cleanup; **CLI-Mode** shell assertions + exit codes for CLI-only features)
