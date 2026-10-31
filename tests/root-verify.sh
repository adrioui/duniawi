#!/usr/bin/env bash







set -euo pipefail

backup=${BACKUP:-/run/media/adrioui/backup}
out=${OUT:-/var/tmp/duniawi-root-verify-$(date +%Y%m%dT%H%M%S)}

if [ "$(id -u)" -ne 0 ]; then
  echo "root-verify: must run as root" >&2
  exit 1
fi
if ! findmnt -no OPTIONS "$backup" | grep -qE '(^|,)ro(,|$)'; then
  echo "root-verify: backup is not mounted read-only" >&2
  exit 1
fi

mkdir -p "$out"
echo "root-verify: reports in $out"

set +e
{
  echo "# date $(date -Is)"
  echo "# command: sha256sum -c source.sha256"
  cd "$backup/home"
  sha256sum --quiet -c "$backup/evidence-20261030/gate3/source.sha256"
} >"$out/full-home-hash.log" 2>&1
full_rc=$?
echo "root-verify: full home hash exit=$full_rc"

{
  echo "# date $(date -Is)"
  grep -aE '  \./(\.herdr|Works/Bangunindo/BLIV)/' \
    "$backup/evidence-20261030/gate3/source.sha256" >"$out/required.sha256"
  echo "# required entries $(wc -l < "$out/required.sha256")"
  cd "$backup/home"
  sha256sum --quiet -c "$out/required.sha256"
} >"$out/required-hash.log" 2>&1
required_rc=$?
echo "root-verify: required-tree hash exit=$required_rc"
set -e

{
  echo "# date $(date -Is)"
  cd "$backup/home"
  printf "root_entries="; find . -xdev -uid 0 -print | wc -l
  printf "root_files="; find . -xdev -uid 0 -type f -print | wc -l
  printf "root_dirs="; find . -xdev -uid 0 -type d -print | wc -l
  printf "required_root_files="
  find .herdr Works/Bangunindo/BLIV -xdev -uid 0 -type f -print | wc -l
  echo "--- distinct uid:gid ---"
  find . -xdev -printf '%U:%G\n' | LC_ALL=C sort -u
} >"$out/ownership.log" 2>&1

{
  echo "# date $(date -Is)"
  cd "$backup/home"
  find . -xdev -printf '%U:%G %y %p\n' \
    | awk '$1 != "1000:1000" && $1 != "0:0"' \
    | grep -vE '(/node_modules/|^[^ ]+ [^ ]+ \./\.local/share/containers/|^[^ ]+ [^ ]+ \./Personal/financial/actual/\.yarn/cache/|^[^ ]+ [^ ]+ \./clickhouse-local/|^[^ ]+ [^ ]+ \./Works/)' \
    | sort
} >"$out/non-1000-ownership.txt" 2>&1

{
  echo "# date $(date -Is)"
  findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS "$backup"
  echo "# this script issued no writes to the backup"
} >"$out/mount-after.log" 2>&1

echo "root-verify: complete (full=$full_rc required=$required_rc)"
echo "root-verify: inspect $out"
