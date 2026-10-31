#!/usr/bin/env bash
set -euo pipefail

src="$TMPDIR/migration-fixture/source"
dst="$TMPDIR/migration-fixture/destination"
require_acl="${REQUIRE_ACL:-0}"
require_full_disk="${REQUIRE_FULL_DISK:-0}"
require_root="${REQUIRE_ROOT:-0}"
acl_supported=0
xattr_supported=0
full_disk_mounted=0

cleanup() {
  if [ "$full_disk_mounted" = 1 ]; then
    umount "$TMPDIR/migration-fixture/full" 2>/dev/null || true
  fi
}
trap cleanup EXIT

rm -rf "$TMPDIR/migration-fixture"
mkdir -p "$src"/{dir,Works/Bangunindo/BLIV,.herdr,.config,Personal,.clawdbot,clickhouse-local/data}
mkdir -p "$dst"


printf 'alpha\n' > "$src/alpha.txt"
printf 'beta\n' > "$src/dir/beta.txt"
ln "$src/alpha.txt" "$src/dir/alpha-hardlink.txt"
ln -s ../alpha.txt "$src/dir/alpha-symlink"
touch -d '2020-01-02 03:04:05' "$src/alpha.txt" "$src/dir/beta.txt"



if setfacl -m "u:$(id -u):r--" "$src/dir/beta.txt" 2>/dev/null; then
  acl_supported=1
elif [ "$require_acl" = 1 ]; then
  echo "migration fixture: ACLs are required but unsupported" >&2
  exit 1
fi

if setfattr -n user.test -v fixture-value "$src/dir/beta.txt" 2>/dev/null; then
  xattr_supported=1
elif [ "$require_acl" = 1 ]; then
  echo "migration fixture: xattrs are required but unsupported" >&2
  exit 1
fi




printf 'workspace file\n' > "$src/Works/Bangunindo/BLIV/root-owned-policy.txt"
printf 'herdr file\n' > "$src/.herdr/root-owned-policy.txt"
printf 'personal user file\n' > "$src/Personal/user-owned.txt"
printf 'personal root file\n' > "$src/Personal/root-owned.txt"


printf 'do-not-copy\n' > "$src/.config/secret.env"
printf 'excluded personal\n' > "$src/.config/personal.txt"
printf 'clawdbot state\n' > "$src/.clawdbot/state.json"
printf 'clickhouse state\n' > "$src/clickhouse-local/data/part.bin"


sqlite3 "$src/db.sqlite" 'CREATE TABLE t(x); INSERT INTO t VALUES (1);'

cat > "$TMPDIR/migration-fixture/exclude" <<'EOF'
/.config/
/.clawdbot/
/clickhouse-local/
EOF
if [ "$require_root" = 1 ]; then
  printf '/Personal/root-owned.txt\n' >> "$TMPDIR/migration-fixture/exclude"
fi

rsync -aHAX --numeric-ids \
  --exclude-from="$TMPDIR/migration-fixture/exclude" \
  "$src/" "$dst/"

cmp "$src/alpha.txt" "$dst/alpha.txt"
cmp "$src/dir/beta.txt" "$dst/dir/beta.txt"

[ "$(stat -c '%i' "$dst/alpha.txt")" = "$(stat -c '%i' "$dst/dir/alpha-hardlink.txt")" ]
[ "$(stat -c '%h' "$dst/alpha.txt")" -eq 2 ]
[ "$(readlink "$dst/dir/alpha-symlink")" = "../alpha.txt" ]

[ "$(stat -c '%y' "$dst/alpha.txt")" = "$(stat -c '%y' "$src/alpha.txt")" ]
[ "$(stat -c '%y' "$dst/dir/beta.txt")" = "$(stat -c '%y' "$src/dir/beta.txt")" ]

[ "$(stat -c '%u:%g' "$dst/alpha.txt")" = "$(id -u):$(id -g)" ]
[ -e "$dst/Personal/user-owned.txt" ]

if [ "$require_root" = 1 ]; then

  find "$dst/.herdr" "$dst/Works/Bangunindo/BLIV" -xdev -uid 0 -exec chown 1000:1000 {} +
  [ "$(stat -c '%u:%g' "$dst/Works/Bangunindo/BLIV/root-owned-policy.txt")" = "1000:1000" ]
  [ "$(stat -c '%u:%g' "$dst/.herdr/root-owned-policy.txt")" = "1000:1000" ]
  [ ! -e "$dst/Personal/root-owned.txt" ]
  [ -z "$(find "$dst/.herdr" "$dst/Works/Bangunindo/BLIV" -xdev -uid 0 -print -quit)" ]
else
  [ "$(stat -c '%u:%g' "$dst/Works/Bangunindo/BLIV/root-owned-policy.txt")" = "$(id -u):$(id -g)" ]
  [ "$(stat -c '%u:%g' "$dst/.herdr/root-owned-policy.txt")" = "$(id -u):$(id -g)" ]
  [ -e "$dst/Personal/root-owned.txt" ]
fi

[ ! -e "$dst/.config" ]
[ ! -e "$dst/.config/secret.env" ]
[ ! -e "$dst/.config/personal.txt" ]
[ ! -e "$dst/.clawdbot" ]
[ ! -e "$dst/clickhouse-local" ]

if [ "$acl_supported" = 1 ]; then
  diff -u \
    <(getfacl -cp "$src/dir/beta.txt" | sed "s#$src##g") \
    <(getfacl -cp "$dst/dir/beta.txt" | sed "s#$dst##g")
fi

if [ "$xattr_supported" = 1 ]; then
  diff -u \
    <(getfattr -d -m - "$src/dir/beta.txt" | grep -v '^#' || true) \
    <(getfattr -d -m - "$dst/dir/beta.txt" | grep -v '^#' || true)
fi

[ "$(sqlite3 "$dst/db.sqlite" 'PRAGMA integrity_check;')" = "ok" ]



cp "$dst/db.sqlite" "$dst/corrupt.sqlite"
printf 'this is not a sqlite database' \
  | dd of="$dst/corrupt.sqlite" bs=1 conv=notrunc status=none
if sqlite3 "$dst/corrupt.sqlite" 'PRAGMA integrity_check;' >"$TMPDIR/migration-fixture/corrupt-check.txt" 2>&1; then
  if grep -qx 'ok' "$TMPDIR/migration-fixture/corrupt-check.txt"; then
    echo "migration fixture: corrupted SQLite copy was accepted" >&2
    exit 1
  fi
fi
rm -f "$dst/corrupt.sqlite"



if [ "$require_full_disk" = 1 ]; then
  full="$TMPDIR/migration-fixture/full"
  mkdir -p "$full"
  mount -t tmpfs -o size=1M tmpfs "$full"
  full_disk_mounted=1
  dd if=/dev/zero of="$TMPDIR/migration-fixture/large.bin" bs=1M count=2 status=none
  if rsync -a "$TMPDIR/migration-fixture/large.bin" "$full/"; then
    echo "migration fixture: copy to a full destination unexpectedly succeeded" >&2
    exit 1
  fi
  umount "$full"
  full_disk_mounted=0
  rm -f "$TMPDIR/migration-fixture/large.bin"
fi

echo "migration fixture: pass (acl=$acl_supported xattr=$xattr_supported full_disk=$require_full_disk root=$require_root)"
