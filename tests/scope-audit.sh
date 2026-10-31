#!/usr/bin/env bash


set -euo pipefail

backup=${BACKUP:-/run/media/adrioui/backup}
home="$backup/home"
out=${OUT:-/var/tmp/duniawi-scope-audit-$(date +%Y%m%dT%H%M%S)}
mkdir -p "$out"

include=(
  "Works/Bangunindo/BLIV"
  ".herdr/worktrees"
  "Personal"
  "Learns"
  "sessions"
  ".codex/sessions"
  ".codex/history.jsonl"
  ".codex/session_index.jsonl"
  ".claude/projects"
  ".claude/history.jsonl"
  ".pi/agent/sessions"
  ".pi/agent/runtime-events"
  ".cursor/chats"
  ".cline/tasks"
  ".cline/data/sessions"
)

{
  echo "# date $(date -Is)"
  echo "# backup $(findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS "$backup")"
  echo "# include paths"
  printf '%s\n' "${include[@]}"
  echo "# counts and sizes"
  for p in "${include[@]}"; do
    if [ -e "$home/$p" ]; then
      files=$(find "$home/$p" -xdev -type f -print 2>/dev/null | wc -l)
      size=$(du -sh "$home/$p" 2>/dev/null | cut -f1)
      printf '%-36s files=%-9s size=%s\n' "$p" "$files" "$size"
    else
      printf '%-36s MISSING\n' "$p"
    fi
  done
} >"$out/inventory.log" 2>&1

find_args=()
for p in "${include[@]}"; do
  [ -e "$home/$p" ] && find_args+=("$home/$p")
done

{
  echo "# date $(date -Is)"
  echo "# path-only secret inventory; no file contents are read"
  find "${find_args[@]}" -xdev -type f \
    \( -name '.env' -o -name '*.env' -o -name '*.key' -o -name '*.pem' \
    -o -name 'id_*' -o -name 'credentials*' -o -name '*.p12' -o -name '*.pfx' \
    -o -name 'auth.json' -o -name 'keys.txt' \) -print 2>/dev/null | sort
} >"$out/secret-paths.txt" 2>&1

{
  echo "# date $(date -Is)"
  echo "# path-only root-owned inventory for included data"
  find "${find_args[@]}" -xdev -uid 0 -printf '%y %m %s %p\n' 2>/dev/null | sort
} >"$out/root-owned.txt" 2>&1

{
  echo "# date $(date -Is)"
  echo "# non-1000 owners outside generated/root-owned state"
  find "${find_args[@]}" -xdev -printf '%U:%G %y %p\n' 2>/dev/null \
    | awk '$1 != "1000:1000" && $1 != "0:0"' | sort
} >"$out/non-1000.txt" 2>&1

{
  echo "# date $(date -Is)"
  echo "# SQLite/database path inventory"
  find "${find_args[@]}" -xdev -type f \
    \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' \) -print 2>/dev/null | sort
} >"$out/db-paths.txt" 2>&1

{
  echo "# date $(date -Is)"
  echo "include_files=$(find "${find_args[@]}" -xdev -type f -print 2>/dev/null | wc -l)"
  echo "secret_paths=$(grep -vc '^#' "$out/secret-paths.txt" || true)"
  echo "root_owned_entries=$(grep -vc '^#' "$out/root-owned.txt" || true)"
  echo "required_root_owned_entries=$(grep -v '^#' "$out/root-owned.txt" | grep -cE '/\.herdr/|/Works/Bangunindo/BLIV/' || true)"
  echo "non_1000_entries=$(grep -vc '^#' "$out/non-1000.txt" || true)"
  echo "db_entries=$(grep -vc '^#' "$out/db-paths.txt" || true)"
  echo "backup_options=$(findmnt -no OPTIONS "$backup")"
} >"$out/summary.log" 2>&1

cat "$out/summary.log"
echo "scope-audit: reports in $out"
