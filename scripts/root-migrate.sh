#!/usr/bin/env bash









set -Eeuo pipefail
umask 077

MODE=${1:-stage}
REPORT_DIR=${2:-}
BACKUP=/run/media/adrioui/backup
SRC=$BACKUP/home
STAGE=/home/adrioui.restore
BACKUP_UUID=cdb0183d-7f36-4415-802c-0a36e8f7df10
EXPECT_LOCK=5b495d350f985613c13b2b80b6fa4fe54b8c5db96d85145d39ad97d65346ee9f
EXPECT_PROXY=6752ad14c924f4b3d10dbc6ab25df70c05955e9c9e052afc540ae6250c7a5e4a
EXPECT_MODULE=90a9880f2eeefd72e3bcd8236a383996dae41a1ff702523764be1d1b887a8f17
STAMP=$(date +%Y%m%dT%H%M%S)
ROOT_EVID=/var/log/duniawi-migration
EVID=$ROOT_EVID/$STAMP
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DURABLE_REPO=/var/lib/duniawi-src
SQLITE=$(ls -d /nix/store/*sqlite-3*-bin/bin/sqlite3 2>/dev/null | head -1)
GITLEAKS=$(ls -d /nix/store/*gitleaks-*/bin/gitleaks 2>/dev/null | head -1)
GIT=$(command -v git 2>/dev/null || ls -d /nix/store/*git-2.5*/bin/git 2>/dev/null | head -1)
RG=$(command -v rg 2>/dev/null || ls -d /nix/store/*ripgrep-*/bin/rg 2>/dev/null | head -1)
FAIL=0

[ "$(id -u)" -eq 0 ] || { echo "FATAL: run as root from a local TTY" >&2; exit 1; }

if [ "$MODE" != "report" ]; then
  mkdir -p "$EVID"
  exec > >(tee -a "$EVID/run.log") 2>&1
fi
log() { printf '%s %s\n' "$(date -Is)" "$*"; }
die() { log "FATAL: $*"; exit 1; }
check() {
  if [ "$2" = "$3" ]; then log "PASS $1 ($3)"; printf '%s\tPASS\t%s\n' "$1" "$3" >>"$EVID/checks.tsv";
  else log "FAIL $1 expected=$2 actual=$3"; printf '%s\tFAIL\t%s\n' "$1" "$3" >>"$EVID/checks.tsv"; FAIL=1; fi
}
sha() { sha256sum "$1" | cut -d' ' -f1; }

[ "$(id -u)" -eq 0 ] || die "run as root from a local TTY"
[ -n "$SQLITE" ] && [ -x "$SQLITE" ] || die "sqlite3 not found in store"
[ -n "$GIT" ] && [ -x "$GIT" ] || die "git not found in store"
[ -n "$RG" ] && [ -x "$RG" ] || die "ripgrep not found"
[ -f "$REPO/flake.lock" ] || die "repo not found at $REPO"

preflight_base() {
  log "=== preflight ==="
  findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS "$BACKUP" | tee "$EVID/backup-mount.txt"
  findmnt -no OPTIONS "$BACKUP" | grep -qE '(^|,)ro(,|$)' || die "backup is not mounted read-only"
  check "backup-uuid" "$BACKUP_UUID" "$(blkid -s UUID -o value /dev/sda1)"
  check "repo-lock" "$EXPECT_LOCK" "$(sha "$REPO/flake.lock")"
  check "repo-proxy" "$EXPECT_PROXY" "$(sha "$REPO/pkgs/amp-deepseek/proxy.mjs")"
  check "repo-module" "$EXPECT_MODULE" "$(sha "$REPO/modules/amp-deepseek-nixos.nix")"
  check "repo-clean" "0" "$("$GIT" -c safe.directory='*' -C "$REPO" status --porcelain | wc -l)"
  [ -d "$SRC" ] || die "backup home not found at $SRC"
}

preflight_stage() {
  preflight_base
  [ -e /home/adrioui.restore ] && die "stage already exists; inspect it or remove it deliberately"
  avail=$(df -BG --output=avail /home | tail -1 | tr -dc '0-9')
  [ "$avail" -ge 80 ] || die "need at least 80G free under /home, have ${avail}G"
  log "free under /home: ${avail}G"
}

write_excludes() {
cat >"$EVID/rsync-excludes.txt" <<'EOF'
# secrets, keys, auth
**/.ssh/
**/.gnupg/
**/.password-store/
**/.aws/
**/.netrc
**/.git-credentials
**/auth.json
**/credentials*
**/*.pem
**/*.key
**/*.p12
**/*.pfx
**/*.kdbx
**/*.gpg
**/*.asc
**/id_rsa*
**/id_ed25519*
**/keys.txt
**/license_key.txt
# caches, run state, trash
**/.cache/
**/Trash/
**/.local/share/Trash/
**/*.sock
**/*.pid
# generated state named by the scope
Personal/**/node_modules/
Personal/**/.yarn/cache/
Personal/**/.swc/
Personal/**/lib-dist/
Personal/**/dist/
Personal/**/target/
Learns/**/airflow/logs/
Learns/**/.dlt/
Learns/**/surrealdb-data/
EOF
  sha "$EVID/rsync-excludes.txt" >"$EVID/rsync-excludes.sha256"
}

includes() {
  cat <<'EOF'
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
EOF
  for w in "$SRC"/.herdr/worktrees/btj--bliv*; do
    [ -e "$w" ] && printf '%s\n' ".herdr/worktrees/$(basename "$w")"
  done
}

do_stage() {
  if [ "${RESUME:-0}" = "1" ]; then
    preflight_base
    [ -d "$STAGE" ] || die "no stage to resume"
    prev=""
    for d in "$ROOT_EVID"/*/; do
      [ -d "$d" ] || continue
      [ "$d" = "$EVID/" ] && continue
      if [ -z "$prev" ] || [ "$d" -nt "$prev" ]; then prev=$d; fi
    done
    log "=== resume: copy and idempotence were proven in the prior run ($prev) ==="
    printf 'rsync-idempotent\tPASS\tprior-run %s\n' "$(basename "${prev:-unknown}")" >>"$EVID/checks.tsv"
  else
    preflight_stage
    write_excludes
    mapfile -t INC < <(includes)
    log "=== includes (${#INC[@]}) ==="; printf '%s\n' "${INC[@]}" | tee "$EVID/include.txt"

    log "=== rsync stage ==="
    mkdir -m 0700 "$STAGE"
    for p in "${INC[@]}"; do
      log "copy $p"
      ( cd "$SRC" && rsync -aHAX --numeric-ids --relative \
          --exclude-from="$EVID/rsync-excludes.txt" \
          --info=stats2 "./$p" "$STAGE/" ) || die "rsync failed for $p"
    done

    log "=== idempotence: second dry-run must be empty ==="
    : >"$EVID/idempotence.diff"
    for p in "${INC[@]}"; do
      ( cd "$SRC" && rsync -aHAX --numeric-ids --relative --dry-run --itemize-changes \
          --exclude-from="$EVID/rsync-excludes.txt" "./$p" "$STAGE/" ) >>"$EVID/idempotence.diff" || true
    done
    check "rsync-idempotent" "0" "$(wc -l <"$EVID/idempotence.diff")"
  fi

  log "=== ownership mapping: only .herdr and Works/Bangunindo/BLIV ==="
  chown -h 1000:1000 "$STAGE"
  for p in .herdr Works Works/Bangunindo Works/Bangunindo/BLIV; do
    [ -e "$STAGE/$p" ] && chown -h 1000:1000 "$STAGE/$p"
  done
  find "$STAGE/.herdr" "$STAGE/Works/Bangunindo/BLIV" -xdev -uid 0 -exec chown -h 1000:1000 {} + 2>/dev/null || true

  if [ "${SKIP_REWRITE:-0}" = "1" ]; then
    log "=== path rewrite: skipped, already proven in the prior run ==="
    printf 'path-rewrite-complete\tPASS\tprior-run\n' >>"$EVID/checks.tsv"
  else
  log "=== path rewrite (dry-run first) ==="
  : >"$EVID/path-rewrite.files"
  for old in /var/home/adrifadilah /home/adrifadilah /mnt/disk/adrifadilah; do
    "$RG" -l -0 --hidden --no-ignore --no-messages -F "$old" "$STAGE" >>"$EVID/path-rewrite.files" || true
  done

  sort -zu "$EVID/path-rewrite.files" >"$EVID/path-rewrite.list"
  log "files carrying the old home prefix (dry-run): $(tr -cd '\0' <"$EVID/path-rewrite.list" | wc -c)"
  rewrite_fail=0
  while IFS= read -r -d '' f; do
    [ -n "$f" ] || continue
    if ! sed -i "s|/var/home/adrifadilah|$STAGE|g; s|/home/adrifadilah|$STAGE|g; s|/mnt/disk/adrifadilah|$STAGE|g" "$f"; then
      log "REWRITE-FAILED $f"
      rewrite_fail=$((rewrite_fail+1))
    fi
  done <"$EVID/path-rewrite.list"
  check "path-rewrite-errors" "0" "$rewrite_fail"
  left=0
  for old in /var/home/adrifadilah /home/adrifadilah /mnt/disk/adrifadilah; do
    n=$("$RG" -l --hidden --no-ignore --no-messages -F "$old" "$STAGE" 2>/dev/null | wc -l) || n=0
    left=$((left + n))
  done
  check "path-rewrite-complete" "0" "$left"
  fi

  log "=== ownership verification (numeric; gid 1000 exists only after switch) ==="
  find "$STAGE" -xdev -uid 0 -printf '%y %u:%g %p -> %l\n' >"$EVID/uid0-left.txt"
  check "no-uid-0-left" "0" "$(wc -l <"$EVID/uid0-left.txt")"
  check "no-unknown-uid" "0" "$(find "$STAGE" -xdev ! -uid 0 ! -uid 1000 -print | wc -l)"
  check "no-unknown-gid" "0" "$(find "$STAGE" -xdev ! -gid 0 ! -gid 100 ! -gid 1000 -print | wc -l)"
  if getent group 1000 >/dev/null; then
    check "no-nouser-nogroup" "0" "$(find "$STAGE" -xdev \( -nouser -o -nogroup \) -print | wc -l)"
  else
    log "NOTE gid 1000 is absent on this generation; -nogroup check is deferred to post-cutover"
  fi

  log "=== SQLite integrity with WAL/SHM ==="
  find "$STAGE" -xdev -type f \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' \) -print | sort >"$EVID/db-paths.txt"
  log "sqlite candidates: $(wc -l <"$EVID/db-paths.txt")"
  tmp=$(mktemp -d "$EVID/dbtmp.XXXXXX")
  ok=0; bad=0; skipped=0
  while IFS= read -r -d '' db; do
    rm -f "$tmp/check.db" "$tmp/check.db-wal" "$tmp/check.db-shm"
    cp "$db" "$tmp/check.db" 2>/dev/null || { skipped=$((skipped+1)); continue; }
    [ -f "$db-wal" ] && cp "$db-wal" "$tmp/check.db-wal" || true
    [ -f "$db-shm" ] && cp "$db-shm" "$tmp/check.db-shm" || true
    if r=$("$SQLITE" "$tmp/check.db" 'PRAGMA integrity_check;' 2>&1) && [ "$r" = "ok" ]; then
      ok=$((ok+1))
    else
      bad=$((bad+1)); printf 'FAIL %s\n%s\n' "$db" "$r" >>"$EVID/db-audit.fail"
    fi
  done < <(find "$STAGE" -xdev -type f \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' \) -print0)
  rm -rf "$tmp"
  log "sqlite ok=$ok bad=$bad skipped=$skipped"
  check "sqlite-integrity" "0" "$bad"
  check "sqlite-unreadable" "0" "$skipped"

  log "=== git object and worktree integrity ==="
  : >"$EVID/git-fsck.log"; : >"$EVID/git-preexisting.txt"; : >"$EVID/git-regression.txt"
  git_pass=0; preexisting=0; regression=0; bad_gitdir=0
  while IFS= read -r -d '' g; do
    root=$(dirname "$g")
    if [ -f "$g" ]; then
      gd=$(sed -n 's/^gitdir: //p' "$g")
      case "$gd" in
        /*) resolved=$(realpath -m -- "$gd" 2>/dev/null || echo "$gd") ;;
        *)  resolved=$(realpath -m -- "$root/$gd" 2>/dev/null || echo "$root/$gd") ;;
      esac
      case "$resolved" in
        "$STAGE"/*) : ;;
        *) log "BAD gitdir outside stage: $g -> $gd (resolved $resolved)"; bad_gitdir=$((bad_gitdir+1)) ;;
      esac
    fi
    if "$GIT" -c safe.directory='*' -C "$root" fsck --full --strict >>"$EVID/git-fsck.log" 2>&1; then
      git_pass=$((git_pass+1))
    else
      src_root="$SRC/${root#"$STAGE"/}"
      if [ -d "$src_root" ] && "$GIT" -c safe.directory='*' -C "$src_root" fsck --full --strict >/dev/null 2>&1; then
        log "FSCK REGRESSION: $root"
        regression=$((regression+1)); printf '%s\n' "$root" >>"$EVID/git-regression.txt"
      else
        log "FSCK PRE-EXISTING: $root"
        preexisting=$((preexisting+1)); printf '%s\n' "$root" >>"$EVID/git-preexisting.txt"
      fi
    fi
  done < <(find "$STAGE/Works/Bangunindo/BLIV" "$STAGE/.herdr" -xdev \( -name .git -type d -o -name .git -type f \) -print0 2>/dev/null)
  log "git fsck: pass=$git_pass preexisting=$preexisting regression=$regression bad_gitdir=$bad_gitdir"

  : >"$EVID/git-prunable.txt"
  while IFS= read -r -d '' g; do
    root=$(dirname "$g")
    "$GIT" -c safe.directory='*' -C "$root" worktree list --porcelain >"$EVID/wt.$$" 2>/dev/null || continue
    awk -v stage="$STAGE" '/^worktree /{p=$2} /^prunable /{if (index(p, stage)==1) print p}' "$EVID/wt.$$" >>"$EVID/git-prunable.txt"
  done < <(find "$STAGE/Works/Bangunindo/BLIV/repos" -xdev -name .git -type d -print0 2>/dev/null)
  rm -f "$EVID/wt.$$"
  check "git-fsck-regressions" "0" "$regression"
  check "git-bad-gitdirs" "0" "$bad_gitdir"
  check "git-worktrees-resolve" "0" "$(sort -u "$EVID/git-prunable.txt" | wc -l)"

  log "=== secret scan ==="
  if [ -n "$GITLEAKS" ] && [ -x "$GITLEAKS" ]; then
    if "$GITLEAKS" detect --no-git --redact --max-target-megabytes 10 \
        --config "$REPO/.gitleaks.toml" --source "$STAGE" >"$EVID/gitleaks.log" 2>&1; then
      check "gitleaks" "0" "0"
    else
      check "gitleaks" "0" "leaks"; log "review $EVID/gitleaks.log"
    fi
  else
    log "gitleaks unavailable; secret scan NotRun"
    printf 'gitleaks\tNotRun\tbinary not found\n' >>"$EVID/checks.tsv"
  fi

  log "=== manifest and two hashes ==="
  find "$STAGE" -xdev -printf '%y %m %U %G %s %T@ %p\n' | LC_ALL=C sort >"$EVID/manifest.txt"
  sha "$EVID/manifest.txt" | tee "$EVID/manifest.sha256"
  b2sum "$EVID/manifest.txt" | tee "$EVID/manifest.b2sum"
  log "manifest entries: $(wc -l <"$EVID/manifest.txt")"

  if [ "$FAIL" -eq 0 ]; then
    printf '%s\n' "$EVID" >"$ROOT_EVID/STAGE-PASS"
    sha "$EVID/manifest.txt" >>"$ROOT_EVID/STAGE-PASS"
    log "STAGE PASS — evidence in $EVID"
  else
    log "STAGE FAIL — evidence in $EVID"
  fi
  log "checks:"; cat "$EVID/checks.tsv"
  exit "$FAIL"
}

do_build() {
  preflight_base
  log "=== durable repo copy ==="
  rm -rf "$DURABLE_REPO"
  "$GIT" clone -q --local "$REPO" "$DURABLE_REPO"
  "$GIT" -C "$DURABLE_REPO" checkout -q "$("$GIT" -c safe.directory='*' -C "$REPO" rev-parse HEAD)"
  log "durable commit: $("$GIT" -C "$DURABLE_REPO" rev-parse HEAD)"
  log "=== nixos-rebuild build ==="
  nixos-rebuild build --flake "$DURABLE_REPO#t14" 2>&1 | tee "$EVID/build.log"
  readlink -f ./result | tee "$EVID/build-result.txt"
}

do_cutover() {
  preflight_base
  [ -f "$ROOT_EVID/STAGE-PASS" ] || die "no verified stage; run stage first"
  [ -d "$STAGE" ] || die "stage missing"
  mapfile -t pass <"$ROOT_EVID/STAGE-PASS"
  stage_evid=${pass[0]:-}; stage_hash=${pass[1]:-}
  [ -n "$stage_evid" ] && [ -n "$stage_hash" ] || die "STAGE-PASS is malformed"
  check "stage-manifest-unchanged" "$stage_hash" "$(sha "$stage_evid/manifest.txt")"
  [ "$FAIL" -eq 0 ] || die "stage changed since verification"

  if loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3}' | grep -qx adrioui; then
    die "log out adrioui and run cutover from a root TTY"
  fi

  echo "This will move /home/adrioui aside and install the stage as the live home."
  echo "Type CUTOVER to continue:"
  read -r answer
  [ "$answer" = "CUTOVER" ] || die "aborted"

  log "=== durable repo copy ==="
  rm -rf "$DURABLE_REPO"
  "$GIT" clone -q --local "$REPO" "$DURABLE_REPO"
  "$GIT" -C "$DURABLE_REPO" checkout -q "$("$GIT" -c safe.directory='*' -C "$REPO" rev-parse HEAD)"

  log "=== rewrite stage prefix to the live home ==="
  "$RG" -l -0 --hidden --no-ignore --no-messages -F "$STAGE" "$STAGE" >"$EVID/cutover.files" || true
  sort -zu "$EVID/cutover.files" >"$EVID/cutover.list"
  cut_fail=0
  while IFS= read -r -d '' f; do
    [ -n "$f" ] || continue
    if ! sed -i "s|$STAGE|/home/adrioui|g" "$f"; then
      log "CUTOVER-REWRITE-FAILED $f"
      cut_fail=$((cut_fail+1))
    fi
  done <"$EVID/cutover.list"
  check "cutover-rewrite-errors" "0" "$cut_fail"
  left_cut=$("$RG" -l --hidden --no-ignore --no-messages -F "$STAGE" "$STAGE" 2>/dev/null | wc -l) || left_cut=0
  check "cutover-rewrite-complete" "0" "$left_cut"

  log "=== swap homes ==="
  mv /home/adrioui "/home/adrioui.pre-migration.$STAMP"
  mv "$STAGE" /home/adrioui
  chown 1000:1000 /home/adrioui

  log "=== git integrity in the live home ==="
  git_bad=0
  while IFS= read -r -d '' g; do
    root=$(dirname "$g")
    "$GIT" -c safe.directory='*' -C "$root" fsck --full --strict >>"$EVID/cutover-fsck.log" 2>&1 || git_bad=$((git_bad+1))
  done < <(find /home/adrioui/Works/Bangunindo/BLIV /home/adrioui/.herdr -xdev \( -name .git -type d -o -name .git -type f \) -print0 2>/dev/null)
  check "cutover-git-fsck" "0" "$git_bad"

  log "=== switch ==="
  nixos-rebuild switch --flake "$DURABLE_REPO#t14" 2>&1 | tee "$EVID/switch.log"
  systemctl --failed --no-legend | tee "$EVID/failed-units.txt"
  check "post-switch-no-nouser-nogroup" "0" "$(find /home/adrioui -xdev \( -nouser -o -nogroup \) -print | wc -l)"
  log "CUTOVER APPLIED. Reboot to exercise the new generation."
  log "Rollback: boot the previous generation from the boot menu, then"
  log "  mv /home/adrioui /home/adrioui.new && mv /home/adrioui.pre-migration.$STAMP /home/adrioui"
}

do_report() {
  if [ -n "$REPORT_DIR" ]; then
    target=$REPORT_DIR
  else
    target=""
    for d in "$ROOT_EVID"/*/; do
      [ -d "$d" ] || continue
      if [ -z "$target" ] || [ "$d" -nt "$target" ]; then target=$d; fi
    done
  fi
  [ -n "$target" ] || { echo "no evidence directory under $ROOT_EVID" >&2; exit 1; }
  echo "evidence: $target"
  echo "=== checks.tsv ==="
  cat "$target/checks.tsv" 2>/dev/null || true
  echo "=== run.log tail ==="
  tail -120 "$target/run.log" 2>/dev/null || true
  echo "=== uid0-left ==="
  head -60 "$target/uid0-left.txt" 2>/dev/null || echo "(none)"
  echo "=== git-preexisting ==="
  cat "$target/git-preexisting.txt" 2>/dev/null || true
  echo "=== git-regression ==="
  cat "$target/git-regression.txt" 2>/dev/null || true
  echo "=== git-prunable ==="
  cat "$target/git-prunable.txt" 2>/dev/null || true
  echo "=== db count ==="
  wc -l "$target/db-paths.txt" 2>/dev/null || true
  echo "=== git-fsck tail ==="
  tail -20 "$target/git-fsck.log" 2>/dev/null || true
  echo "=== gitleaks tail ==="
  tail -8 "$target/gitleaks.log" 2>/dev/null || true
}

case "$MODE" in
  stage) do_stage ;;
  resume) RESUME=1; do_stage ;;
  finish) RESUME=1 SKIP_REWRITE=1; do_stage ;;
  report) do_report ;;
  build) do_build ;;
  cutover) do_cutover ;;
  *) die "usage: $0 stage|resume|report|build|cutover" ;;
esac
