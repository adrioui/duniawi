#!/usr/bin/env bash



set -uo pipefail



repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:-"$repo_root/evidence/raw"}
mkdir -p "$out"

write_header() {
  local name=$1
  shift
  local file="$out/$name.log"
  {
    printf '# command:'
    printf ' %q' "$@"
    printf '\n# started: %s\n' "$(date -Is)"
  } >"$file"
  "$@" >>"$file" 2>&1
  local rc=$?
  printf '# exit: %s\n# finished: %s\n' "$rc" "$(date -Is)" >>"$file"
  return "$rc"
}

write_shell() {
  local name=$1
  local command=$2
  local file="$out/$name.log"
  {
    printf '# shell: %s\n# started: %s\n' "$command" "$(date -Is)"
  } >"$file"
  bash -c "$command" >>"$file" 2>&1
  local rc=$?
  printf '# exit: %s\n# finished: %s\n' "$rc" "$(date -Is)" >>"$file"
  return "$rc"
}

write_header 00-date date -Is
write_header 01-git-status git status --porcelain=v2 --branch
write_header 02-git-head git rev-parse HEAD
write_header 03-git-remote git remote -v
write_header 04-git-log git log -1 --format=fuller
write_header 05-lock-sha256 sha256sum flake.lock
write_header 06-nix-version nix --version
write_shell 07-flake-metadata 'nix flake metadata --json'
write_shell 08-nixos-values '
  printf "hostPlatform="; nix eval --raw .#nixosConfigurations.t14.config.nixpkgs.hostPlatform.system; echo
  printf "stateVersion="; nix eval --json .#nixosConfigurations.t14.config.system.stateVersion
  printf "hostName="; nix eval --raw .#nixosConfigurations.t14.config.networking.hostName; echo
  printf "toplevel="; nix eval --raw .#nixosConfigurations.t14.config.system.build.toplevel.drvPath; echo
  printf "darwinPlatform="; nix eval --raw .#darwinConfigurations.adri.config.nixpkgs.hostPlatform.system; echo
  printf "darwinStateVersion="; nix eval --json .#darwinConfigurations.adri.config.system.stateVersion
'
write_shell 09-active-system '
  readlink -f /run/current-system
  readlink -f /run/booted-system
  nix-env -p /nix/var/nix/profiles/system --list-generations | tail -5
  bootctl status 2>&1 || true
'
write_header 10-findmnt-backup findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /run/media/adrioui/backup
write_header 11-lsblk lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINTS
write_shell 12-df '
  df -h / /boot /run/media/adrioui/backup
  df -i / /boot /run/media/adrioui/backup
'
write_shell 13-smart '
  nix shell github:NixOS/nixpkgs/6f06d204d8f2d8761d9da78778745974a3216381#smartmontools -c sh -c "
    smartctl -H /dev/sda 2>&1 || true
    smartctl -A /dev/sda 2>&1 || true
  "
'
write_shell 14-backup-identity '
  stat -c "backup mount: %A %U:%G %n" /run/media/adrioui/backup
  stat -c "home: %A %U:%G %s %n" /run/media/adrioui/backup/home
  findmnt -no SOURCE,UUID,FSTYPE,OPTIONS /run/media/adrioui/backup
'




write_shell 15-home-metadata-digest '
  cd /run/media/adrioui/backup/home || exit 1
  stream=/tmp/duniawi-home-metadata-$(date +%Y%m%dT%H%M%S).txt
  find . -xdev -printf "%y %m %U:%G %s %i %n %p -> %l\n" 2>/tmp/duniawi-home-metadata.err \
    | LC_ALL=C sort > "$stream"
  echo "stream=$stream"
  wc -l < "$stream"
  sha256sum "$stream"
  echo "--- find stderr ---"
  sed -n "1,120p" /tmp/duniawi-home-metadata.err
'

write_shell 16-ownership-counts '
  cd /run/media/adrioui/backup/home || exit 1
  printf "root_entries="; find . -xdev -uid 0 -print 2>/dev/null | wc -l
  printf "root_files="; find . -xdev -uid 0 -type f -print 2>/dev/null | wc -l
  printf "root_dirs="; find . -xdev -uid 0 -type d -print 2>/dev/null | wc -l
  printf "sqlite="; find . -xdev -type f \( -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.db" \) -print 2>/dev/null | wc -l
  printf "secret_paths="; find . -xdev -type f \( -name "*.env" -o -name "*.key" -o -name "*.pem" -o -name "id_*" -o -name "keys.txt" \) -print 2>/dev/null | wc -l


  find . -xdev -printf "%U:%G\n" 2>/dev/null | LC_ALL=C sort -u > /tmp/duniawi-uid-gid.txt
  echo "--- distinct uid:gid ---"
  cat /tmp/duniawi-uid-gid.txt
  echo "--- unmapped users ---"
  cut -d: -f1 /tmp/duniawi-uid-gid.txt | while read -r uid; do
    getent passwd "$uid" >/dev/null || echo "$uid"
  done
  echo "--- unmapped groups ---"
  cut -d: -f2 /tmp/duniawi-uid-gid.txt | while read -r gid; do
    getent group "$gid" >/dev/null || echo "$gid"
  done


  printf "dangling="
  find . -xdev -type l -print0 2>/dev/null \
    | while IFS= read -r -d "" p; do [ -e "$p" ] || printf "%s\n" "$p"; done \
    | wc -l
'

write_shell 17-acl-xattr-capability-digest '
  cd /run/media/adrioui/backup/home || exit 1
  set +eu
  acl_file=/tmp/duniawi-acl-$(date +%Y%m%dT%H%M%S).txt
  xattr_file=/tmp/duniawi-xattr-$(date +%Y%m%dT%H%M%S).txt
  cap_file=/tmp/duniawi-cap-$(date +%Y%m%dT%H%M%S).txt
  getfacl -R -p . > "$acl_file" 2>/tmp/duniawi-acl.err
  sha256sum "$acl_file"
  echo "acl_lines=$(wc -l < "$acl_file")"
  getfattr -R -d -m - . > "$xattr_file" 2>/tmp/duniawi-xattr.err
  sha256sum "$xattr_file"
  echo "xattr_lines=$(wc -l < "$xattr_file")"
  getcap -r . 2>/tmp/duniawi-cap.err | LC_ALL=C sort > "$cap_file"
  sha256sum "$cap_file"
  echo "cap_lines=$(wc -l < "$cap_file")"
  echo "--- stderr sizes ---"
  wc -l /tmp/duniawi-acl.err /tmp/duniawi-xattr.err /tmp/duniawi-cap.err 2>/dev/null || true
'
write_shell 18-listener-and-failed '
  ss -ltnp 2>&1 || true
  systemctl --failed --no-legend 2>&1 || true
  systemctl --user --failed --no-legend 2>&1 || true
'

printf 'Phase 0 evidence written to %s\n' "$out"
