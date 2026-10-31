# Backup content hash summary

Date: 2026-10-31 (Asia/Jakarta)
Source: `/run/media/adrioui/backup/home`, read-only.
Command: `sha256sum --quiet -c /run/media/adrioui/backup/evidence-20261030/gate3/source.sha256`
Result: exit 1; **no checksum mismatches**, 4,826,215 files read.
The manifest has 5,082,466 entries; 256,251 files could not be read as the
current user.

All 256,251 unreadable files are outside the final migration scope:

| Group | Files | Disposition |
|---|---:|---|
| `.local/share/containers/` | 247,017 | excluded |
| `clickhouse-local/` | 9,207 | excluded |
| `.clawdbot/` | 17 | excluded |
| `Fun/bike/docs/runs/` | 4 | excluded |
| `.local/state/accounts-backup*` | 4 | excluded (credentials) |
| `.local/share/distrobox/` | 1 | excluded |
| `Works/Learns/.../airflow` | 1 | excluded (non-BLIV Works) |
| **Total** | **256,251** | all excluded |

Required trees under `.herdr/` and `Works/Bangunindo/BLIV/` had **zero**
unreadable or mismatched files. `Personal/` and `Learns/` had no hash failures
outside the excluded generated/runtime subtrees.

This proves content integrity for all readable in-scope data. It is not a
root-level proof of the excluded container/agent state, which the user does
not need. A root TTY is still required before any live stage to prove the
complete home and to map root-owned files.

Full raw log: `/tmp/duniawi-source-hash-verification.log` (not committed; it
contains 512k path-only lines). The durable summary is this file.
