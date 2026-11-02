#!/usr/bin/env bash















set -Eeuo pipefail







export LC_ALL=C

SRC=${SRC:-/run/media/adrioui/backup/home}
STAGE=${STAGE:-/home/adrioui.restore}
EVID=${EVID:-/var/log/duniawi-migration/$(date +%Y%m%dT%H%M%S)}
OLD_HOME=${OLD_HOME:-/var/home/adrifadilah}
NEW_HOME=${NEW_HOME:-/home/adrioui}
INCLUDE_FILE=${INCLUDE_FILE:-}
CHECKSUM=0
DEEP=0
for a in "$@"; do
    case "$a" in
        --checksum) CHECKSUM=1 ;;
        --deep) DEEP=1 ;;
        *) echo "unknown option $a" >&2; exit 2 ;;
    esac
done

die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
log() { printf '%s %s\n' "$(date -Is)" "$*"; }
fail=0
check() {
    if [ "$2" = "$3" ]; then
        log "PASS $1 ($3)"; printf '%s\tPASS\t%s\n' "$1" "$3" >>"$EVID/verify.tsv"
    else
        log "FAIL $1 expected=$2 actual=$3"; printf '%s\tFAIL\t%s\n' "$1" "$3" >>"$EVID/verify.tsv"; fail=1
    fi
}

[ "$(id -u)" -eq 0 ] || die "run as root from a local TTY"
[ -d "$STAGE" ] || die "no stage at $STAGE"
mkdir -p "$EVID"
exec > >(tee -a "$EVID/verify.log") 2>&1
: >"$EVID/verify.tsv"
log "mode: deep=$DEEP checksum=$CHECKSUM"

RULES=$EVID/rsync-filter.rules
[ -f "$RULES" ] || die "missing $RULES from restore-home.sh; cannot compare like with like"
sha256sum "$RULES"

if [ -n "$INCLUDE_FILE" ]; then
    mapfile -t INC <"$INCLUDE_FILE"
else
    INC=(
        Works/Bangunindo/BLIV Personal Learns sessions
        .codex/sessions .codex/history.jsonl .codex/session_index.jsonl
        .claude/projects .claude/history.jsonl
        .pi/agent/sessions .pi/agent/runtime-events
        .cursor/chats .cline/tasks .cline/data/sessions
    )
    for w in "$SRC"/.herdr/worktrees/btj--bliv*; do
        [ -e "$w" ] && INC+=(".herdr/worktrees/$(basename "$w")")
    done
fi










log "=== oracle 1: rsync drift ==="
: >"$EVID/drift.txt"
for p in "${INC[@]}"; do
    (
        cd "$SRC"
        if [ "$CHECKSUM" = "1" ]; then
            rsync -rlptHASXnc --numeric-ids --relative \
                --filter="merge $RULES" --itemize-changes "$p" "$STAGE/"
        else
            rsync -rlptHASXn --numeric-ids --relative \
                --filter="merge $RULES" --itemize-changes "$p" "$STAGE/"
        fi
    ) >>"$EVID/drift.txt" 2>&1 || true
done
check "drift-lines" "0" "$(wc -l <"$EVID/drift.txt")"






log "=== oracle 2: exclusion reconciliation ==="
cat >"$EVID/exclusion-policy.ere" <<'POLICY'
(^|/)\.ssh/
(^|/)\.gnupg/
(^|/)\.password-store/
(^|/)\.aws/credentials$
(^|/)\.netrc$
(^|/)\.git-credentials$
(^|/)\.env$
^\.config/gh/hosts\.yml$
^\.config/sops/age/keys\.txt$
^\.docker/config\.json$
(^|/)\.kube/config$
^Works/Bangunindo/BLIV/license_key\.txt$
(^|/)id_rsa$
(^|/)id_ed25519$
(^|/)id_ecdsa$
\.kdbx$
^Personal/(.*/)?node_modules/
^Personal/(.*/)?\.yarn/cache/
^Personal/(.*/)?\.swc/
^Personal/(.*/)?lib-dist/
^Personal/(.*/)?dist/
^Personal/(.*/)?target/
^Learns/(.*/)?airflow/logs/
^Learns/(.*/)?\.dlt/
^Learns/(.*/)?surrealdb-data/
\.sock$
\.pid$
POLICY
( cd "$SRC" && find "${INC[@]}" -xdev -type f -print 2>/dev/null ) | LC_ALL=C sort -u >"$EVID/source-files.txt"
( cd "$STAGE" && find . -xdev -type f -printf '%P\n' 2>/dev/null ) | LC_ALL=C sort -u >"$EVID/stage-files.txt"
comm -23 "$EVID/source-files.txt" "$EVID/stage-files.txt" >"$EVID/not-copied.txt"
grep -Ev -f "$EVID/exclusion-policy.ere" "$EVID/not-copied.txt" >"$EVID/not-explained.txt" || true
log "source=$(wc -l <"$EVID/source-files.txt") stage=$(wc -l <"$EVID/stage-files.txt") not-copied=$(wc -l <"$EVID/not-copied.txt") unexplained=$(wc -l <"$EVID/not-explained.txt")"
check "unexplained-exclusions" "0" "$(wc -l <"$EVID/not-explained.txt")"

if [ -s "$EVID/not-explained.txt" ]; then
    log "first unexplained paths:"; head -20 "$EVID/not-explained.txt" | sed 's/^/  /'
fi




log "=== oracle 3: secret absence ==="
secrets=(
    .ssh/id_rsa .ssh/id_ed25519 .gnupg .aws/credentials .netrc .git-credentials
    .config/gh/hosts.yml .config/sops/age/keys.txt .docker/config.json .kube/config
    Works/Bangunindo/BLIV/license_key.txt
)
present=0
for s in "${secrets[@]}"; do
    if [ -e "$STAGE/$s" ]; then log "SECRET PRESENT: $s"; present=$((present + 1)); fi
done


dotenv=$(find "$STAGE" -xdev -type f -name '.env' -printf '.' 2>/dev/null | wc -c)
if [ "$dotenv" -ne 0 ]; then
    log "SECRET PRESENT: .env basenames=$dotenv"
    present=$((present + dotenv))
fi
check "secret-paths-present" "0" "$present"
if command -v gitleaks >/dev/null 2>&1; then
    if gitleaks detect --no-git --redact --max-target-megabytes 10 --source "$STAGE" \
        >"$EVID/gitleaks.log" 2>&1; then
        check "gitleaks" "0" "0"
    else
        check "gitleaks" "0" "leaks"
    fi
else
    log "gitleaks not on PATH; content secret scan NotRun"
    printf 'gitleaks\tNotRun\tno binary\n' >>"$EVID/verify.tsv"
fi





log "=== oracle 4: git ==="
bad_ptr=0
while IFS= read -r -d '' g; do
    gd=$(sed -n 's/^gitdir: //p' "$g")
    [ -n "$gd" ] || continue
    case "$gd" in
        "$OLD_HOME"/*) rel=${gd#"$OLD_HOME"/} ;;
        "$NEW_HOME"/*) rel=${gd#"$NEW_HOME"/} ;;
        "$STAGE"/*) rel=${gd#"$STAGE"/} ;;
        *) log "external gitdir (not this home): $g -> $gd"; continue ;;
    esac
    if [ ! -e "$STAGE/$rel" ]; then
        log "DANGLING gitdir after move: $g -> $rel"
        bad_ptr=$((bad_ptr + 1))
    fi
done < <(find "$STAGE" -xdev -name .git -type f -print0 2>/dev/null)
check "worktree-pointers" "0" "$bad_ptr"

fsck_ok=0 fsck_pre=0 fsck_reg=0
while IFS= read -r -d '' g; do
    root=$(dirname "$g")
    strict=(--connectivity-only)
    if [ "$DEEP" = "1" ]; then
        strict=(--full --strict)
    fi
    if git -c safe.directory='*' -C "$root" fsck "${strict[@]}" >>"$EVID/git-fsck.log" 2>&1; then
        fsck_ok=$((fsck_ok + 1))
    else
        src_root="$SRC/${root#"$STAGE"/}"
        if [ -d "$src_root" ] && git -c safe.directory='*' -C "$src_root" fsck "${strict[@]}" >/dev/null 2>&1; then
            log "FSCK REGRESSION: ${root#"$STAGE"/}"
            printf '%s\n' "${root#"$STAGE"/}" >>"$EVID/git-regression.txt"
            fsck_reg=$((fsck_reg + 1))
        else
            printf '%s\n' "${root#"$STAGE"/}" >>"$EVID/git-preexisting.txt"
            fsck_pre=$((fsck_pre + 1))
        fi
    fi
done < <(find "$STAGE" -xdev -name .git -type d -print0 2>/dev/null)
log "fsck ok=$fsck_ok pre-existing=$fsck_pre regression=$fsck_reg"
check "git-fsck-regression" "0" "$fsck_reg"






log "=== oracle 5: sqlite ==="
SQLITE=${SQLITE:-$(command -v sqlite3 || true)}
if [ -z "$SQLITE" ]; then
    log "sqlite3 not on PATH; SQLite audit NotRun"
    printf 'sqlite\tNotRun\tno binary\n' >>"$EVID/verify.tsv"
else
    mapfile -t dbs < <(find "$STAGE" -xdev -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print 2>/dev/null)
    wal_pairs=0
    for db in "${dbs[@]}"; do [ -f "$db-wal" ] && wal_pairs=$((wal_pairs + 1)); done
    log "databases=${#dbs[@]} with-wal=$wal_pairs"
    if [ "$DEEP" = "1" ]; then sample=("${dbs[@]}"); else
        sample=(); for i in "${!dbs[@]}"; do [ $((i % 40)) -eq 0 ] && sample+=("${dbs[$i]}"); done
        for db in "${dbs[@]}"; do [ -f "$db-wal" ] && sample+=("$db"); done
    fi
    tmp=$(mktemp -d "$EVID/dbtmp.XXXXXX"); ok=0 bad=0
    trap 'rm -rf "${tmp:-}"' EXIT
    for db in "${sample[@]}"; do
        rm -f "$tmp/c.db" "$tmp/c.db-wal" "$tmp/c.db-shm"
        cp "$db" "$tmp/c.db" 2>/dev/null || continue
        [ -f "$db-wal" ] && cp "$db-wal" "$tmp/c.db-wal" || true
        [ -f "$db-shm" ] && cp "$db-shm" "$tmp/c.db-shm" || true
        if r=$("$SQLITE" "$tmp/c.db" 'PRAGMA integrity_check;' 2>&1) && [ "$r" = "ok" ]; then
            ok=$((ok + 1))
        else
            bad=$((bad + 1)); printf 'FAIL %s\n%s\n' "$db" "$r" >>"$EVID/db-fail.txt"
        fi
    done
    log "sqlite checked=$ok bad=$bad"
    check "sqlite-integrity" "0" "$bad"
fi





log "=== census ==="
log "stage hardlinked files: $(find "$STAGE" -xdev -type f -links +1 | wc -l)"
log "stage sparse files:     $(find "$STAGE" -xdev -type f -printf '%s %b\n' | awk '$2*512 < $1' | wc -l)"
log "stage bytes:            $(du -sb "$STAGE" | cut -f1)"



oracles=$(awk -F'\t' '$2=="PASS" || $2=="FAIL"' "$EVID/verify.tsv" | wc -l)
result=$([ "$fail" -eq 0 ] && echo PASS || echo FAIL)





printf 'verify-complete\t%s\t%s\n' "$result" "$oracles" >>"$EVID/verify.tsv"
log "=== result: $result ($oracles oracle rows) ==="
cat "$EVID/verify.tsv"
exit "$fail"
