#!/usr/bin/env bash




























set -Eeuo pipefail
export LC_ALL=C


export PATH="$PATH:/run/current-system/sw/bin:/run/current-system/sw/sbin"

PROVIDER_MODEL=${PROVIDER_MODEL:-deepseek/deepseek-v4.1-flash}
TARGET_USER=${TARGET_USER:-adrioui}
SRC=${NIX_SRC:-/etc/nixos}

EVID=
EXPECT_REV=
THREAD=${AMP_THREAD_ID:-}
STRICT=0
MENU_SRC=
RESCUE_SRC=
N=

usage() {
    cat <<'EOF'
Usage: device-verify [options]

  --evidence DIR        evidence directory (default: root
                        /var/lib/duniawi/evidence/<stamp>; user
                        ${XDG_STATE_HOME:-$HOME/.local/state}/duniawi/evidence/<stamp>)
  --expect-revision SHA require the built-in revision to equal SHA
  --thread THREAD       Amp thread for check-access (default AMP_THREAD_ID)
  --menu-evidence FILE  copy the N-1 menu transcript into the evidence directory
  --rescue-evidence FILE copy the USB rescue transcript into the evidence directory
  --strict              a required NotRun exits 2
  -h, --help            this help

Evidence rows are Pass/Fail/NotRun/Attested. Attested means the transcript is
bound to a real boot or to the pinned rescue ISO; it never means "probably fine".
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        --evidence)
            EVID=${2:?--evidence needs a directory}
            shift 2
            ;;
        --expect-revision)
            EXPECT_REV=${2:?--expect-revision needs a SHA}
            shift 2
            ;;
        --thread)
            THREAD=${2:?--thread needs a thread}
            shift 2
            ;;
        --menu-evidence)
            MENU_SRC=${2:?--menu-evidence needs a file}
            shift 2
            ;;
        --rescue-evidence)
            RESCUE_SRC=${2:?--rescue-evidence needs a file}
            shift 2
            ;;
        --strict)
            STRICT=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "unknown option $1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    TARGET_UID=$(id -u "$TARGET_USER")
    [ -n "$TARGET_HOME" ] || {
        echo "FATAL: no passwd entry for $TARGET_USER" >&2
        exit 1
    }
    command -v runuser >/dev/null 2>&1 || {
        echo "FATAL: runuser is required when running as root" >&2
        exit 1
    }
else
    TARGET_USER=$(id -un)
    TARGET_HOME=$HOME
    TARGET_UID=$(id -u)
fi

STAMP=${STAMP:-$(date +%Y%m%dT%H%M%S)}
if [ "$(id -u)" -eq 0 ]; then
    EVID=${EVID:-/var/lib/duniawi/evidence/$STAMP}
    install -d -m 0750 -o root -g root "$EVID"
else
    EVID=${EVID:-${XDG_STATE_HOME:-$TARGET_HOME/.local/state}/duniawi/evidence/$STAMP}
    install -d -m 0700 "$EVID"
fi
EVID=$(readlink -f "$EVID")

TSV=$EVID/verify.tsv
LOG=$EVID/gate.log
[ ! -e "$TSV" ] || {
    echo "FATAL: evidence already exists: $TSV" >&2
    exit 64
}
: >"$TSV"
: >"$LOG"
exec > >(tee -a "$LOG") 2>&1

checks=0
pass=0
fail=0
notrun=0
attested=0
required_notrun=0

die() {
    printf 'FATAL: %s\n' "$*" >&2
    exit 1
}
log() { printf '%s %s\n' "$(date -Is)" "$*"; }
clean() { printf '%s' "$1" | tr '\n\t' '  ' | cut -c1-300; }

record() {
    local layer=$1 check=$2 expected=$3 actual=$4 result=$5 evidence=$6
    checks=$((checks + 1))
    case $result in
        Pass) pass=$((pass + 1)) ;;
        Fail) fail=$((fail + 1)) ;;
        NotRun) notrun=$((notrun + 1)) ;;
        Attested) attested=$((attested + 1)) ;;
        *) die "unknown result: $result" ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$layer" "$check" "$(clean "$expected")" "$(clean "$actual")" \
        "$result" "$(clean "$evidence")" >>"$TSV"
    log "$result $layer/$check expected=[$(clean "$expected")] actual=[$(clean "$actual")]"
}

skip() {
    if [ "$6" -eq 1 ]; then
        required_notrun=$((required_notrun + 1))
    fi
    record "$1" "$2" "$3" "$4" NotRun "$5"
}

expect_eq() {
    if [ "$3" = "$4" ]; then
        record "$1" "$2" "$3" "$4" Pass "$5"
    else
        record "$1" "$2" "$3" "$4" Fail "$5"
    fi
}

copy_transcript() {
    local src=$1 dest=$2 src_real dest_real
    [ -n "$src" ] || return 0
    [ -f "$src" ] || return 0
    src_real=$(readlink -f "$src")
    dest_real=$(readlink -f "$dest" 2>/dev/null || true)
    [ "$src_real" = "$dest_real" ] && return 0
    if [ "$(id -u)" -eq 0 ]; then
        install -m 0640 -o root -g root "$src" "$dest"
    else
        install -m 0600 "$src" "$dest"
    fi
}

run_as_user() {
    local cd_home="cd \"\$HOME\" && exec \"\$@\""
    if [ "$(id -u)" -eq 0 ]; then



        runuser -u "$TARGET_USER" -- env \
            HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
            XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
            XDG_DATA_DIRS="/etc/profiles/per-user/$TARGET_USER/share:/run/current-system/sw/share:/usr/share" \
            XDG_DATA_HOME="$TARGET_HOME/.local/share" \
            XDG_CONFIG_HOME="$TARGET_HOME/.config" \
            XDG_CACHE_HOME="$TARGET_HOME/.cache" \
            PATH="$TARGET_HOME/.nix-profile/bin:/etc/profiles/per-user/$TARGET_USER/bin:/run/current-system/sw/bin" \
            /run/current-system/sw/bin/bash -c "$cd_home" _ "$@"
    else
        (cd "$TARGET_HOME" && "$@")
    fi
}

hm_generation() {
    systemctl cat home-manager-adrioui.service 2>/dev/null |
        grep -o '/nix/store/[^ ]*-home-manager-generation' |
        head -n 1 || true
}

JQ=$(command -v jq 2>/dev/null || true)
if [ -z "$JQ" ] && [ "$(id -u)" -eq 0 ]; then
    JQ=$(run_as_user bash -c 'command -v jq' 2>/dev/null || true)
fi

copy_transcript "$MENU_SRC" "$EVID/menu-rehearsal.txt"
copy_transcript "$RESCUE_SRC" "$EVID/rescue-media.txt"

preflight() {
    local gen home_files rel target got foreign=0 foreign_list=""
    log "=== preflight: declared paths and inputs ==="

    if [ -n "$THREAD" ]; then
        record L5 thread "provided" "$THREAD" Pass "--thread/AMP_THREAD_ID"
    else
        skip L5 thread "provided" "missing --thread/AMP_THREAD_ID" "$EVID" 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        log "user preview: root-only L1/journal/evidence checks will be NotRun"
    fi

    gen=$(hm_generation)
    if [ -z "$gen" ] || [ ! -d "$gen/home-files" ]; then
        record declared hm-collisions "0 foreign paths" "no home-manager generation" Fail "systemctl cat home-manager-adrioui"
        return
    fi
    home_files=$(readlink -f "$gen/home-files")
    while IFS= read -r rel; do
        target="$TARGET_HOME/$rel"
        if [ -e "$target" ] || [ -L "$target" ]; then
            got=$(readlink "$target" 2>/dev/null || true)
            if [ "$got" != "$home_files/$rel" ]; then
                foreign=$((foreign + 1))
                foreign_list="$foreign_list $rel"
            fi
        fi
    done < <(
        cd "$home_files" &&
            find . -mindepth 1 \( -type f -o -type l \) -printf '%P\n' | LC_ALL=C sort
    )
    if [ "$foreign" -eq 0 ]; then
        record declared hm-collisions "0 foreign paths" "0" Pass "$home_files"
    else
        record declared hm-collisions "0 foreign paths" "$foreign:$foreign_list" Fail "$home_files"
    fi
}

l1_boot() {
    local failed graphical entries esp k id nlink top root linux f fails=0 detail="" sel def
    local profile_link=/nix/var/nix/profiles/system
    local gen link_target cur booted
    log "=== L1 boot ==="

    link_target=$(readlink "$profile_link" 2>/dev/null || true)
    gen=$(printf '%s' "$link_target" | sed -n 's/^system-\([0-9][0-9]*\)-link$/\1/p')
    cur=$(readlink -f /run/current-system 2>/dev/null || true)
    booted=$(readlink -f /run/booted-system 2>/dev/null || true)
    if [ -n "$gen" ] && [ "$(readlink -f "$profile_link" 2>/dev/null || true)" = "$cur" ] && [ "$cur" = "$booted" ]; then
        record L1 booted-generation "profile = current = booted = N" "N=$gen current=$cur booted=$booted" Pass "$profile_link"
        N=$gen
    else
        record L1 booted-generation "profile = current = booted = N" "profile=$(readlink -f "$profile_link" 2>/dev/null || true) current=$cur booted=$booted" Fail "$profile_link"
        N=
    fi

    failed=$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l)
    expect_eq L1 failed-units 0 "$failed" "systemctl --failed"

    graphical=$(systemctl is-active graphical.target 2>/dev/null || true)
    expect_eq L1 graphical-target active "$graphical" "systemctl is-active graphical.target"

    if [ "$(id -u)" -ne 0 ]; then
        skip L1 loader-entries "N, N-1, N-2 entries bound and present" "bootctl list requires root" "$EVID" 1
        skip L1 loader-selected "nixos-generation-N.conf" "bootctl list requires root" "$EVID" 1
        skip L1 loader-default "nixos-generation-N.conf" "bootctl list requires root" "$EVID" 1
        return
    fi

    entries=$(bootctl list --json=short 2>/dev/null || true)
    [ -n "$entries" ] || entries='[]'
    esp=$(bootctl --print-esp-path 2>/dev/null || echo /boot)

    if [ -z "$N" ]; then
        record L1 loader-entries "N, N-1, N-2 entries bound and present" "no N" Fail "$EVID"
    else
        for k in "$N" "$((N - 1))" "$((N - 2))"; do
            id="nixos-generation-$k.conf"
            nlink="/nix/var/nix/profiles/system-$k-link"
            if [ ! -e "$nlink" ]; then
                fails=$((fails + 1))
                detail="$detail gen$k:no-link"
                continue
            fi
            top=$(readlink -f "$nlink" 2>/dev/null || true)
            case $top in
                /nix/store/*-nixos-system-*) ;;
                *)
                    fails=$((fails + 1))
                    detail="$detail gen$k:bad-target"
                    continue
                    ;;
            esac
            if ! jq -e --arg id "$id" --arg init "$top/init" \
                'any(.[]; .id == $id and (((.options // "") | split(" ") | index("init=" + $init)) != null))' \
                <<<"$entries" >/dev/null; then
                fails=$((fails + 1))
                detail="$detail gen$k:no-init"
                continue
            fi
            root=$(jq -r --arg id "$id" '.[] | select(.id == $id) | .root // empty' <<<"$entries" | head -n1)
            [ -n "$root" ] || root=$esp
            linux=$(jq -r --arg id "$id" '.[] | select(.id == $id) | .linux // empty' <<<"$entries" | head -n1)
            if [ -n "$linux" ]; then
                f="$root/${linux#/}"
                [ -f "$f" ] || {
                    fails=$((fails + 1))
                    detail="$detail gen$k:linux-missing"
                }
            else
                fails=$((fails + 1))
                detail="$detail gen$k:no-linux"
            fi
            while IFS= read -r f; do
                [ -n "$f" ] || continue
                [ -f "$root/${f#/}" ] || {
                    fails=$((fails + 1))
                    detail="$detail gen$k:initrd-missing"
                }
            done < <(jq -r --arg id "$id" '.[] | select(.id == $id) | (.initrd // [])[]' <<<"$entries")
        done
        if [ "$fails" -eq 0 ]; then
            record L1 loader-entries "N, N-1, N-2 entries bound and present" "3 entries ok" Pass "$esp"
        else
            record L1 loader-entries "N, N-1, N-2 entries bound and present" "failures:$detail" Fail "$esp"
        fi
    fi

    if [ -n "$N" ]; then
        sel=$(jq -r '.[] | select(.isSelected == true) | .id' <<<"$entries" | head -n1)
        def=$(jq -r '.[] | select(.isDefault == true) | .id' <<<"$entries" | head -n1)
        expect_eq L1 loader-selected "nixos-generation-$N.conf" "${sel:-none}" "$esp"
        expect_eq L1 loader-default "nixos-generation-$N.conf" "${def:-none}" "$esp"
    else
        record L1 loader-selected "nixos-generation-N.conf" "no N" Fail "$esp"
        record L1 loader-default "nixos-generation-N.conf" "no N" Fail "$esp"
    fi
}

l2_session() {
    local sid name active type seat found=0 actual="no active session"
    log "=== L2 session ==="
    while IFS= read -r sid; do
        name=$(loginctl show-session "$sid" -p Name --value 2>/dev/null || true)
        [ "$name" = "$TARGET_USER" ] || continue
        active=$(loginctl show-session "$sid" -p Active --value 2>/dev/null || true)
        [ "$active" = "yes" ] || continue
        type=$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)
        seat=$(loginctl show-session "$sid" -p Seat --value 2>/dev/null || true)
        actual="$type $seat"
        if [ "$type" = "wayland" ] && [ "$seat" = "seat0" ]; then
            found=1
            break
        fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}')
    if [ "$found" -eq 1 ]; then
        record L2 session "wayland seat0" "$actual" Pass "loginctl show-session"
    else
        record L2 session "wayland seat0" "$actual" Fail "loginctl show-session"
    fi
}

l3_hardware() {
    local wifi blocked pw
    log "=== L3 hardware ==="
    wifi=$(nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null |
        awk -F: '$2=="wifi" {print $3; exit}')
    expect_eq L3 wifi connected "${wifi:-none}" "nmcli device"

    blocked=$(rfkill list 2>/dev/null | grep -c 'blocked: yes' || true)
    blocked=${blocked:-0}
    expect_eq L3 rfkill 0 "$blocked" "rfkill list"

    pw=$(run_as_user systemctl --user is-active pipewire 2>/dev/null || true)
    expect_eq L3 pipewire active "$pw" "systemctl --user is-active pipewire"

    if command -v fwupdmgr >/dev/null 2>&1; then
        if timeout 20 fwupdmgr get-devices >/dev/null 2>&1; then
            record L3 firmware "devices listed" "listed" Pass "fwupdmgr get-devices"
        else
            record L3 firmware "devices listed" "failed" Fail "fwupdmgr get-devices"
        fi
    else
        skip L3 firmware "devices listed" "no fwupdmgr" "fwupdmgr get-devices" 1
    fi

    skip L3 suspend-resume "wifi, audio and backlight after resume" "needs a body at the keyboard" "P4" 0
    skip L3 audio-playback "sink audible" "PipeWire is up; no playback test" "P4" 0
    skip L3 bluetooth-pairing "device paired" "radio is up; no device paired" "P4" 0
    skip L3 backlight "keys adjust the panel" "needs a body at the keyboard" "P4" 0
    skip L3 touchpad "pointer and gestures" "needs a body at the keyboard" "P4" 0
    skip L3 camera "frame captured" "not measured" "P4" 0
    skip L3 fingerprint "enrolled and matched" "not measured" "P4" 0
    skip L3 firmware-update "update applied" "inventory only; update needs root/polkit" "P4" 0
    skip L3 hibernation "resume from disk" "no swap device; zram only" "P4" 0
    skip L3 encryption "root at rest is encrypted" "no LUKS; separate decision" "P4" 0
    skip L3 migration "home cut over" "separate plan; P6 is the handoff" "P6" 0
}

l4_home() {
    local gen home_files rel target got linked=0 leaves=0 missing=""
    local active vars mime starship
    local hmvars sysvars declared key want i expected="" mismatch=""
    log "=== L4 user environment ==="

    active=$(systemctl is-active home-manager-adrioui.service 2>/dev/null || true)
    expect_eq L4 hm-active active "$active" "systemctl is-active home-manager-adrioui"

    gen=$(hm_generation)
    if [ -z "$gen" ] || [ ! -d "$gen/home-files" ]; then
        record L4 managed-paths "derived leaves" "no generation" Fail "systemctl cat home-manager-adrioui"
    else
        home_files=$(readlink -f "$gen/home-files")
        while IFS= read -r rel; do
            leaves=$((leaves + 1))
            target="$TARGET_HOME/$rel"
            got=$(readlink "$target" 2>/dev/null || true)
            if [ "$got" = "$home_files/$rel" ]; then
                linked=$((linked + 1))
            else
                missing="$missing $rel"
            fi
        done < <(
            cd "$home_files" &&
                find . -mindepth 1 \( -type f -o -type l \) -printf '%P\n' | LC_ALL=C sort
        )
        log "managed leaves=$leaves linked=$linked"
        if [ "$linked" -eq "$leaves" ]; then
            record L4 managed-paths "$leaves" "$linked" Pass "$home_files"
        else
            record L4 managed-paths "$leaves" "$linked of $leaves:$missing" Fail "$home_files"
        fi
    fi

    if [ ! -d "$SRC/.git" ]; then
        record L4 session-vars "declared keys match zsh" "no $SRC" Fail "$SRC"
        record L4 mimeapps "declared default" "no $SRC" Fail "$SRC"
    else
        hmvars=$(timeout 60 nix eval --json --offline --no-write-lock-file \
            "git+file://$SRC#nixosConfigurations.t14.config.home-manager.users.$TARGET_USER.home.sessionVariables" 2>/dev/null || true)
        sysvars=$(timeout 60 nix eval --json --offline --no-write-lock-file \
            "git+file://$SRC#nixosConfigurations.t14.config.environment.sessionVariables" 2>/dev/null || true)
        if [ -z "$hmvars" ] || [ -z "$sysvars" ]; then
            record L4 session-vars "declared keys match zsh" "nix eval failed (root-owned $SRC?)" Fail "$SRC"
        else
            declared=$(printf '%s\n%s\n' "$hmvars" "$sysvars" | jq -s 'add' 2>/dev/null || true)
            if [ -z "$declared" ] || [ "$(printf '%s' "$declared" | jq 'length')" -eq 0 ]; then
                record L4 session-vars "declared keys match zsh" "no declared keys" Fail "$SRC"
            else
                vars=$(run_as_user zsh -lic "printf \"%s|%s|%s|%s|%s|%s\" \"\${EDITOR-}\" \"\${VISUAL-}\" \"\${PAGER-}\" \"\${BROWSER-}\" \"\${MOZ_ENABLE_WAYLAND-}\" \"\${NIXOS_OZONE_WL-}\"" 2>/dev/null | tail -n 1 || true)
                [ -n "$vars" ] || vars='|||||'
                for key in EDITOR VISUAL PAGER BROWSER MOZ_ENABLE_WAYLAND NIXOS_OZONE_WL; do
                    want=$(printf '%s' "$declared" | jq -r --arg k "$key" '.[$k] // empty')
                    [ -n "$want" ] || continue
                    case $key in
                        EDITOR) i=1 ;;
                        VISUAL) i=2 ;;
                        PAGER) i=3 ;;
                        BROWSER) i=4 ;;
                        MOZ_ENABLE_WAYLAND) i=5 ;;
                        NIXOS_OZONE_WL) i=6 ;;
                        *) continue ;;
                    esac
                    got=$(printf '%s' "$vars" | cut -d'|' -f"$i")
                    expected="$expected $key=$want"
                    [ "$got" = "$want" ] || mismatch="$mismatch $key=got:$got"
                done
                if [ -z "$mismatch" ]; then
                    record L4 session-vars "declared keys match zsh" "declared:$expected" Pass "$SRC"
                else
                    record L4 session-vars "declared keys match zsh" "mismatch:$mismatch" Fail "$SRC"
                fi
            fi
        fi

        mime=$(timeout 60 nix eval --json --offline --no-write-lock-file \
            "git+file://$SRC#nixosConfigurations.t14.config.home-manager.users.$TARGET_USER.home.xdg.mimeApps.defaultApplications" 2>/dev/null |
            jq -r '."text/html" // empty' 2>/dev/null || true)
        if [ -z "$mime" ]; then
            record L4 mimeapps "declared default" "nix eval failed" Fail "$SRC"
        else
            got=$(run_as_user xdg-mime query default text/html 2>/dev/null || true)
            expect_eq L4 mimeapps "$mime" "${got:-missing}" "xdg-mime query default text/html"
        fi
    fi

    starship=$(run_as_user bash -c 'command -v starship' 2>/dev/null || true)
    if [ -n "$starship" ]; then
        record L4 starship found found Pass "$starship"
    else
        record L4 starship found missing Fail "command -v starship"
    fi
}

l5_services() {
    local svc sync podman status=0 attempt out ok provider
    local u show pid listen frag start hm_start decl decl_out loaded_out exe cmd why="" addr
    log "=== L5 services ==="
    expect_eq L5 firewall active "$(systemctl is-active firewall 2>/dev/null || true)" "systemctl is-active firewall"

    svc=$(systemctl is-active systemd-timesyncd 2>/dev/null || true)
    sync=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)
    if [ "$sync" = "yes" ]; then
        sync=synced
    else
        sync=${sync:-unsynced}
    fi
    expect_eq L5 ntp "active,synced" "$svc,$sync" "systemctl is-active systemd-timesyncd; timedatectl"

    expect_eq L5 tlp active "$(systemctl is-active tlp 2>/dev/null || true)" "systemctl is-active tlp"
    expect_eq L5 bluetooth active "$(systemctl is-active bluetooth 2>/dev/null || true)" "systemctl is-active bluetooth"

    podman=$(run_as_user podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || true)
    expect_eq L5 podman true "${podman:-missing}" "podman info"

    u=amp-deepseek-proxy.service
    show=$(run_as_user systemctl --user show -p LoadState -p ActiveState -p SubState -p MainPID -p FragmentPath -p ExecStart -p ExecMainStartTimestamp "$u" 2>/dev/null || true)
    get() { printf '%s\n' "$show" | sed -n "s/^$1=//p" | head -n1; }
    pid=$(get MainPID)
    frag=$(get FragmentPath)
    start=$(get ExecMainStartTimestamp)
    [ -n "$start" ] || start="unknown"
    listen=$(ss -ltnpH 'sport = :4014' 2>/dev/null | head -n1 || true)
    addr=$(printf '%s' "$listen" | awk '{print $4}')
    if [ "$(get LoadState)" != "loaded" ]; then
        why="$why load=$(get LoadState)"
    fi
    if [ "$(get ActiveState)/$(get SubState)" != "active/running" ]; then
        why="$why state=$(get ActiveState)/$(get SubState)"
    fi
    if [ -z "$pid" ] || [ "$pid" = "0" ]; then
        why="$why no-mainpid"
    fi
    if [ ! -e "$TARGET_HOME/.config/systemd/user/$u" ] || [ "$frag" != "$TARGET_HOME/.config/systemd/user/$u" ]; then
        why="$why fragment=$frag"
    fi
    if [ -z "$listen" ]; then
        why="$why no-listener"
    else
        case $addr in
            127.0.0.1:4014) ;;
            *) why="$why address=$addr" ;;
        esac
        case $listen in
            *"pid=$pid"*) ;;
            *) why="$why listener-pid=$(printf '%s' "$listen" | sed -n 's/.*pid=\([0-9]*\).*/\1/p')" ;;
        esac
    fi
    if [ -r "$TARGET_HOME/.config/systemd/user/$u" ]; then
        decl=$(sed -n 's/^ExecStart=//p' "$(readlink -f "$TARGET_HOME/.config/systemd/user/$u")" | head -n1)
        decl_out=$(printf '%s' "$decl" | awk '{print $1}')
        decl_store=$(printf '%s' "$decl_out" | grep -o '^/nix/store/[^/]*' || true)
        loaded_out=$(printf '%s' "$(get ExecStart)" | sed -n 's/^.*path=\([^ ]*\).*$/\1/p')
        if [ -n "$decl_out" ] && [ "$decl_out" != "$loaded_out" ]; then
            why="$why loaded=$loaded_out declared=$decl_out"
        fi
        if [ -n "$pid" ] && [ -e "/proc/$pid/exe" ]; then
            exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
            cmd=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)
            if [ -n "$decl_store" ]; then
                case $cmd in
                    *"$decl_store"*) ;;
                    *) why="$why argv-not-under-declared-output" ;;
                esac
            else
                why="$why no-declared-store"
            fi
            [ -n "$exe" ] || why="$why no-exe"
        else
            why="$why no-proc"
        fi
    else
        why="$why no-unit-file"
    fi
    if [ "$start" != "unknown" ] && [ -n "$(systemctl show -p ExecMainStartTimestamp --value home-manager-adrioui.service 2>/dev/null || true)" ]; then
        hm_start=$(systemctl show -p ExecMainStartTimestamp --value home-manager-adrioui.service 2>/dev/null || true)
        if [ "$(date -d "$start" +%s 2>/dev/null || echo 0)" -lt "$(( $(date -d "$hm_start" +%s 2>/dev/null || echo 0) - 5 ))" ]; then
            why="$why started-before-hm"
        fi
    fi
    if [ -z "$why" ]; then
        record L5 proxy-process "declared unit process owns 4014" "pid=$pid start=$start" Pass "$TARGET_HOME/.config/systemd/user/$u"
    else
        record L5 proxy-process "declared unit process owns 4014" "why:$why" Fail "$TARGET_HOME/.config/systemd/user/$u"
    fi

    if [ -z "$THREAD" ]; then
        skip L5 model-access "Served" "no thread" "check-access --thread" 1
        return
    fi
    if [ -z "$JQ" ]; then
        skip L5 model-access "Served" "jq not found" "check-access $PROVIDER_MODEL" 1
        return
    fi
    for attempt in 1 2; do
        status=0
        out=$(run_as_user timeout 60 amp config model-providers check-access \
            --provider-model "$PROVIDER_MODEL" --thread "$THREAD" 2>&1) || status=$?
        if [ "$status" -eq 0 ]; then
            break
        fi
        if [ "$attempt" -eq 1 ]; then
            log "model check exited $status; retrying once"
            sleep 2
        fi
    done
    ok=$(printf '%s' "$out" | "$JQ" -r 'if .ok == true then "true" else "false" end' 2>/dev/null || true)
    provider=$(printf '%s' "$out" | "$JQ" -r '.modelRouting.modelProviderName // .modelRouting.connection.name // "unknown"' 2>/dev/null || true)
    if [ "$ok" = "true" ]; then
        record L5 model-access "Served" "Served via $provider" Pass "check-access $PROVIDER_MODEL"
    elif [ "$status" -ne 0 ]; then
        record L5 model-access "Served" "check-access exit $status" Fail "check-access $PROVIDER_MODEL"
    else
        record L5 model-access "Served" "refused: ${provider:-unknown}" Fail "check-access $PROVIDER_MODEL"
    fi
}

n2_boot_init() {
    local n2=$1 id line
    for id in $(journalctl --list-boots --no-pager -o json 2>/dev/null | jq -r '.[].boot_id' 2>/dev/null); do
        line=$(journalctl -b "$id" -k -o cat 2>/dev/null | grep -m1 'Kernel command line:' || true)
        case $line in
            *"init=$n2/init"*) printf '%s' "$id"; return 0 ;;
        esac
    done
    return 1
}

attest_menu() {
    local f=$EVID/menu-rehearsal.txt id line n1
    n1=$(readlink -f "/nix/var/nix/profiles/system-$((N - 1))-link" 2>/dev/null || true)
    if [ ! -s "$f" ]; then
        skip L6 menu-rehearsal "journal boot N-1" "no transcript" "$f" 1
        return
    fi
    id=$(sed -n 's/^boot_id=//p' "$f" | head -n1 | tr -d '-')
    if [ -z "$id" ] || ! journalctl --list-boots --no-pager -o json 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .boot_id == $id)' >/dev/null 2>&1; then
        record L6 menu-rehearsal "journal boot N-1" "boot_id ${id:-absent} not in journal" Fail "$f"
        return
    fi
    line=$(journalctl -b "$id" -k -o cat 2>/dev/null | grep -m1 'Kernel command line:' || true)
    if [ -n "$n1" ] && printf '%s' "$line" | grep -q "init=$n1/init"; then
        record L6 menu-rehearsal "journal boot N-1" "boot $id init=$n1" Attested "$f"
    else
        record L6 menu-rehearsal "journal boot N-1" "boot $id init mismatch" Fail "$f"
    fi
}

attest_rescue() {
    local f=$EVID/rescue-media.txt want=${DUNIAWI_RESCUE_ISO_SHA256:-} got
    if [ ! -s "$f" ]; then
        skip L6 rescue-media "pinned rescue ISO" "no transcript" "$f" 1
        return
    fi
    if [ -z "$want" ]; then
        skip L6 rescue-media "pinned rescue ISO" "DUNIAWI_RESCUE_ISO_SHA256 is empty" "$f" 1
        return
    fi
    got=$(sed -n 's/^iso_sha256=//p' "$f" | head -n1)
    if [ "$got" = "$want" ] && grep -Eq '^[[:space:]]*timeout ' "$f" && grep -Eq '^[[:space:]]*default nixos-generation-' "$f"; then
        record L6 rescue-media "pinned rescue ISO" "iso=$got loader.conf present" Attested "$f"
    else
        record L6 rescue-media "pinned rescue ISO" "iso=${got:-absent} loader.conf missing or hash mismatch" Fail "$f"
    fi
}

l6_change() {
    local rev durable_head durable_status n2 n2link built cur days boot
    log "=== L6 change control ==="

    rev=$(/run/current-system/sw/bin/nixos-version --configuration-revision 2>/dev/null || true)
    if [ -z "$rev" ] && [ -r /run/current-system/configurationRevision ]; then
        rev=$(cat /run/current-system/configurationRevision)
    fi
    if printf '%s' "$rev" | grep -Eq '^[0-9a-f]{40}$'; then
        record L6 revision-format "40 hex" "$rev" Pass "/run/current-system/sw/bin/nixos-version"
    else
        record L6 revision-format "40 hex" "${rev:-absent}" Fail "/run/current-system/sw/bin/nixos-version"
    fi

    if [ -n "$EXPECT_REV" ]; then
        expect_eq L6 revision-source "$EXPECT_REV" "${rev:-absent}" "--expect-revision"
    else
        durable_head=$(git -c safe.directory='*' -C "$SRC" rev-parse HEAD 2>/dev/null || true)
        expect_eq L6 revision-source "${durable_head:-durable HEAD}" "${rev:-absent}" "git -C $SRC rev-parse HEAD"
    fi

    if [ -d "$SRC/.git" ]; then
        built=$(timeout 60 nix eval --offline --no-write-lock-file --raw \
            "git+file://$SRC#nixosConfigurations.t14.config.system.build.toplevel.outPath" 2>/dev/null || true)
        cur=$(readlink -f /run/current-system 2>/dev/null || true)
        if [ -n "$built" ] && [ "$built" = "$cur" ]; then
            record L6 revision-build "flake build = current" "$built" Pass "$SRC"
        else
            record L6 revision-build "flake build = current" "built=${built:-eval-failed} current=$cur" Fail "$SRC"
        fi
        if durable_status=$(git -c safe.directory='*' -C "$SRC" status --porcelain 2>/dev/null); then
            durable_status=$(printf '%s' "$durable_status" | grep -c . || true)
            durable_status=${durable_status:-0}
            expect_eq L6 durable-clean 0 "$durable_status" "git -C $SRC status --porcelain"
        else
            record L6 durable-clean 0 "git status failed" Fail "git -C $SRC status --porcelain"
        fi
        log "durable flake.lock $(sha256sum "$SRC/flake.lock" 2>/dev/null | cut -d' ' -f1)"
    else
        record L6 revision-build "flake build = current" "no $SRC" Fail "$SRC"
        record L6 durable-clean 0 "no $SRC" Fail "git -C $SRC status --porcelain"
    fi

    n2link="/nix/var/nix/profiles/system-$((N - 2))-link"
    n2=$(readlink -f "$n2link" 2>/dev/null || true)
    if [ -n "$N" ] && [ -e "/nix/var/nix/profiles/system-$((N - 1))-link" ] && [ -e "$n2link" ] &&
        case $n2 in /nix/store/*-nixos-system-*) true ;; *) false ;; esac; then
        if nix path-info "$n2" >/dev/null 2>&1; then
            record L6 generations "N-1 and N-2 exact links" "N=$N N-1=$(readlink -f "/nix/var/nix/profiles/system-$((N - 1))-link") N-2=$n2" Pass "$n2link"
        else
            record L6 generations "N-1 and N-2 exact links" "N-2 not in store: $n2" Fail "$n2link"
        fi
    else
        record L6 generations "N-1 and N-2 exact links" "missing N-1/N-2 link (N=${N:-none})" Fail "$n2link"
    fi

    if [ -n "$n2" ]; then
        if timeout 60 nix store verify --recursive --no-trust "$n2" >/dev/null 2>&1; then
            record L6 n-2-intact "store verify N-2" "ok" Pass "$n2"
        else
            record L6 n-2-intact "store verify N-2" "failed" Fail "$n2"
        fi
        if [ -e "$n2link" ]; then
            days=$((( $(date +%s) - $(stat -c %Y "$n2link") ) / 86400))
            if [ "$days" -lt 14 ]; then
                record L6 n-2-age "<14 days" "$days days" Pass "$n2link"
            else
                record L6 n-2-age "<14 days" "$days days" Fail "$n2link"
            fi
        else
            record L6 n-2-age "<14 days" "no N-2 link" Fail "$n2link"
        fi
        boot=$(n2_boot_init "$n2" || true)
        if [ -n "$boot" ]; then
            record L6 n-2-boot "journal boot with N-2 init" "boot $boot init=$n2" Pass "journalctl --list-boots"
        else
            record L6 n-2-boot "journal boot with N-2 init" "no retained boot for $n2" Fail "journalctl --list-boots"
        fi
    else
        record L6 n-2-intact "store verify N-2" "no N-2" Fail "$n2link"
        record L6 n-2-age "<14 days" "no N-2" Fail "$n2link"
        record L6 n-2-boot "journal boot with N-2 init" "no N-2" Fail "journalctl --list-boots"
    fi

    attest_menu
    attest_rescue
}

finalize() {
    local files=(verify.tsv context.json)
    local boot_id cmdline profile_link booted bootctl_json nixver head
    boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)
    cmdline=$(cat /proc/cmdline 2>/dev/null || true)
    profile_link=$(readlink /nix/var/nix/profiles/system 2>/dev/null || true)
    booted=$(readlink -f /run/booted-system 2>/dev/null || true)
    bootctl_json=$(bootctl list --json=short 2>/dev/null || echo '[]')
    [ -n "$bootctl_json" ] || bootctl_json='[]'
    nixver=$(/run/current-system/sw/bin/nixos-version --json 2>/dev/null || echo '{}')
    head=$(git -c safe.directory='*' -C "$SRC" rev-parse HEAD 2>/dev/null || true)
    jq -n \
        --arg evidence "$EVID" \
        --arg boot_id "$boot_id" \
        --arg cmdline "$cmdline" \
        --arg profile "$profile_link" \
        --arg booted "$booted" \
        --arg head "$head" \
        --argjson nixos "$nixver" \
        --argjson bootctl "$bootctl_json" \
        '{evidence:$evidence, boot_id:$boot_id, cmdline:$cmdline, profile:$profile, booted:$booted, durable_head:$head, nixos:$nixos, bootctl:$bootctl}' \
        >"$EVID/context.json"


    printf 'verify-complete checks=%d pass=%d fail=%d notrun=%d attested=%d\n' \
        "$checks" "$pass" "$fail" "$notrun" "$attested" >>"$TSV"
    [ -f "$EVID/menu-rehearsal.txt" ] && files+=(menu-rehearsal.txt)
    [ -f "$EVID/rescue-media.txt" ] && files+=(rescue-media.txt)
    (
        cd "$EVID"
        sha256sum "${files[@]}" >manifest.sha256
    )
    if [ "$(id -u)" -eq 0 ]; then
        chmod 0640 "$TSV" "$LOG" "$EVID/context.json" "$EVID/manifest.sha256"
        [ -f "$EVID/menu-rehearsal.txt" ] && chmod 0640 "$EVID/menu-rehearsal.txt"
        [ -f "$EVID/rescue-media.txt" ] && chmod 0640 "$EVID/rescue-media.txt"
    else
        chmod 0600 "$TSV" "$LOG" "$EVID/context.json" "$EVID/manifest.sha256"
    fi
    local result=Pass
    if [ "$fail" -ne 0 ]; then
        result=Fail
    fi
    log "=== result: $result checks=$checks pass=$pass fail=$fail notrun=$notrun attested=$attested required-notrun=$required_notrun ==="
    cat "$TSV"
    if [ "$fail" -ne 0 ]; then
        exit 1
    fi
    if [ "$STRICT" -eq 1 ] && [ "$required_notrun" -ne 0 ]; then
        log "strict: $required_notrun required row(s) NotRun"
        exit 2
    fi
    exit 0
}

main() {
    preflight
    l1_boot
    l2_session
    l3_hardware
    l4_home
    l5_services
    l6_change
    finalize
}

main
