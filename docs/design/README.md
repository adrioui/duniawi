# Cross-platform Den design

Status: **Gate 2 implemented; Gate 3 VM proof and failure injection passed;
the live migration is blocked by root verification, A3b, A4/A5, and secrets**

This directory designs the second host in `adrioui/duniawi` and the migration
of the old Fedora home from the read-only `backup` HDD. It is intentionally
evidence-first: every status names a command, artifact, or approval.

## Reading order

1. `baseline.md` — Gate 0 facts and hashes.
2. `research.md` — primary-source research and adopt/defer/reject decisions.
3. `domain.md` — nouns, IDs, variants, errors, invariants.
4. `graph.md` — Den resolution and migration graphs.
5. `compatibility.md` — aspect/host matrix and Darwin non-regression.
6. `packages.md` — package portability.
7. `services.md` — service disposition.
8. `secrets.md` — inventory, threat model, rotation.
9. `exclusions.md` — what is not restored (Approval 3/A3b).
10. `migration.md` — stage/verify/cutover runbook.
11. `rollback.md` — rollback procedure.
12. `test-plan.md` — two-system CI and VM/migration tests.
13. `safety-case.md` — cutover invariants, blast radius, go/no-go.
14. `adr/` — decisions.
15. `approvals.md` — A1–A5, A3b, and blockers.

## Decisions at a glance

| Decision | Choice | ADR |
|---|---|---|
| Repository topology | one flake, two hosts | 0001 |
| Composition | Den aspects/classes; shared user aspect plus NixOS host aspect | 0002 |
| Ownership | uid 1000, gid 1000, group `adrioui`; selective `.herdr`/`Works/Bangunindo/BLIV` mapping | 0003 |
| Secrets | sops-nix + per-host age | 0004 |
| Services | archive old proxy stack; implement repo-owned amp-deepseek natively; no tunnel | 0005 |
| Migration | stage at `/home/adrioui.restore`, verify, cut over, roll back | 0006 |
| CI | Linux + macOS arm64 matrix | 0007 |
| NixOS release | pin `t14` to the running 26.05 revision; Darwin stays on unstable | 0008 |
| Old paths | declarative compatibility link; restore is byte-identical, never rewritten | 0009 |

## Current gate status

| Gate | Status | Notes |
|---|---|---|
| 0 Freeze/baseline | Captured with exceptions | root hash verification blocked; Darwin build not run on macOS |
| 1 Design review | Researched; A1–A3 recorded; A3b open | primary-source dossier and ADRs |
| 2 Implementation | **Implemented and evaluated** | NixOS toplevel builds; static checks pass; Darwin evaluates |
| 3 VM proof | **Pass (rollback NotRun)** | boot/login/HM/proxy/auth/missing-secret/reboot, kill-restart, power-cycle, full-disk, corrupt-SQLite |
| 4 Migration integration | Fixture pass; real stage blocked | root access, A3b, secret rotation |
| 5 Cutover | Blocked | A4–A5, rollback rehearsal, stage proof |
| 6 Release/handoff | Not started | PR, evidence, retention |

## Hard blockers

- No sudo/root access in this session; `sudo -n true` fails.
- 192,782 root-owned entries; 170,171 root-owned files. Only `.herdr`,
  `Works/Bangunindo/BLIV`, and user-owned `Personal`/`Learns` data are in
  scope; generated dependency and runtime state is excluded.
- Final scope from 2026-10-31: BLIV code/worktrees, Agent transcripts,
  `Personal`, and `Learns`. `Tooling`, `Fun`, `Games`, `Downloads`, distrobox,
  ClickHouse, `.clawdbot`, and other top-level data are excluded.
- A3b is reduced to 16 runtime entries under `Learns/.dlt` and
  `Learns/surrealdb-data`; they are excluded as regenerable. Re-open if needed.
- Approval 1 (wrapper hash mismatch) is **accepted against the regenerated
  chain**; the corrected 40-entry bundle and detached wrapper are in
  `docs/design/evidence/gate4/bundle-regenerated/`.
- Approval 2 (UID/GID mapping) is confirmed.
- Approval 3 (exclusion policy) is confirmed for the final scope.
- Approval 4 (cutover/rollback window) is pending; no window was approved.
- Approval 5 (live switch) is pending; no live switch is authorized.
- In-scope content hash passed (4,826,215 files, zero mismatches); root-only excluded-state verification is NotRun. The stage has not started.
- Rollback rehearsal is NotRun; boot the previous generation with the old home.
- A sudo credential was pasted into chat on 2026-10-31. It was not used;
  `sudo -k` was run and `sudo -n true` still fails. Change the password from a
  local console and treat it as compromised.
- Secret rotation is not done: the old GPG passphrase and age key are
  compromised.
- The old proxy stack is archived; only `amp-deepseek` is implemented on
  NixOS, with new sops secrets.
- Darwin has not been built on macOS in this session; CI must prove it.

## What is intentionally not done

- No `nixos-rebuild switch` on the live machine.
- No writes to `/home/adrioui` during staging.
- No writes to the backup HDD.
- No copy of old proxy code/config/secrets from the external HDD.
- No reuse of the old age key, SSH key, GPG key, or provider credentials.
- No commit to `main`.
- No unpinned input, channel, or `--impure`.

## Next step

Decide A3b, then arrange a root TTY for fresh hash verification. Rotate the
exposed credentials, provision the new age key and sops file, and rehearse
rollback. The real stage cannot start before those are cleared. macOS CI build
and soak remain open release gates. See `evidence/LEDGER.md`.
