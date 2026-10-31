# Ownership inventory and policy evidence

Date: 2026-10-31 (Asia/Jakarta)
Source: `/run/media/adrioui/backup/home`, mounted
`ro,nosuid,nodev,relatime,errors=remount-ro`.
Method: unprivileged `find -xdev -printf` plus
`getent passwd`/`getent group` on distinct IDs. No backup writes.

## 1. Root-owned

| Measure | Count |
|---|---:|
| Root-owned entries | 192,782 |
| Root-owned files | 170,171 |
| Root-owned directories | 22,413 |
| Root-owned files under `.herdr` + `Works/Bangunindo/BLIV` | 32,326 |
| Size of those required files | about 1.93 GiB |

Root-owned files by top level:

| Top level | Files |
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

`Personal/` is dominated by `Personal/financial/actual` generated
`node_modules`, `.yarn/cache`, and build output (121,464 entries including
directories). Those are regenerable and excluded. `.pi` root-owned content is
not required by the user's `.herdr`/`Works/Bangunindo/BLIV` decision. Within `Works/`, only
`Works/Bangunindo/BLIV` is in scope; other `Works` trees are excluded.

Policy: hash root-owned files first; map only `.herdr` and
`Works/Bangunindo/BLIV` files and traversal directories; exclude all other
root-owned files. No recursive `chown` over the home. `.clawdbot/`,
`clickhouse-local/`, and non-BLIV `Works` trees are excluded by explicit user
decision (2026-10-31).

## 2. Non-1000, non-root ownership

After excluding container storage, `node_modules`, Yarn caches,
`clickhouse-local/`, and non-BLIV `Works`, 109 entries remain in Learns. The full raw
list is `non-1000-ownership.txt`; the in-scope list is
`non-1000-ownership-learns.txt`.

| UID:GID | Entries | Main location |
|---|---:|---|
| `1000:0` | 93 | `Learns/data-engineering/airflow` |
| `65532:65532` | 12 | `Learns/vibing/musiqasik/surrealdb-data` |
| `999:999` | 4 | `Learns/.../dlt-postgres-lakekeeper/.dlt` |
| `524288:524288` | 3 | `.local/share/distrobox` |

The 3 distrobox entries are excluded. Of the remaining 109 entries in
`Learns/`, 93 are `1000:0` (valid user with group root) and 16 are
`999:999`/`65532:65532` under `.dlt` and `surrealdb-data`. Those two subtrees
are runtime database state, not source; exclude them as regenerable. If the
user needs that state, it reopens A3b with an explicit ID-mapping decision.
Do not silently map IDs to `1000:1000`.

## 3. Container/generated trees already excluded

- `.local/share/containers/` — overlay and volume IDs in the `524xxx`,
  `589xxx`, etc. range.
- `**/node_modules/` and `**/.yarn/cache/`.
- `clickhouse-local/` data/logs (excluded by user decision; database tool
  state).
- `Learns/.../airflow/logs/` and other generated run state.
- `.local/share/distrobox/` (excluded by user; container tool state).
- All non-BLIV `Works` trees and all other top-level data except Agent
  conversation history (excluded by the revised 2026-10-31 scope).

If any of these is actually required, it must be handled as a separate data
restore, not by a blanket ownership rewrite.

## 4. Agent history scope

The revised scope includes “history from my conversations with Agent” but not
the rest of the agent application state. The exact application set is pending.
Do not copy whole `.claude`, `.pi`, `.codex`, `.amp`, `.cursor`, `.windsurf`,
or `.factory` trees wholesale: they contain auth files, caches, binaries,
sockets, and plugin state. Copy only transcript/session files once the user
names the Agent application.

Candidate transcript stores: `sessions/`, `.codex/history.jsonl`,
`.claude/projects/` + `.claude/history.jsonl`, and
`.pi/agent/runtime-events/`. These are candidates, not approved.

## 5. Verification still required

The unprivileged metadata walk cannot enter root-owned directories such as
`.clawdbot/agents`, `.clawdbot/telegram`, several container volume `_data`
directories, and `clickhouse-local` internals. A root TTY must:
1. complete the metadata and content hash streams;
2. regenerate the root-owned map/exclude lists;
3. prove no unexpected root-owned file remains in included paths after mapping.
