machine.start()
machine.wait_for_unit("multi-user.target")
machine.succeed("git config --global --add safe.directory '*'")

report = []


def note(tag, out):
    report.append(f"### {tag}\n{out}")
    print(f"### {tag}\n{out}", flush=True)






machine.succeed(r"""
set +e +o pipefail
S=/srv/fixture/var/home/adrifadilah
rm -rf /srv/fixture
mkdir -p $S/Works/Bangunindo/BLIV/repos \
         $S/.herdr/worktrees/btj--bliv-demo \
         $S/Personal/app/node_modules/pkg \
         $S/Learns/proj/.dlt \
         $S/.aws \
         $S/.claude/projects/p
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=a@b GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=a@b
git init -q -b main $S/Works/Bangunindo/BLIV/repos/demo
( cd $S/Works/Bangunindo/BLIV/repos/demo \
  && echo readme > README.md && mkdir -p botocore \
  && echo 'def load(): pass' > botocore/credentials.py \
  && git add -A && git commit -qm init \
  && git worktree add -q $S/.herdr/worktrees/btj--bliv-demo/wt1 -b wt1 \
  && echo work > $S/.herdr/worktrees/btj--bliv-demo/wt1/w.txt )
echo '[default]' > $S/Works/Bangunindo/BLIV/license_key.txt
echo '[default]' > $S/.aws/credentials
echo 'module.exports=1' > $S/Personal/app/node_modules/pkg/index.js
echo '{"event":"x"}' > $S/.claude/projects/p/transcript.jsonl
echo state > $S/Learns/proj/.dlt/state.txt
echo notes > $S/Personal/notes.md
ln $S/Personal/notes.md $S/Personal/notes.hard
setfattr -n user.provenance -v old-home $S/Personal/notes.md
setfacl -m g:adrioui:r-- $S/Personal/notes.md
# chown clears setuid and capabilities, so create everything, chown, then set bits
cp /run/current-system/sw/bin/true $S/Personal/app/tool
truncate -s 32M $S/Personal/app/sparse.img
printf x | dd of=$S/Personal/app/sparse.img bs=1 seek=16777216 conv=notrunc status=none
# A WAL database whose committed rows live only in the -wal file.
python3 - <<'PY'
import sqlite3, os
p = "/srv/fixture/var/home/adrifadilah/Personal/app/data.db"
c = sqlite3.connect(p)
c.execute("PRAGMA journal_mode=WAL")
c.execute("PRAGMA wal_autocheckpoint=0")
c.execute("create table t(i integer primary key, v text)")
c.executemany("insert into t(v) values(?)", [(f"r{i}",) for i in range(50)])
c.commit()
os._exit(9)
PY
chown -R 1000:1000 $S
chmod 4755 $S/Personal/app/tool
setcap cap_net_bind_service+ep $S/Personal/app/tool
chown 0:0 $S/.herdr/worktrees/btj--bliv-demo/wt1/w.txt
printf '%s\n' Works/Bangunindo/BLIV Personal Learns .herdr/worktrees/btj--bliv-demo .claude/projects > /tmp/inc.txt
true
""")

note("F0 fixture", machine.succeed(r"""
S=/srv/fixture/var/home/adrifadilah
find $S -type f -o -type l | sed "s|$S/||" | sort
true
"""))


note("F1 restore-home.sh", machine.succeed(r"""
set +e +o pipefail
export SRC=/srv/fixture/var/home/adrifadilah
export STAGE=/home/adrioui.restore
export EVID=/tmp/evid
export INCLUDE_FILE=/tmp/inc.txt
export MIN_FREE_GB=0
export ALLOW_WRITABLE_SOURCE=1
rm -rf $EVID $STAGE
echo "findmnt: $(command -v findmnt || echo MISSING)"
# The guard must refuse a writable source when the escape hatch is absent.
env -u ALLOW_WRITABLE_SOURCE SRC=/srv/fixture/var/home/adrifadilah \
    STAGE=/tmp/never-stage EVID=/tmp/evid-guard INCLUDE_FILE=/tmp/inc.txt \
    MIN_FREE_GB=0 bash /etc/restore-home.sh >/tmp/guard.log 2>&1
echo "guard rc=$? (expect non-zero)"
grep -q 'not mounted read-only' /tmp/guard.log && echo "guard message ok"
test ! -e /tmp/never-stage && echo "guard left no stage"
bash /etc/restore-home.sh
echo "restore rc=$?"
true
"""))

note("F2 what the policy did", machine.succeed(r"""
set +e
D=/home/adrioui.restore
echo "kept  botocore/credentials.py: $(test -f $D/Works/Bangunindo/BLIV/repos/demo/botocore/credentials.py && echo yes || echo NO)"
echo "kept  transcript.jsonl:        $(test -f $D/.claude/projects/p/transcript.jsonl && echo yes || echo NO)"
echo "excluded .aws/credentials:     $(test -e $D/.aws/credentials && echo PRESENT || echo absent)"
echo "excluded license_key.txt:      $(test -e $D/Works/Bangunindo/BLIV/license_key.txt && echo PRESENT || echo absent)"
echo "excluded node_modules:         $(test -e $D/Personal/app/node_modules && echo PRESENT || echo absent)"
echo "excluded .dlt:                 $(test -e $D/Learns/proj/.dlt && echo PRESENT || echo absent)"
echo "root-owned file mapped:        $(stat -c '%u:%g' $D/.herdr/worktrees/btj--bliv-demo/wt1/w.txt)"
echo "home dir:                      $(stat -c '%u:%g %a' $D)"
echo "metadata:                      $(stat -c '%a %h' $D/Personal/notes.md)"
echo "xattr:                         $(getfattr -d $D/Personal/notes.md 2>/dev/null | grep -v '^#' | head -1)"
echo "acl:                           $(getfacl -c $D/Personal/notes.md 2>/dev/null | grep adrioui)"
echo "setuid:                        $(stat -c '%a' $D/Personal/app/tool)"
echo "cap:                           $(getcap $D/Personal/app/tool)"
echo "sparse blocks:                 $(stat -c '%b' $D/Personal/app/sparse.img)"
echo "db + wal:                      $(ls $D/Personal/app/data.db* 2>/dev/null | wc -l)"
echo "nogroup entries:               $(find $D -xdev -nogroup | wc -l)"
true
"""))

note("F3 git pointer after the move", machine.succeed(r"""
set +e
D=/home/adrioui.restore
cat $D/.herdr/worktrees/btj--bliv-demo/wt1/.git
cat $D/Works/Bangunindo/BLIV/repos/demo/.git/worktrees/wt1/gitdir
git -c safe.directory='*' -C $D/Works/Bangunindo/BLIV/repos/demo worktree list --porcelain | grep '^worktree'
true
"""))


note("F4 verify-home.sh", machine.succeed(r"""
set +e +o pipefail
export SRC=/srv/fixture/var/home/adrifadilah
export STAGE=/home/adrioui.restore
export EVID=/tmp/evid
export INCLUDE_FILE=/tmp/inc.txt
export MIN_FREE_GB=0
export OLD_HOME=/srv/fixture/var/home/adrifadilah
bash /etc/verify-home.sh --checksum --deep
rc=$?
echo "$rc" > /tmp/evid/verify.rc
echo "verify rc=$rc"
true
"""))

note("F5 verify verdict", machine.succeed(r"""
set +e
echo "--- verify.tsv:"; cat /tmp/evid/verify.tsv
echo "--- unexplained exclusions:"; cat /tmp/evid/not-explained.txt 2>/dev/null || echo "(none)"
echo "--- drift lines: $(wc -l < /tmp/evid/drift.txt)"; head -10 /tmp/evid/drift.txt
true
"""))








note("F6 verify under en_US.UTF-8", machine.succeed(r"""
set +e +o pipefail
echo "locales: $(locale -a | grep -i '^en_US' | tr '\n' ' ')"
rm -rf /tmp/evid-utf8; mkdir -p /tmp/evid-utf8
cp /tmp/evid/rsync-filter.rules /tmp/evid-utf8/
export SRC=/srv/fixture/var/home/adrifadilah
export STAGE=/home/adrioui.restore
export EVID=/tmp/evid-utf8
export INCLUDE_FILE=/tmp/inc.txt
export OLD_HOME=/srv/fixture/var/home/adrifadilah
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
bash /etc/verify-home.sh --checksum --deep
rc=$?
echo "$rc" > /tmp/evid-utf8/verify.rc
echo "utf8 verify rc=$rc"
cat /tmp/evid-utf8/verify.tsv
true
"""))






note("F7 same-size, same-mtime corruption must fail", machine.succeed(r"""
set +e +o pipefail
F=/home/adrioui.restore/.claude/projects/p/transcript.jsonl
cp -a "$F" /tmp/transcript.bak
before=$(stat -c '%s %Y' "$F")
printf '%s\n' '{"EVENT":"x"}' > "$F"
touch -r /tmp/transcript.bak "$F"
after=$(stat -c '%s %Y' "$F")
echo "size+mtime before=$before after=$after (deliberately identical)"
rm -rf /tmp/evid-fault; mkdir -p /tmp/evid-fault
cp /tmp/evid/rsync-filter.rules /tmp/evid-fault/
export SRC=/srv/fixture/var/home/adrifadilah
export STAGE=/home/adrioui.restore
export EVID=/tmp/evid-fault
export INCLUDE_FILE=/tmp/inc.txt
export OLD_HOME=/srv/fixture/var/home/adrifadilah
bash /etc/verify-home.sh --checksum --deep; rc=$?
echo "$rc" > /tmp/evid-fault/verify.rc
echo "fault rc=$rc"
grep -E 'drift-lines|verify-complete' /tmp/evid-fault/verify.tsv
cp -a /tmp/transcript.bak "$F"
rm -rf /tmp/evid-after; mkdir -p /tmp/evid-after
cp /tmp/evid/rsync-filter.rules /tmp/evid-after/
EVID=/tmp/evid-after bash /etc/verify-home.sh --checksum --deep; rc2=$?
echo "$rc2" > /tmp/evid-after/verify.rc
echo "after-restore rc=$rc2"
grep -E 'drift-lines|verify-complete' /tmp/evid-after/verify.tsv
true
"""))





machine.succeed("locale -a | grep -qi '^en_US'")
machine.succeed("command -v findmnt")
machine.succeed("grep -q 'not mounted read-only' /tmp/guard.log")
machine.succeed("test ! -e /tmp/never-stage")
machine.succeed("! grep -q FAIL /tmp/evid/checks.tsv")

oracles = (
    "drift-lines",
    "unexplained-exclusions",
    "secret-paths-present",
    "worktree-pointers",
    "git-fsck-regression",
    "sqlite-integrity",
)
for evid in ("/tmp/evid", "/tmp/evid-utf8"):
    machine.succeed(f"test -s {evid}/verify.rc && grep -qx 0 {evid}/verify.rc")
    for key in oracles:
        machine.succeed(
            f"""awk -F'\\t' -v k={key} '$1==k && $2=="PASS" {{f=1}} END {{exit !f}}' {evid}/verify.tsv"""
        )


    machine.succeed(
        f"""awk -F'\\t' '$1=="verify-complete" && $2=="PASS" && $3>={len(oracles)} {{f=1}} END {{exit !f}}' {evid}/verify.tsv"""
    )



machine.succeed("! grep -qx 0 /tmp/evid-fault/verify.rc")
machine.succeed(
    """awk -F'\\t' '$1=="drift-lines" && $2=="FAIL" {f=1} END {exit !f}' /tmp/evid-fault/verify.tsv"""
)
machine.succeed(
    """awk -F'\\t' '$1=="verify-complete" && $2=="FAIL" {f=1} END {exit !f}' /tmp/evid-fault/verify.tsv"""
)
machine.succeed("grep -qx 0 /tmp/evid-after/verify.rc")
machine.succeed(
    f"""awk -F'\\t' '$1=="verify-complete" && $2=="PASS" && $3>={len(oracles)} {{f=1}} END {{exit !f}}' /tmp/evid-after/verify.tsv"""
)
machine.succeed("test -f /home/adrioui.restore/Works/Bangunindo/BLIV/repos/demo/botocore/credentials.py")
machine.succeed("test ! -e /home/adrioui.restore/.aws/credentials")
machine.succeed("test ! -e /home/adrioui.restore/Works/Bangunindo/BLIV/license_key.txt")
machine.succeed("test \"$(stat -c %u:%g /home/adrioui.restore/Personal/notes.md)\" = 1000:1000")
machine.succeed("test \"$(stat -c %i /home/adrioui.restore/Personal/notes.md)\" = \"$(stat -c %i /home/adrioui.restore/Personal/notes.hard)\"")
machine.succeed("test \"$(stat -c %a /home/adrioui.restore/Personal/app/tool)\" = 4755")
machine.succeed("getcap /home/adrioui.restore/Personal/app/tool | grep -q cap_net_bind_service")
machine.succeed("getfattr -d /home/adrioui.restore/Personal/notes.md | grep -q user.provenance")
machine.succeed("getfacl -c /home/adrioui.restore/Personal/notes.md | grep -q 'group:adrioui:r--'")
machine.succeed("test \"$(stat -c %h /home/adrioui.restore/Personal/notes.md)\" = 2")

print("\n\n===== REHEARSAL =====\n" + "\n".join(report) + "\n===== END =====")
