# Evidence

Canonical artifacts for the migration safety case:

- `LEDGER.md` — claim, command, exit code, artifact, timestamp, oracle, status.
- `raw/` — read-only Phase 0 outputs and the final VM transcript.
- `migration/` — fixture, ownership inventory, non-1000 list, backup hash log.
- `rollback/` — rehearsal status and failed automation notes.
- `security/` — incident and rotation checklist, no secret values.

No production credential belongs in this directory. Test-only key names may
appear in the VM transcript; they are not usable secrets.
