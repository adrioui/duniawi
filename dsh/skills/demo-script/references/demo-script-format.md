# Demo Script Segment Format

Each demo script is a sequence of **segments**. One segment = one user-visible flow (e.g., "Add Data Lake Source," "Browse Schema," "Invite Member").

## Segment Template

Use this structure for every segment in the generated script:

```markdown
### Segment N: {Flow Title}

**Design Reference:** `{relative path to screenshot PNG}`
> Show this screenshot on the LEFT side of the split-screen.

**Narration:**
> {1-3 sentences explaining what the user is doing and why. Written in present tense, second person ("You click Add Source..."). Keep it conversational for an internal audience.}

**Swagger UI Steps (RIGHT side):**

1. **Before state** (show current data):
   - **Endpoint:** `{METHOD} {path}`
   - **Headers:** `Authorization: Bearer {{token}}`
   - **Request body:** _(none, or JSON snippet)_
   - **Expected response:** `{status code}`
     ```json
     {expected response JSON — show key fields, use "..." for arrays with many items}
     ```
   - **What to highlight:** {e.g., "empty `items` array", "source count is 0"}

2. **Action** (perform the operation):
   - **Endpoint:** `{METHOD} {path}`
   - **Headers:** `Authorization: Bearer {{token}}`
   - **Request body:**
     ```json
     {full request JSON with realistic sample values}
     ```
   - **Expected response:** `{status code}`
     ```json
     {expected response JSON with key fields}
     ```
   - **What to highlight:** {e.g., "new source `id` returned", "status is `syncing`"}

3. **After state** (confirm the change):
   - **Endpoint:** `{METHOD} {path}`
   - _(same as Before state endpoint)_
   - **Expected response:** `{status code}`
     ```json
     {response showing the change — e.g., items array now has 1 entry}
     ```
   - **What to highlight:** {e.g., "items array now contains the new source"}

**Transition:** {One sentence bridging to the next segment, e.g., "Now that we have a source, let's browse its catalog."}

**Timing:** `{X min}` (per-segment, total 20-25 min)

**Hero:** `{⭐ if this is the wow moment}` — 1 hero per script max, pause after hero.
```

> **Rule:** Every segment MUST include `Timing` and `Hero` fields after `Transition`. Total script time 20-25 min. Only one segment may be marked `⭐ Hero`; presenter MUST pause narration briefly after the hero moment for effect.

## Rules

1. **Before/After is mandatory** for mutating operations (POST, PUT, DELETE). For read-only flows (browse catalog, view schema), skip Before/After and just show the GET response.

2. **Use realistic sample data.** For InfluxDB sources, use values like:
   - Host: `influxdb.example.com`
   - Port: `8086`
   - Token: `my-influxdb-token`
   - Organization: `my-org`
   - Bucket: `metrics`
   - Source name: `Production Metrics`

3. **Response JSON should be representative, not exhaustive.** Show 1-2 items in arrays, use `"..."` to indicate more. Include all key fields the narration references.

4. **One segment per flow.** Don't combine unrelated flows. If a flow has sub-steps (e.g., test connection then create source), keep them as sequential steps within the same segment.

5. **Number segments sequentially** across the entire script. A full Data Lake demo might have 8-10 segments.

6. **Design reference paths** are relative to the design directory the user provides. Use the exact filename from the directory listing.

7. **Mark one hero segment** (e.g., access-control 403->200 or CLI sweep rotated:0->1), pause narration after it. Choose the single most impressive state change as `⭐ Hero` — typically a permission flip, a sweep that proves rotation, or a before/after that lands the demo's value prop. 1 hero per script max; presenter pauses 2-3 seconds after the hero response to let it land.

8. **Each segment footer MUST include Source Links and Fallback.** After `Timing`/`Hero`, append:
   - **Source Links:** `views.py:Lxx`, `schemas.py:Lxx`, ADR or runbook link (e.g., `docs/adr/012-rotation.md`, `runbooks/rotate_keys.md`). Use real line numbers from the repo.
   - **Fallback line:** `If 500, say X and show Y` — e.g., `Fallback: If 500, say "rotation is async — check logs" and show \`docker logs rotate_keys\` tail.` Never leave a segment without a recovery line.

## Segment Ordering Convention

When generating a full-feature demo, order segments to tell a coherent story:

1. List sources (empty state)
2. Add/create source (with test connection)
3. Browse catalog (datasets > tables > columns)
4. View schema + Copy SQL
5. Preview data
6. Edit connection
7. Access control (invite, accept, update role, remove)
8. Delete source

> **Retention note:** Place hero segment at 60-70% through script for retention. For an 8-segment script this is Segment 5-6; for 10 segments, Segment 6-7. Don't open or close with the hero — peak the middle, then resolve.

### CLI-Only Segment Variant (when no Swagger)

When a flow has **0 Swagger routes** and is CLI/script-only (e.g., `bliv-5622` rotation — only `scripts/rotate_keys.py`, no API; see `hack/bliv-5622-swagger-demo.md:48`), use this variant instead of Swagger UI Steps. Keep split-screen L/R intact — human delivers, not an agent GIF.

```markdown
### Segment N: {Flow Title} — CLI-Only

**Design Reference:** `{ADR or runbook path, e.g., docs/adr/012-rotation.md}` — rendered excerpt or diagram on LEFT side of split-screen (replaces screenshot; ADR/runbook instead of screenshot).

**Narration:**
> {1-3 sentences, same voice as standard segments. Explain the CLI action and why. E.g., "You run the rotation script to sweep expired keys..."}

**CLI Steps (RIGHT side):**

1. **Before state** (show current data):
   - **Command:** `{e.g., python scripts/rotate_keys.py --dry-run --json}`
   - **Env:** `{e.g., DRY_RUN=1 VAULT_ADDR=...}`
   - **Expected stdout (JSON):**
     ```json
     { "rotated": 0, "expired": 3, "errors": [] }
     ```
   - **Expected exit code:** `0`
   - **What to highlight:** {e.g., "rotated is 0 — nothing swept yet"}

2. **Action** (perform the operation):
   - **Command:** `{e.g., python scripts/rotate_keys.py --json}`
   - **Env:** `{e.g., VAULT_ADDR=... VAULT_TOKEN={{token}}}`
   - **Expected stdout (JSON):**
     ```json
     { "rotated": 1, "keys": [{"id": "k_abc123", "status": "rotated"}] }
     ```
   - **Expected exit code:** `0`
   - **What to highlight:** {e.g., "rotated flipped 0->1, new key id returned"}

3. **After state** (confirm the change):
   - **Command:** `{e.g., python scripts/rotate_keys.py --dry-run --json}`
   - **Expected stdout (JSON):**
     ```json
     { "rotated": 0, "expired": 0, "keys": [{"id": "k_abc123", "status": "active"}] }
     ```
   - **Expected exit code:** `0`
   - **What to highlight:** {e.g., "expired is now 0 — sweep succeeded"}

**Transition:** {One sentence bridging to next segment.}

**Timing:** `{X min}` (per-segment, total 20-25 min)

**Hero:** `{⭐ if this is the wow moment}` — 1 hero per script max, pause after hero.

**Source Links:** `scripts/rotate_keys.py:Lxx`, `docs/adr/012-rotation.md` or `runbooks/rotate_keys.md`

**Fallback:** `If non-zero exit / 500, say "X" and show Y` — e.g., `Fallback: If exit 1, say "vault unreachable — check VAULT_ADDR" and show \`vault status\`.`
```

**Mapping table — Swagger → CLI translation:**

| Swagger concept | CLI equivalent |
|---|---|
| Endpoint `METHOD /path` | Command `python scripts/<name>.py [--flags] --json` |
| Response JSON (HTTP body) | stdout JSON (parse with `jq`) |
| HTTP status `200` / `4xx` / `500` | Exit code `0` / `2` / `1` (or script-specific codes; document in segment) |
| ID-chain (`id` from create → used in next GET) | Counter-chain (`rotated:0->1`, `expired:3->0`, or emitted `key id` reused in verify step) |
| L-pane = screenshot PNG | L-pane = ADR/runbook excerpt or architecture diagram |
| R-pane = Swagger UI (Endpoint + Headers + Body) | R-pane = Terminal (Command + Env + stdout JSON + exit code) |

**When to use which:**

- If `rg -l "swagger|openapi|APIRouter|@app\.(get|post)"` finds routes for the flow → use standard Swagger UI Steps.
- If 0 routes and only `scripts/*.py` / `bin/*` exists (validated at `hack/bliv-5622-swagger-demo.md:48` for `bliv-5622`) → use CLI-Only Variant. Do not invent Swagger endpoints — validate CLI-only case explicitly.
