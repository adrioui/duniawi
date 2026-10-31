#!/usr/bin/env bash




set -euo pipefail

list=${1:?usage: db-audit.sh DB-PATH-LIST}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ok=0
bad=0
skip=0

while IFS= read -r db; do
  case "$db" in
    ''|\#*) continue ;;
  esac
  [ -f "$db" ] || { skip=$((skip + 1)); continue; }
  cp --reflink=auto "$db" "$tmp/check.db" 2>/dev/null || cp "$db" "$tmp/check.db"
  [ -f "$db-wal" ] && cp "$db-wal" "$tmp/check.db-wal" || true
  [ -f "$db-shm" ] && cp "$db-shm" "$tmp/check.db-shm" || true

  if result=$(sqlite3 "$tmp/check.db" 'PRAGMA integrity_check;' 2>&1) && [ "$result" = "ok" ]; then
    ok=$((ok + 1))
  else
    bad=$((bad + 1))
    printf 'FAIL %s\n%s\n' "$db" "$result"
  fi
  rm -f "$tmp/check.db" "$tmp/check.db-wal" "$tmp/check.db-shm"
done <"$list"

printf 'db-audit: ok=%d bad=%d skip=%d\n' "$ok" "$bad" "$skip"
[ "$bad" -eq 0 ]
