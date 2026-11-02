#!/usr/bin/env bash























set -Eeuo pipefail
export LC_ALL=C

PROVIDER_MODEL=${PROVIDER_MODEL:-deepseek/deepseek-v4.1-flash}
EXPECTED_HM_PATHS=${EXPECTED_HM_PATHS:-14}
TARGET_USER=${TARGET_USER:-adrioui}

EVID=
EXPECT_REV=
THREAD=${AMP_THREAD_ID:-}
STRICT=0
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
        --strict)
            STRICT=1
            shift
            ;;
        -h | --help)
            sed -n '2,26p' "$0"
            exit 0
            ;;
        *)
            echo "unknown option $1" >&2
            exit 2
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

STAMP=$(date +%Y%m%dT%H%M%S)
EVID=${EVID:-$TARGET_HOME/.local/state/duniawi/evidence/$STAMP}
mkdir -p "$EVID"
EVID=$(readlink -f "$EVID")
if [ "$(id -u)" -eq 0 ]; then
    chown "$TARGET_USER:$(id -gn "$TARGET_USER")" "$EVID"
fi

TSV=$EVID/verify.tsv
LOG=$EVID/verify.log
: >"$TSV"
exec > >(tee -a "$LOG") 2>&1

checks=0
pass=0
fail=0
notrun=0
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

run_as_user() {
    if [ "$(id -u)" -eq 0 ]; then
        runuser -u "$TARGET_USER" -- env \
            HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
            XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
            PATH="$TARGET_HOME/.nix-profile/bin:/etc/profiles/per-user/$TARGET_USER/bin:/run/current-system/sw/bin" \
            "$@"
    else
        "$@"
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

preflight() {
    local gen home_files rel target got foreign=0 foreign_list=""
    log "=== preflight: declared paths and inputs ==="

    if [ -n "$THREAD" ]; then
        record L5 thread "provided" "$THREAD" Pass "--thread/AMP_THREAD_ID"
    else
        record L5 thread "provided" "missing" Fail "--thread/AMP_THREAD_ID"
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
    if [ -e "$TARGET_HOME/.config/systemd/user-disabled/amp-deepseek-proxy.service" ]; then
        log "archive: the moved .wants symlink is in user-disabled/"
    fi
}

l1_boot() {
    local failed graphical entries
    log "=== L1 boot ==="
    failed=$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l)
    expect_eq L1 failed-units 0 "$failed" "systemctl --failed"

    graphical=$(systemctl is-active graphical.target 2>/dev/null || true)
    expect_eq L1 graphical-target active "$graphical" "systemctl is-active graphical.target"

    if [ -r /boot/loader/loader.conf ]; then
        entries=$(bootctl list 2>/dev/null | grep -c 'nixos-generation' || true)
        entries=${entries:-0}
        if [ "$entries" -ge 2 ]; then
            record L1 loader-entries ">=2 generations" "$entries" Pass "bootctl list"
        else
            record L1 loader-entries ">=2 generations" "$entries" Fail "bootctl list"
        fi
    else
        skip L1 loader-entries ">=2 generations" "unreadable /boot" "bootctl list" 1
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
    log "=== L4 user environment ==="

    active=$(systemctl is-active home-manager-adrioui.service 2>/dev/null || true)
    expect_eq L4 hm-active active "$active" "systemctl is-active home-manager-adrioui"

    gen=$(hm_generation)
    if [ -z "$gen" ] || [ ! -d "$gen/home-files" ]; then
        record L4 managed-paths "$EXPECTED_HM_PATHS" "no generation" Fail "systemctl cat home-manager-adrioui"
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
        if [ "$linked" -eq "$EXPECTED_HM_PATHS" ] && [ "$leaves" -eq "$EXPECTED_HM_PATHS" ]; then
            record L4 managed-paths "$EXPECTED_HM_PATHS" "$linked" Pass "$home_files"
        else
            record L4 managed-paths "$EXPECTED_HM_PATHS" "$linked of $leaves:$missing" Fail "$home_files"
        fi
    fi



    vars=$(run_as_user zsh -lic 'printf "%s|%s|%s|%s|%s" "${EDITOR-}" "${PAGER-}" "${BROWSER-}" "${MOZ_ENABLE_WAYLAND-}" "${NIXOS_OZONE_WL-}"' 2>/dev/null | tail -n 1 || true)
    expect_eq L4 session-vars "nvim|less|helium|1|1" "${vars:-missing}" "zsh -lic"

    mime=$(run_as_user xdg-mime query default text/html 2>/dev/null || true)
    expect_eq L4 mimeapps helium.desktop "${mime:-missing}" "xdg-mime query default text/html"

    starship=$(run_as_user bash -c 'command -v starship' 2>/dev/null || true)
    if [ -n "$starship" ]; then
        record L4 starship found found Pass "$starship"
    else
        record L4 starship found missing Fail "command -v starship"
    fi
}

l5_services() {
    local svc sync podman status=0 attempt out ok provider
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

l6_change() {
    local rev durable_head durable_status links gen_count n2 target
    log "=== L6 change control ==="




    rev=$(nixos-version --configuration-revision 2>/dev/null || true)
    if [ -z "$rev" ] && [ -r /run/current-system/configurationRevision ]; then
        rev=$(cat /run/current-system/configurationRevision)
    fi
    if printf '%s' "$rev" | grep -Eq '^[0-9a-f]{40}$'; then
        record L6 revision-format "40 hex" "$rev" Pass "nixos-version --configuration-revision"
    else
        record L6 revision-format "40 hex" "${rev:-absent}" Fail "nixos-version --configuration-revision"
    fi

    if [ -n "$EXPECT_REV" ]; then
        expect_eq L6 revision-source "$EXPECT_REV" "${rev:-absent}" "--expect-revision"
    else
        durable_head=$(git -c safe.directory='*' -C /var/lib/duniawi-src rev-parse HEAD 2>/dev/null || true)
        expect_eq L6 revision-source "${durable_head:-durable HEAD}" "${rev:-absent}" "git -C /var/lib/duniawi-src rev-parse HEAD"
    fi

    if [ -d /var/lib/duniawi-src/.git ]; then
        if durable_status=$(git -c safe.directory='*' -C /var/lib/duniawi-src status --porcelain 2>/dev/null); then
            durable_status=$(printf '%s' "$durable_status" | grep -c . || true)
            durable_status=${durable_status:-0}
            expect_eq L6 durable-clean 0 "$durable_status" "git -C /var/lib/duniawi-src status --porcelain"
        else
            record L6 durable-clean 0 "git status failed" Fail "git -C /var/lib/duniawi-src status --porcelain"
        fi
        log "durable flake.lock $(sha256sum /var/lib/duniawi-src/flake.lock 2>/dev/null | cut -d' ' -f1)"
    else
        record L6 durable-clean 0 "no /var/lib/duniawi-src" Fail "git -C /var/lib/duniawi-src status --porcelain"
    fi

    links=$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' -printf '%f\n' 2>/dev/null | LC_ALL=C sort -V)
    gen_count=$(printf '%s\n' "$links" | grep -c . || true)
    gen_count=${gen_count:-0}
    if [ "$gen_count" -ge 3 ]; then
        record L6 generations ">=3" "$gen_count" Pass "nix-env --list-generations"
    else
        record L6 generations ">=3" "$gen_count" Fail "nix-env --list-generations"
    fi

    if [ "$gen_count" -ge 3 ]; then
        n2=$(printf '%s\n' "$links" | tail -n 3 | head -n 1)
        target=$(readlink -f "/nix/var/nix/profiles/$n2" 2>/dev/null || true)
        case $target in
            /nix/store/*-nixos-system-*)
                record L6 n-2 bootable "$n2 -> $target" Pass "$n2"
                ;;
            *)
                record L6 n-2 bootable "$n2 -> ${target:-dangling}" Fail "$n2"
                ;;
        esac
    else
        record L6 n-2 bootable "fewer than 3 generations" Fail "nix-env --list-generations"
    fi

    if [ -s "$EVID/rescue-media.txt" ]; then
        record L6 rescue-media "booted USB" "recorded" Pass "$EVID/rescue-media.txt"
    else
        skip L6 rescue-media "booted USB" "no operator evidence" "$EVID/rescue-media.txt" 1
    fi
    if [ -s "$EVID/menu-rehearsal.txt" ]; then
        record L6 menu-rehearsal "booted N-1" "recorded" Pass "$EVID/menu-rehearsal.txt"
    else
        skip L6 menu-rehearsal "booted N-1" "no operator evidence" "$EVID/menu-rehearsal.txt" 1
    fi
}

finalize() {
    local result=Pass
    if [ "$fail" -ne 0 ]; then
        result=Fail
    fi


    printf 'verify-complete\tchecks=%d\tpass=%d\tfail=%d\tnotrun=%d\n' \
        "$checks" "$pass" "$fail" "$notrun" >>"$TSV"
    log "=== result: $result checks=$checks pass=$pass fail=$fail notrun=$notrun required-notrun=$required_notrun ==="
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
