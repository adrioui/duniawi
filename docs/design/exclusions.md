# Exclusion policy (Approval 3)

Status: **A3 confirmed for the final scope: BLIV code/worktrees, Agent
transcripts, Personal, and Learns. No live copy has started.**

This policy controls what is **not** copied from the read-only backup into
`/home/adrioui.restore`. It never modifies the backup. Exclusions are applied
with a reviewed rsync filter file; every skipped path is reconciled against
an independent policy check (ADR-0009).

The default is **exclude** for secrets, credentials, old service state,
regenerable caches, and anything whose content cannot be verified. User
documents are restored only from the include list in section 5.

## 1. Mandatory security exclusions

These paths are excluded because they contain, or may contain, credentials.
They are rotated or recreated on NixOS; they are never restored from the old
home.

| Pattern | Reason | Replacement |
|---|---|---|
| `.ssh/` | private keys, known hosts, agent sockets | new SSH key |
| `.gnupg/` | private keys, passphrase state, agent sockets | new GPG key |
| `.config/sops/` | old age private key | new per-host age key |
| `.env` (exact basename) | project credentials; 45 in-scope files measured on this backup | recreate via sops or the provider |
| `.aws/` | AWS credentials | re-authenticate / new key |
| `.config/gh/` | GitHub OAuth token | `gh auth login` |
| `.docker/` | registry auth, token seed | re-authenticate |
| `.kube/` | cluster credentials | new kubeconfig |
| `.local/share/keyrings/` | desktop keyring | new keyring |
| `.clawdbot/` | agent credentials, WhatsApp/Telegram sessions, runtime state, root-owned files | excluded entirely; user decision 2026-10-31 |
| `.config/nix-managed/` | infrastructure secrets | new sops secrets |
| `.config/litellm/` | LiteLLM config, provider keys, tunnel token | archived; not ported |
| `.config/cline-shim/` | provider env files and account state | archived; not ported |
| `.config/claude-litellm/` | provider keys, logs | archived; not ported |
| `.config/qodercli2api/` | provider env | archived; not ported |
| `.config/collie/` | bridge token/env | archived; not ported |
| `.config/commandcode-proxy/` | proxy log and config | archived; not ported |
| `.config/opencode/commandcode.key` | provider key | revoke; new key only if needed |
| `.config/amp/` | settings and backups that may contain provider keys | review; restore only non-secret settings |
| `.config/systemd/user/` | old units and dangling symlinks | NixOS/home-manager units |
| `.bash_history`, `.zsh_history`, `.python_history`, `.node_repl_history` | may contain secrets | do not restore |
| `.local/share/Trash/` | deleted data, unpredictable secrets | do not restore |
| `**/*.log` under `.config/`, `.local/share/`, `.cache/` | logs may contain headers/tokens | archive only; no restore |
| `**/.env`, `**/env` under `.config/` | provider secrets | exclude; recreate via sops |
| Secrets by **exact path or exact basename, never by prefix**: `.ssh/`, `.gnupg/`, `.aws/credentials`, `.netrc`, `.git-credentials`, `.config/gh/hosts.yml`, `.config/sops/age/keys.txt`, `.docker/config.json`, `.kube/config`, `id_rsa`, `id_ed25519`, `id_ecdsa`, `*.kdbx`, `.env` (exact basename; `example.env` is not matched), `Works/Bangunindo/BLIV/license_key.txt`, `**/.aws/credentials` | keys/certs | exclude; recreate via sops or the provider |

Name-only prefix globs are forbidden. Measured on this backup, the previous
rule `**/credentials*` removed 563 in-scope files whose basename merely starts
with `credentials`: 302 `.py` modules (`botocore/credentials.py`,
`google/auth/oauth2/credentials.py`, `google/auth/compute_engine/credentials.py`,
`redis/credentials.py`), 144 `.pyc`, 16 `.ts`, 10 `.js`. The sibling rules were
no better: 106 of 446 `*.pem` matches are `cacert.pem` public CA bundles, and
152 of 351 `*.env` matches are `example.env` templates. A rule that removes
library code is a copy defect, not an exclusion. Every rule needs a ledger row
with its matched count and a `code removed?` flag, and the stage must be
reconciled against the source inventory (ADR-0009).

`gpg-preset-passphrase.service` is a special case: it contains an inline
passphrase and is excluded even though it lives under the systemd unit path.
It is never restored.

## 2. Old proxy and service state

The old Fedora AI proxy stack is archived, not migrated. Exclude its code,
config, state, and logs:

| Pattern | Reason |
|---|---|
| `Tooling/commandcode-proxy/` | old proxy code; not copied |
| `Tooling/CLIProxyAPI-latest-magnitude/` | old proxy code/config |
| `Tooling/qodercli2api/` | old proxy code/config |
| `Tooling/freebuff-2api/` | old proxy build output/config |
| `Tooling/zcode-api/` | old proxy code |
| `Tooling/amp-cache-parity/` | old drift check |
| `.config/freebuff-2api/` | old proxy config |
| `.config/routatic-proxy/` | old proxy config |
| `.config/opencode2api/` | old proxy config |
| `.config/.opencode2api/` | old proxy state |
| `.opencode2api/`, `.opencode2dsh/` | old proxy state |
| `.dsh/`, `.dsh-tui/`, `.dsh-cc/`, `.dsh-doctor/` | old harness state; `dsh` binary is missing |
| `.config/herdr/` sockets and caches | runtime state, not data |
| `.config/collie/` | bridge credentials |

Project source trees under `Works/Bangunindo/BLIV/` and `Learns/` are
**not** automatically excluded. They are restored as data, but any secret file
inside them is excluded by the patterns above and must be recreated.

## 3. Regenerable and cache exclusions

These are large and can be recreated. Excluding them saves space and reduces
the secret surface. Approval 3 may remove any row, but the default is exclude.

| Pattern | Approx. size | Reason |
|---|---|---|
| `.cache/` | ~15 GiB | regenerable |
| `.bun/` | ~5.4 GiB | package cache |
| `.npm/` | part of `.local`/home | package cache |
| `.rustup/` | ~3.9 GiB | toolchain cache |
| `.cargo/registry/`, `.cargo/git/` | part of home | package cache; keep `credentials.toml` excluded |
| `go/pkg/mod/` | part of `go/` | module cache |
| `**/node_modules/` | project-dependent | reinstall |
| `**/.venv/`, `**/venv/` | project-dependent | recreate |
| `**/target/`, `**/dist/`, `**/build/`, `**/.next/`, `**/.turbo/` | project-dependent | rebuild |
| `clickhouse-local/` | tool/database state | **excluded by user decision 2026-10-31** |
| `Fun/bike/docs/runs/` | generated agent run logs; four files unreadable without root | exclude; not user source |
| `.local/share/containers/` | part of `.local` (~41 GiB) | container storage; recreate images |
| `.local/share/flatpak/` | part of `.local` | Flatpak runtime; reinstall |
| `.var/app/*/cache/`, `.var/app/*/tmp/` | part of `.var` (~14 GiB) | app caches |
| `.local/share/Trash/` | part of `.local` | deleted data |
| `.local/share/opencode/opencode.db*` | live DB | **never copy from backup**; use live DB and a consistent SQLite backup |
| `.local/share/opencode/log/` | logs | may contain prompts/secrets |
| `.local/state/` logs and caches | part of `.local` | runtime state |

### 3.1 Works scope

The user narrowed `Works/` to the BLIV work only on 2026-10-31:

| Path | Decision |
|---|---|
| `Works/Bangunindo/BLIV/` | include; root-owned files map to `1000:1000` |
| `Works/Bangunindo/` other projects | exclude |
| `Works/Learns/` | exclude |
| `Works/adrifadilah-ai-agents/` | exclude |

This removes the `Works/Learns/.../airflow` non-1000 entries from the stage.
`.herdr/worktrees/btj--bliv*` remains in scope; all six current worktrees are
BLIV.

## 4. Broken or unverifiable paths

| Path | Reason | Action |
|---|---|---|
| `bliv-secrets.service` | dangling home-manager symlink | exclude |
| `nix-gc.service`, `nix-gc.timer` | dangling home-manager symlinks | exclude; replace with `nix.gc.automatic` |
| `nix-managed-probe.service` | dangling home-manager symlink | exclude |
| `tray.target` | dangling home-manager symlink | exclude |
| `sprint69-deck.service` and payload | payload absent from manifest | exclude service; archive |
| `.local/bin/dsh` | absent from manifest | exclude unit; archive |
| 192,782 root-owned entries; 170,171 root-owned files, 22,413 root-owned directories | fresh unprivileged inventory; earlier 9,224 figure was incomplete | root hash verification still required; selective policy below |
| 121,464 of the root-owned entries are under `Personal/financial/actual` | `node_modules`, `.yarn/cache`, and build output owned by container/build users | regenerable; exclude those generated subtrees |
| 32,326 root-owned files under `.herdr` + `Works/Bangunindo/BLIV` (about 1.93 GiB) | user-required content | hash first, then selectively map to `1000:1000` |
| 920 root-owned files under `.clawdbot` | agent credentials/runtime; user does not need it | exclude the whole tree |
| any path with an unmapped UID/GID outside the approved mapping | ownership cannot be preserved | **blocked** until the user approves exclusion or mapping |

Fresh root-owned regular-file counts by top level (unprivileged `find`):

| Top level | Root-owned files |
|---|---:|
| `Personal/` | 103,708 |
| `.pi/` | 32,908 |
| `.herdr/` | 27,453 |
| `Works/` (BLIV only in scope) | 4,873 |
| `.clawdbot/` | 920 |
| `.adalflow/` | 250 |
| `clawd/` | 25 |
| `Learns/` | 15 |
| `.local/` | 9 |
| `wt/` | 7 |
| `.claude/` | 1 |
| **Total** | **170,171** |

Most of `Personal/` is generated dependency/build state, not the financial
data the user asked to keep. It is excluded by the `**/node_modules/`,
`.yarn/cache`, and build-output rules below.

### 4.1 Root-owned ownership policy

The user explicitly narrowed the required root-owned content to `.herdr/` and
`Works/Bangunindo/BLIV/`. The policy is:

1. Root-owned regular files under `.herdr/` and `Works/Bangunindo/BLIV/` are included and
   mapped to `adrioui:adrioui` (`1000:1000`) **after** hash and metadata
   verification.
2. Root-owned regular files elsewhere in the included tree are **excluded**
   from the stage. They are not needed.
3. Root-owned directories needed to traverse `.herdr/` or `Works/Bangunindo/BLIV/` are mapped
   to `1000:1000`; no recursive `chown` of the whole home is performed.
4. Root-owned credential files (for example `.clawdbot/credentials/*`,
   `.local/state/accounts-backup/*/shadow`) are excluded regardless of tree.
5. Every selective `chown` is recorded with a path list and verified with
   `find . -uid 0` on the stage. A remaining root-owned file in an included
   path is a stop condition.

This is a controlled exception to the earlier "no recursive chown" rule. It
was approved by the user on 2026-10-31; it is not a blanket permission to
change ownership elsewhere.

### 4.2 Non-1000 ownership in user data

Fresh metadata found 112 non-1000 entries after excluding generated trees.
The 3 distrobox entries are excluded. Of the 109 in `Learns/`, 93 are
`1000:0` (a valid user with group root) and 16 are `999:999`/`65532:65532`
under `.dlt` and `surrealdb-data`. Those two subtrees are runtime database
state, not source, and are excluded as regenerable. If that state is needed,
A3b reopens with an explicit ID-mapping decision.

Policy: **exclude any path whose UID/GID is not `1000:1000` (or a valid
`1000:0` path) or an approved root-owned `.herdr` or
`Works/Bangunindo/BLIV` path.** Do not map an unapproved ID to `1000:1000`
silently. If a future include adds such data, record the path, current ID,
intended ID, and service impact as a new approval.

The fixture covers the approved `1000:1000`, root-owned
`.herdr`/`Works/Bangunindo/BLIV`, and excluded-tree cases only.

## 5. Restore include list

The user reduced the scope again on 2026-10-31:

> “I'm not using distrobox as well. What I care about is the code from work,
> history from my conversations with Agent. That's it. Everything else is not
> needed.”

The authoritative scope from 2026-10-31 is:

| Area | Approx. size | Notes |
|---|---|---|
| `Works/Bangunindo/BLIV/` | ~24.9 GiB | BLIV code; root-owned files map to `1000:1000` |
| `.herdr/worktrees/btj--bliv*` | part of ~33 GiB | all six current worktrees are BLIV |
| `Personal/` | ~2.3 GiB | user data; exclude `node_modules`, `.yarn/cache`, generated build output, and root-owned generated files |
| `Learns/` | ~11 GiB | source and data; exclude `airflow/logs`, `.dlt/`, and `surrealdb-data/` runtime state |
| Agent conversation transcripts | ~9 GiB | transcript/session files only, from the paths below |

Everything else is excluded, including `Tooling/`, `Fun/`, `Games/`,
`Downloads/`, `.config/` as a whole, `.local/share/` as a whole, `.var/`,
distrobox, ClickHouse, `.clawdbot`, and all non-BLIV `Works`.

Agent history is transcript-only. Do not copy an entire agent directory: they
contain auth files, caches, binaries, sockets, and plugin state.

| Path | Contents |
|---|---|
| `sessions/` | Codex rollout transcripts |
| `.codex/sessions/`, `.codex/history.jsonl`, `.codex/session_index.jsonl` | Codex sessions/history |
| `.claude/projects/`, `.claude/history.jsonl` | Claude transcripts/history |
| `.pi/agent/sessions/`, `.pi/agent/runtime-events/` | Pi sessions/events |
| `.cursor/chats/` | Cursor chat databases |
| `.cline/tasks/`, `.cline/data/sessions/` | Cline task/session data, if present |

Anything not in this list is excluded by default.

## 6. Path resolution policy

The copy is not rewritten. Every restored byte stays identical to the backup,
so the stage can be re-verified against the read-only source at any moment
(ADR-0009).

Old absolute paths — `/var/home/adrifadilah` in git worktree pointers, agent
transcripts, application databases and package manifests — are made to resolve
by one declarative link in `den.aspects.homeMigration`
(`modules/home-migration.nix`):

```nix
systemd.tmpfiles.rules = [
  "d /var/home 0755 root root -"
  "L /var/home/adrifadilah - - - - /home/adrioui"
];
```

A symlink is resolved per lookup, so it follows the home across the cutover
rename. A bind mount does not: it pins the inode, and would still point at the
pre-migration tree after the swap.

Rules:

| Rule | Reason |
|---|---|
| Never edit restored files | `sed -i` replaces the inode; hardlinks break and ACLs, xattrs and file capabilities are dropped (measured) |
| Never map ownership after the copy | `chown`/`chgrp` clear setuid and `security.capability`; ownership is already correct via ADR-0003 |
| Repair live configuration, not archives | shell rc files, `~/.config/herdr/session.json` are rewritten by hand or by Home Manager; transcripts and databases are history |
| Defer `git worktree repair` | the link makes the existing pointers resolve; repair and link removal are one phase-2 change |
| Gate link removal | Approval 6, on a ledger of remaining references per directory |

Known limitation: `find /var/home/adrifadilah` without a trailing slash returns
the link itself rather than the tree. Documented and accepted for the migration
window.

## 7. Verification

| Check | Pass condition |
|---|---|
| Exclusion manifest reviewed | every pattern has a reason and owner |
| Exclusions explained | every file present in the source but absent from the stage matches a documented rule (`verify-home.sh`: `unexplained-exclusions 0`) |
| Content drift | `rsync -n -c` with the same filter reports no differences (`drift-lines 0`) |
| Dry run | `rsync --dry-run --itemize-changes` shows only approved paths |
| No secret path copied | `find` on stage for excluded patterns returns nothing |
| Database WAL | every staged `-wal` sibling is present and sampled `integrity_check` is `ok` |
| Worktree pointers | every `.git` pointer resolves to a staged path after the move |
| No dangling symlink | `find -xtype l` on stage returns nothing |
| Root-owned mapping list | every `.herdr` or `Works/Bangunindo/BLIV` root-owned path is listed and mapped |
| No unexpected root-owned file | `find . -uid 0` under included paths is empty after mapping |
| No unmapped ownership | `find -nouser -o -nogroup` returns nothing in the included tree; container/generated trees are excluded |
| Non-1000 policy | every remaining unmapped ID is either excluded or separately approved |
| Size/inodes | stage fits in 415 GiB / 29.47M free inodes (fresh `df`) |
| Backup unchanged | `findmnt` still `ro,nosuid,nodev,relatime`; no writes |

## 8. Approval request

Approval 3 asks the operator to approve:

1. The mandatory security exclusions in section 1.
2. The old proxy/service exclusions in section 2.
3. The regenerable exclusions in section 3.
4. The restore include list in section 5: BLIV code/worktrees, Agent
   transcripts, `Personal/`, and `Learns/`.
5. The root-owned policy in section 4.1: map `.herdr` and `Works/Bangunindo/BLIV`, exclude other
   root-owned files, and perform only selective `chown`.
6. The path resolution policy in section 6: a declarative compatibility link,
   and no rewriting of restored data.

No restore copy may start until this approval is recorded in
`docs/design/approvals.md`.
