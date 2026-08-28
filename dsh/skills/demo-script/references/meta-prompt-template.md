# Meta-Prompt Template

When the demo script is complete, generate a **meta-prompt** — a self-contained prompt that a separate agent (or human) can use to manually verify every endpoint shown in the demo against a running instance.

## Template

````markdown
# API Verification: {Feature Name}

You are verifying the {feature name} API endpoints against a running instance.

> Preamble — paste at the top of your shell session:
> ```bash
> set -euo pipefail
> ```
> **Fail fast; every step asserts.** If any assertion fails the session exits non-zero — fix before proceeding.

## Setup

**Base URL:** `{{base_url}}` (e.g., `http://localhost:8000`)

**Authentication:**
1. Obtain a Bearer token by logging in:
   ```bash
   curl -s -X POST {{base_url}}/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email": "admin@example.com", "password": "password"}' \
     | jq -r '.data.access_token'
   ```
2. Export it: `export TOKEN="<token from above>"`

**Second user (for access control tests):**
- Repeat login with a different user to get `TOKEN_B`

**Alternative Setup for CLI-only (when feature has no Swagger routes):**
- Export the secrets the CLI needs and bring up backing services:
  ```bash
  export BLIV_DATA_HOUSE_SECRET_KEY="dev-secret-not-for-prod"
  export BLIV_DATA_HOUSE_SECRET_KEY_PREVIOUS="old-secret-still-accepted"
  docker compose up -d postgres:15 redis:7 minio
  # Wait for readiness, e.g.:
  # docker compose exec postgres pg_isready && docker compose exec redis redis-cli ping
  ```
- Note: bliv-5622 rotation is CLI-only (`scripts/rotate_keys.py`); Alternative Setup is the correct path — 0 Swagger routes is expected.

## Verification Steps

Execute these commands **in order**. Each step depends on IDs returned by previous steps.

### Step 1: {Description}
```bash
curl -s -X {METHOD} {{base_url}}{path} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  {-d '{request body}' if applicable}
```
**Expect:** HTTP `{status}` with `{key field assertions}`
**Save:** `export {VAR_NAME}=$(echo $RESPONSE | jq -r '.data.{field}')`

### Step 2: {Description}
...

_(Continue for all endpoints exercised in the demo script)_

### CLI-Mode (when feature is CLI-only)

Use this sub-section instead of / in addition to curl steps when the feature is exercised via a CLI (e.g., `scripts/rotate_keys.py`). Assert exit codes and structured output fields.

```bash
set -euo pipefail

# 1) Verify current key — expect success
python -m scripts.rotate_keys verify; echo $?
# Expect: exit 0 (ok)

# 2) Rotate — assert RotationStats (or equivalent) fields with jq -e
STATS=$(python -m scripts.rotate_keys rotate --dry-run 2>&1 || true)
echo "$STATS" | jq -e '.rotated == 1 and .old_key == 0'

# Counter-chaining example (dry-run vs sweep):
# Before: rotated:0 / old_key:1  -> dry-run must leave counters unchanged
# After sweep: rotated:1
BEFORE_ROTATED=$(python -m scripts.rotate_keys verify --json | jq -r '.rotated')
BEFORE_OLD=$(python -m scripts.rotate_keys verify --json | jq -r '.old_key')
echo "before rotated:$BEFORE_ROTATED old_key:$BEFORE_OLD"
# Expect: rotated:0 old_key:1

python -m scripts.rotate_keys rotate   # real sweep
AFTER_ROTATED=$(python -m scripts.rotate_keys verify --json | jq -r '.rotated')
echo "after rotated:$AFTER_ROTATED"
# Expect: rotated:1 (delta +1)

# 3) Negative / corrupt-key check — expect non-zero
python -m scripts.rotate_keys verify --key corrupt 2>&1; echo $?
# Expect: exit 1 (old/corrupt key rejected)
```

> Shell mode: every assertion uses `jq -e` so a field mismatch fails the step. Never swallow exit codes with `|| true` outside the explicitly noted dry-run capture.

## Cleanup

After verification, remove test data to leave the environment clean:

```bash
# Delete test source (cascades to datasets, tables, access records)
curl -s -X DELETE {{base_url}}/api/v1/data-lake/sources/$SOURCE_ID \
  -H "Authorization: Bearer $TOKEN"
```

**CLI cleanup (when CLI-mode was used):**
```bash
# Tear down backing services and reset DB so counters return to baseline
docker compose down -v
# DB reset (choose the one your stack uses):
# docker compose exec postgres psql -U postgres -c "TRUNCATE rotation_stats CASCADE;"
# or: python -m scripts.reset_db --force
```

## Checklist

- [ ] All endpoints returned expected status codes
- [ ] Create operations returned valid IDs
- [ ] Before/after GETs confirmed mutations took effect
- [ ] Access control honored role restrictions
- [ ] Cleanup completed without errors
- [ ] CLI exit codes match (0 for ok, 1 for old/corrupt)
- [ ] Before/After counter deltas verified
````

## Rules for Generating Meta-Prompts

1. **Use `curl` with `jq`** for all commands. Pipe through `jq '.'` for readability.

2. **Chain IDs with shell variables.** When a step produces an ID needed later, include an `export` line. Use descriptive variable names: `SOURCE_ID`, `DATASET_ID`, `ACCESS_ID`, etc.

3. **Include negative tests** where the demo script shows permission boundaries. E.g., "Using `TOKEN_B` (viewer), attempt to delete — expect HTTP 403."

4. **Order matches the demo script.** Steps follow the same sequence as segments so the verification mirrors the demo narrative.

5. **Cleanup is mandatory.** Always end with deletion of all test-created resources. Note cascade behavior where applicable.

6. **Placeholder variables** use double-brace syntax `{{base_url}}` for values the user must fill in. Shell variables use `$VAR` syntax for values captured during the run.

7. **Shell mode: assert exit codes + RotationStats fields with `jq -e`; fail step if mismatch.** Every verification step must be fail-fast (`set -euo pipefail`) and assert both the process exit code and the structured output. Use `jq -e '.rotated == 1 and .old_key == 0'` (or the feature's equivalent predicate) so a wrong count fails the shell.

8. **Rehearsal gate: run all steps before recording.** Do not mark the meta-prompt done until every command has been executed end-to-end in a clean environment and the Checklist is fully ticked.
