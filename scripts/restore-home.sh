#!/usr/bin/env bash










set -Eeuo pipefail
umask 077

SRC=${SRC:-/run/media/adrioui/backup/home}
STAGE=${STAGE:-/home/adrioui.restore}
EVID=${EVID:-/var/log/duniawi-migration/$(date +%Y%m%dT%H%M%S)}
INCLUDE_FILE=${INCLUDE_FILE:-}
MAP_ROOT_OWNED=${MAP_ROOT_OWNED:-1}
FORCE=${FORCE:-0}
MIN_FREE_GB=${MIN_FREE_GB:-80}

die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
log() { printf '%s %s\n' "$(date -Is)" "$*"; }
fail=0
check() {
  if [ "$2" = "$3" ]; then
    log "PASS $1 ($3)"
    printf '%s\tPASS\t%s\n' "$1" "$3" >>"$EVID/checks.tsv"
  else
    log "FAIL $1 expected=$2 actual=$3"
    printf '%s\tFAIL\t%s\n' "$1" "$3" >>"$EVID/checks.tsv"
    fail=1
  fi
}

[ "$(id -u)" -eq 0 ] || die "run as root from a local TTY"
[ -d "$SRC" ] || die "source home not found at $SRC"








if findmnt -no OPTIONS --target "$SRC" 2>/dev/null | grep -qE '(^|,)ro(,|$)'; then
    log "source is mounted read-only"
else
    [ "${ALLOW_WRITABLE_SOURCE:-0}" = "1" ] \
        || die "source $SRC is not mounted read-only; refusing (set ALLOW_WRITABLE_SOURCE=1 only for a fixture)"
    log "WARNING: source is not read-only; continuing because ALLOW_WRITABLE_SOURCE=1"
fi

[ -e "$STAGE" ] && die "stage already exists at $STAGE; inspect it or remove it deliberately"

mkdir -p "$EVID"
exec > >(tee -a "$EVID/restore.log") 2>&1
: >"$EVID/checks.tsv"

avail=$(df -BG --output=avail "$(dirname "$STAGE")" | tail -1 | tr -dc '0-9')
log "free under $(dirname "$STAGE"): ${avail}G"
[ "${avail:-0}" -ge "$MIN_FREE_GB" ] || die "need at least ${MIN_FREE_GB}G free"





if [ -n "$INCLUDE_FILE" ]; then
    mapfile -t INC <"$INCLUDE_FILE"
else
    INC=(
        Works/Bangunindo/BLIV
        Personal
        Learns
        sessions
        .codex/sessions
        .codex/history.jsonl
        .codex/session_index.jsonl
        .claude/projects
        .claude/history.jsonl
        .pi/agent/sessions
        .pi/agent/runtime-events
        .cursor/chats
        .cline/tasks
        .cline/data/sessions
    )
    for w in "$SRC"/.herdr/worktrees/btj--bliv*; do
        [ -e "$w" ] && INC+=(".herdr/worktrees/$(basename "$w")")
    done
fi
printf '%s\n' "${INC[@]}" | tee "$EVID/include.txt"
for p in "${INC[@]}"; do
    [ -e "$SRC/$p" ] || die "include path missing from source: $p"
done













RULES_SRC=${RULES_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rsync-filter.rules}
[ -f "$RULES_SRC" ] || die "filter rules not found at $RULES_SRC"
cp "$RULES_SRC" "$EVID/rsync-filter.rules"
sha256sum "$EVID/rsync-filter.rules" | tee "$EVID/rsync-filter.sha256"







mkdir -m 0700 "$STAGE"
for p in "${INC[@]}"; do
    log "copy $p"
    (
        cd "$SRC"
        rsync -aHASX --numeric-ids --relative \
            --filter="merge $EVID/rsync-filter.rules" \
            --info=stats2 "$p" "$STAGE/"
    ) || die "rsync failed for $p"
done



chown -h 1000:1000 "$STAGE"
chmod 0700 "$STAGE"







if [ "$MAP_ROOT_OWNED" = "1" ]; then
    sensitive=$(find "$STAGE/.herdr" "$STAGE/Works/Bangunindo/BLIV" -xdev \
        -uid 0 \( -perm -4000 -o -perm -2000 \) -print 2>/dev/null | wc -l)
    capped=$(find "$STAGE/.herdr" "$STAGE/Works/Bangunindo/BLIV" -xdev \
        -uid 0 -exec getcap {} + 2>/dev/null | wc -l)
    log "root-owned files to map with setuid/setgid=$sensitive capabilities=$capped"
    if [ "$sensitive" -ne 0 ] || [ "$capped" -ne 0 ]; then
        [ "$FORCE" = "1" ] || die "mapping would destroy $sensitive setuid and $capped capability file(s); set FORCE=1 to accept"
    fi
    find "$STAGE/.herdr" "$STAGE/Works/Bangunindo/BLIV" -xdev -uid 0 \
        -printf '%p\n' >"$EVID/root-owned-mapped.txt" 2>/dev/null || true
    find "$STAGE/.herdr" "$STAGE/Works/Bangunindo/BLIV" -xdev -uid 0 \
        -exec chown -h 1000:1000 {} + 2>/dev/null || true
    log "mapped $(wc -l <"$EVID/root-owned-mapped.txt") root-owned entries"
fi








check "no-uid-0-in-mapped-trees" "0" \
    "$(find "$STAGE/.herdr" "$STAGE/Works/Bangunindo/BLIV" -xdev -uid 0 -print 2>/dev/null | wc -l)"
log "root-owned entries outside the mapped trees: $(find "$STAGE" -xdev -uid 0 -print 2>/dev/null | wc -l)"
check "no-foreign-uid" "0" "$(find "$STAGE" -xdev ! -uid 0 ! -uid 1000 -print 2>/dev/null | wc -l)"
check "no-foreign-gid" "0" "$(find "$STAGE" -xdev ! -gid 0 ! -gid 1000 -print 2>/dev/null | wc -l)"
check "home-mode" "700" "$(stat -c %a "$STAGE")"
log "files: $(find "$STAGE" -xdev -type f | wc -l)  dirs: $(find "$STAGE" -xdev -type d | wc -l)  bytes: $(du -sb "$STAGE" | cut -f1)"
log "include and filter hashes are in $EVID; run verify-home.sh next"
exit "$fail"
