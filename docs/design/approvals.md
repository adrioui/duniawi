# Approvals record

Status: **A1–A3 recorded; A4–A5 pending; live cutover is not authorized**

The migration is gated on five explicit approvals. A design review is also
required before Gate 2 implementation. Silence, a green build, or a previous
conversation does not grant an approval. A3b is recorded below and is
resolved by excluding the 16 runtime files under `.dlt`/`surrealdb-data`.

## Design review

| Item | Status | Evidence |
|---|---|---|
| Domain model | Draft complete | `docs/design/domain.md` |
| Resolution/migration graph | Draft complete | `docs/design/graph.md` |
| Compatibility matrix | Draft complete | `docs/design/compatibility.md` |
| Package portability | Draft complete | `docs/design/packages.md` |
| Service disposition | Draft complete | `docs/design/services.md` |
| Secrets/threat model/rotation | Draft complete | `docs/design/secrets.md` |
| Exclusion policy | Draft complete | `docs/design/exclusions.md` |
| Migration runbook | Draft complete | `docs/design/migration.md` |
| Rollback procedure | Draft complete | `docs/design/rollback.md` |
| Test plan / CI matrix | Draft complete | `docs/design/test-plan.md` |
| ADRs | Draft complete | `docs/design/adr/` |
| Gate 0 baseline | Draft complete | `docs/design/baseline.md` |

Design review decision: **A1–A3 recorded; A4–A5 pending. A new A3b ownership
decision is needed before the live stage.**

## Approval 1 — wrapper hash mismatch

| Field | Value |
|---|---|
| ID | A1 |
| Subject | Accept the `BUNDLE.sha256.sha256` wrapper hash mismatch |
| Recorded hash | `654c567d6dcd8ac6a9a982933661a4c3d0744fb1f4ffe2c6989606f8f4129b9b` |
| Actual hash | `8bafbeb0d1ae3413afaf92d36ee2a4895f86c7c12307b408d2fb027b9b54bbb4` |
| Scope | The wrapper file only; the 40 other bundle entries verify `OK` |
| Self-reference | `BUNDLE.sha256` contains an empty-file line for itself (`e3b0c442…`), excluded from the check |
| Risk if accepted | The wrapper hash is not self-consistent, but the listed evidence files are intact |
| Risk if rejected | The bundle must be regenerated or re-signed before migration |
| Required evidence | `sha256sum -c` filtered bundle log; explanation of the wrapper mismatch |
| Decision | **Accepted 2026-10-31 against the regenerated chain** |
| Approver / date | User, 2026-10-31 |
| Blocking | Cleared for Gate 4; other gates remain |

The original mismatch was not waived. Best practice was to restore the hash
chain, and the user accepted the regenerated evidence. The chain is in
`docs/design/evidence/gate4/bundle-regenerated/`:

- `BUNDLE.sha256` has 40 entries; SHA-256
  `bed412d87a1eec556c81e9b6f7e31084edfe636dbe6d5eb4828ae68f8c8188a1`;
- `BUNDLE.sha256.sha256` is detached; wrapper file SHA-256
  `8e7646bf10b9bc98da3163e204ec5239fed6c0237f7d6f37d79035f011855224`;
- `sha256sum -c` reports 40/40 OK; the wrapper check is OK.

The read-only backup was not modified. The remediation procedure used was:

1. Create a new evidence directory outside the read-only backup.
2. Copy the verified 40 entries and regenerate `BUNDLE.sha256` from their
   actual hashes.
3. Regenerate `BUNDLE.sha256.sha256` from the new `BUNDLE.sha256`, so the
   wrapper hash is self-consistent.
4. Record both old and new hashes, the reason for regeneration, and the
   filtered `sha256sum -c` output.
5. Re-request A1 with the new evidence. Do not edit the backup.

Acceptance wording: “I accept the regenerated wrapper hash chain and authorize
migration to proceed with the recorded evidence.”

## Approval 2 — UID/GID mapping

| Field | Value |
|---|---|
| ID | A2 |
| Subject | Map old `1000:1000` ownership to new `adrioui:adrioui` |
| Proposed mapping | user `adrioui` uid 1000; group `adrioui` gid 1000; primary group `adrioui` |
| Old identity | user `adrifadilah`, uid 1000, gid 1000 |
| Current target | `adrioui` uid 1000, gid 100 (`users`); gid 1000 unmapped |
| Method | create group gid 1000; no recursive `chown`; restore with `--numeric-ids`; selectively map root-owned `.herdr`/`Works/Bangunindo/BLIV` files |
| Required evidence | `getent passwd adrioui`, `getent group adrioui`, `stat` on restored home, `find -nouser -o -nogroup` empty, `find -uid 0` empty in included paths |
| Risk | wrong mapping makes the restored home unreadable or misowned |
| Decision | **Confirmed 2026-10-31** |
| Approver / date | User, 2026-10-31 |
| Blocking | Gate 4 stage verification, Gate 5 cutover |

Approval wording: “I approve uid 1000 / gid 1000 for `adrioui`, with group
`adrioui` at gid 1000, no recursive chown, and selective mapping of root-owned
files only under `.herdr` and `Works`.”

## Approval 3 — exclusion policy

| Field | Value |
|---|---|
| ID | A3 |
| Subject | Approve what is not restored from the backup |
| Mandatory exclusions | secrets, keys, keyrings, old proxy config/units, shell history, logs, broken home-manager links |
| Regenerable exclusions | caches, package stores, container storage, build outputs, trash |
| Restore include list | `Works/Bangunindo/BLIV`, `.herdr/worktrees/btj--bliv*`, `Personal/` (user data only), `Learns/` (source/data; generated runtime excluded), Agent transcripts from Codex/Claude/Pi/Cursor/Cline |
| Root-owned policy | map `.herdr`/`Works/Bangunindo/BLIV` to `adrioui`; exclude other root-owned files; no recursive chown |
| Deferred review | `.dlt/` and `surrealdb-data/` in `Learns/`; re-open A3b if that runtime state is needed |
| Path rewrite | `/var/home/adrifadilah` and `/home/adrifadilah` → `/home/adrioui` in text files only |
| Required evidence | approved exclude file; dry-run log; secret scan; no dangling links; root-owned lists reviewed |
| Risk | excluding needed data, or including a secret |
| Decision | **Confirmed 2026-10-31 (final scope)**: BLIV code/worktrees + Agent transcripts + Personal + Learns; exclude Tooling, Fun, Games, Downloads, distrobox, ClickHouse, `.clawdbot`, and other top-level data |
| Approver / date | User, 2026-10-31 |
| Blocking | Gate 4 stage copy |

Approval wording: “I approve the final scope: BLIV code/worktrees, Agent
conversation history, Personal, and Learns, with the
`.herdr`/`Works/Bangunindo/BLIV` root-owned mapping.”

## Approval A3b — non-1000 ownership

| Field | Value |
|---|---|
| Subject | Decide what happens to the remaining 16 non-1000 runtime entries in `Learns/` |
| Finding | 109 non-1000 entries remain in Learns: 93 are valid `1000:0`; 16 are `999:999`/`65532:65532` under `.dlt` and `surrealdb-data` |
| Paths | `Learns/.../.dlt/`, `Learns/vibing/musiqasik/surrealdb-data/`; distrobox and non-BLIV Works excluded |
| Default | exclude the 16 runtime entries as regenerable; keep the 93 valid `1000:0` source/data paths |
| Required evidence | path list, old ID, proposed ID or exclusion, service impact |
| Risk | excluding real runtime data, or mapping a database ID and breaking it |
| Decision | **Resolved by exclusion 2026-10-31**: `.dlt` and `surrealdb-data` are runtime state, not source; excluded |
| Blocking | Cleared; re-open if that runtime state is needed |

Approval wording: “I approve excluding `.dlt` and `surrealdb-data` runtime
state while keeping the rest of Learns.”

## Approval 4 — cutover and rollback window

| Field | Value |
|---|---|
| ID | A4 |
| Subject | Approve the cutover/rollback maintenance window |
| Proposed window | date/time to be chosen by the user; root TTY/live USB required |
| Cutover actions | stop user session/OpenCode; consistent DB backup; rename homes; activate; reboot; login proof |
| Rollback actions | boot previous generation or rename homes back; verify login; retain both homes |
| Retention | old home until acceptance; N-1/N-2 generations; no GC during window |
| Required evidence | approved window; rollback rehearsal; Gate 3 VM proof; secret rotation complete |
| Risk | failed cutover or failed rollback; data loss if old home is removed |
| Decision | **Pending — no window approved.** A chat-disclosed credential is not a scheduling decision and was not used. The 2026-10-31 “Continue” answer is not an A4 approval. |
| Approver / date | — |
| Blocking | Gate 5 cutover |

Approval wording: “I approve the cutover/rollback window on `<date/time>` and
confirm the rollback procedure in `docs/design/rollback.md`.”

## Approval 5 — live `nixos-rebuild switch`

| Field | Value |
|---|---|
| ID | A5 |
| Subject | Authorize the live switch on `t14` |
| Command | `nixos-rebuild switch --flake <repo>#t14` |
| Preconditions | A1–A4 recorded; Gate 3 VM proof; Gate 4 stage verification; secrets rotated; rollback ready |
| Scope | one activation, one reboot, login proof; no manual patching |
| Required evidence | pre-switch generation list; switch log; reboot/login proof; rollback rehearsal |
| Risk | unbootable host or broken login; mitigated by previous generation and old home |
| Decision | **Pending — not authorized.** No live switch will be run. The 2026-10-31 “Continue” answer is not an A5 approval. |
| Approver / date | — |
| Blocking | Gate 5 live switch |

Approval wording: “I authorize the live `nixos-rebuild switch` on `t14` now,
with the recorded rollback path.”

## Blocking findings

| Finding | Severity | Owner action | Status |
|---|---|---|---|
| Sudo credential pasted into chat on 2026-10-31 (value not recorded here) | **SecretLeak** | change it from a local console now; do not reuse; no sudo was run with it | Open |
| Inline GPG passphrase in `gpg-preset-passphrase.service` | **SecretLeak** | rotate GPG passphrase/key; never restore | Open |
| Exposed SOPS age key at `.config/sops/age/keys.txt` | **SecretLeak** | do not reuse; generate per-host key | Open |
| 192,782 root-owned entries; 170,171 root-owned files; only `.herdr`/`Works/Bangunindo/BLIV` required | High | root TTY hash verification; map only `.herdr`/`Works/Bangunindo/BLIV`; exclude others | Partially decided |
| 16 non-1000 runtime entries in `Learns/.dlt` and `surrealdb-data` | Medium | A3b: excluded as runtime state; re-open if needed | Resolved |
| Wrapper hash mismatch | Medium | Regenerated chain | Accepted (A1) |
| gid 1000 mapping | High | Approval 2 | Confirmed |
| Exclusion policy | High | Approval 3 | Confirmed, with A3b open |
| Cutover/rollback window not approved | High | Approval 4 | Pending |
| Live switch not approved | High | Approval 5 | Pending |
| Root hash verification | High | root TTY | NotRun |
| Rollback rehearsal | High | boot previous generation + old home | NotRun |
| Secret rotation/provisioning | High | rotate old secrets; new age key and sops file | Open |
| Darwin build not run on macOS | Medium | CI/macOS runner | NotRun |
| Old proxy stack contains secrets | High | archive; rotate; no copy | Open |
| `sprint69-deck` payload and `dsh` binary missing | Medium | archive; do not start | Open |

## Interim operator decisions (2026-10-31)

These are explicit choices recorded during Gate 0/1. They are not a substitute
for A1–A5.

| Decision | Choice | Scope |
|---|---|---|
| Browser | Helium on NixOS, from the pinned `helium` input; no Firefox by default | `nixosUser` / `browser` |
| Root-owned data | map `.herdr` and `Works` to `1000:1000`; exclude other root-owned files | A2/A3 addendum |
| Personal data | exclude `Personal/` under the revised minimal scope | A3 revision 2026-10-31 |
| Clawdbot data | exclude `.clawdbot/` entirely; agent credentials/runtime are not needed | A3, user 2026-10-31 |
| NixOS release | pin `t14` to the running 26.05 revision; Darwin stays on unstable | ADR-0008 |
| Proxy scope | implement repo-owned `amp-deepseek`; archive old Fedora stack | ADR-0005 |
| VPN | Tailscale only by default; NetBird is opt-in | `vpn.nixos` |

## Security incident — chat-disclosed sudo credential

On 2026-10-31 a sudo credential was pasted into the chat while answering the
A4/A5 question. The value is intentionally not reproduced here.

Actions taken:

- the credential was **not used** for any command;
- `sudo -k` was run to clear any cached sudo timestamp;
- `sudo -n true` still fails with “a password is required”;
- the repository was scanned for the value; no match was found;
- no live switch, stage copy, or privileged action was performed.

Required user action: change the account password from a local console now.
Do not paste it into chat, shell history, a command line, a log, or a report.
If it was reused elsewhere, rotate those credentials too.

## Approval mechanics

- Approvals are recorded by explicit user message naming the approval ID and
  the decision.
- An approval is scoped to the stated evidence and window; it is not a blanket
  approval for later changes.
- Any change to the approved mapping, exclusion list, secret backend, proxy
  scope, or cutover window requires a new approval.
- The approver must not paste a password, passphrase, token, or key into chat.
- The migration stops if an approval is missing, stale, or contradicted by new
  evidence.
