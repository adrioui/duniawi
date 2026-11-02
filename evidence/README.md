# Evidence

Canonical artifacts for the migration safety case:

- `LEDGER.md` — claim, command, exit code, artifact, timestamp, oracle, status.
- `raw/` — read-only Phase 0 outputs and the final VM transcript.
- `migration/` — fixture, ownership inventory, non-1000 list, backup hash log.
- `rollback/` — rehearsal status and failed automation notes.
- `security/` — incident and rotation checklist, no secret values.
- `device/` — sanitized device-gate summaries. Raw `verify.tsv`, `context.json`,
  `manifest.sha256` and the operator transcripts stay under
  `/var/lib/duniawi/evidence/<stamp>` and are not committed when they contain
  serials, LAN addresses, SSIDs, or host paths. A committed summary names the
  claim, command, exit, a sanitized excerpt, and the gate result; the raw
  transcript is referenced by its absolute path only.

No production credential belongs in this directory. Test-only key names may
appear in the VM transcript; they are not usable secrets. A device transcript
marked `Attested` means the boot-ID/journal or ISO-hash binding passed, not
that a human physically pressed the menu key.
