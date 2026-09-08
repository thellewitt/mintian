#!/usr/bin/env bash
# mintian-kernel-cleanup.sh
# Kernel cleanup and repair utility for Mintian
# Safe against stale repositories, metapackage removal,
# and ancient dependency resurrection.
#
# Operation modes:
#
#   --keep N
#       Keep N additional newest kernels in addition to the currently
#       running kernel and the newest installed kernel. This controls
#       how many older kernel ABIs are retained after those two are
#       protected. The default is 5.
#
#   --apply
#       Perform the requested kernel cleanup. Without --apply, the
#       script only performs a dry run and reports which packages
#       would be removed. --apply requires root privileges and asks
#       for confirmation before removing anything.
#
#   --repair-only
#       Do not perform kernel cleanup. Instead, repair the current
#       boot/kernel state by checking APT, protecting kernel
#       metapackages, repairing /boot permissions, refreshing the
#       /vmlinuz and /initrd.img symlinks, refreshing installed
#       headers/kbuild for the running ABI, and updating GRUB.
#
# Safety:
#   The running kernel and newest installed kernel are retained.
#   Obsolete kernel packages are removed only with --apply and
#   explicit confirmation.
#
# Safe against stale repositories, metapackage removal,
# and ancient dependency resurrection.
#
# Examples:
#
#   mintian-kernel-cleanup.sh
#       Dry run using the default retention policy.
#
#   mintian-kernel-cleanup.sh --keep 3
#       Dry run while retaining 3 additional older kernels.
#
#   mintian-kernel-cleanup.sh --keep 3 --apply
#       Remove obsolete kernels after displaying the removal list
#       and requesting confirmation.
#
#   mintian-kernel-cleanup.sh --repair-only
#       Repair boot/kernel state without removing kernels.

set -euo pipefail

# --- Configuration -----------------------------------------------------------

KEEP=5
APPLY=0
REPAIR_ONLY=0

LOG_DIR="/var/log/mintian"
LOG_FILE="$LOG_DIR/kernel-cleanup.log"

MIN_BOOT_KB=153600      # 150MB
MIN_ROOT_BOOT_KB=524288 # 512MB

PROTECTED_PKGS=(
    linux-generic
    linux-image-generic
    linux-headers-generic
    linux-base
    linux-tools-common
    linux-libc-dev
)

# --- Initialization ----------------------------------------------------------

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --keep N          Keep N additional newest kernels beyond the
                    running and newest installed kernels
  --apply           Perform actual removal
  --repair-only     Only repair boot/kernel state
  -h, --help        Show this help
EOF
}

# --- Argument Parsing --------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                echo "--keep requires a value." >&2
                usage
                exit 2
            fi
            KEEP="$2"
            shift 2
            ;;
        --apply)
            APPLY=1
            shift
            ;;
        --repair-only)
            REPAIR_ONLY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then
    echo "KEEP must be a non-negative integer." >&2
    exit 2
fi

# --- Helpers -----------------------------------------------------------------

log() {
    echo "$*"
}

die() {
    echo "❌ $*" >&2
    exit 1
}

abi_of() {
    local ver="$1"

    ver="${ver%%+deb*}"
    ver="${ver%%+mintian*}"
    ver="${ver%-generic}"
    ver="${ver%-lowlatency}"
    ver="${ver%-amd64}"

    printf "%s" "$ver"
}

check_boot_space() {
    local available
    local min_required
    local size_label

    available=$(df -Pk /boot | awk 'NR==2 {print $4}')

    if findmnt -rn /boot >/dev/null 2>&1; then
        min_required="$MIN_BOOT_KB"
        size_label="150MB"
    else
        min_required="$MIN_ROOT_BOOT_KB"
        size_label="512MB"
    fi

    if (( available < min_required )); then
        die "Low disk space. Required: $size_label Available: $((available / 1024))MB"
    fi
}

sanity_check_apt() {
    local candidate

    log "→ Refreshing package metadata..."
    apt-get update

    log "→ Verifying package integrity..."

    if ! apt-get check >/dev/null 2>&1; then
        die "APT dependency state is broken."
    fi

    # Ancient kernel ghost detection.
    # This is intentionally specific to a known Mintian repository problem.
    candidate="$(
        apt-cache policy linux-image-5.15.0-71-generic 2>/dev/null |
        awk '/^[[:space:]]*Candidate:/ {print $2; exit}'
    )"

    if [[ -n "$candidate" && "$candidate" != "(none)" ]]; then
        die "Stale repository metadata detected for obsolete kernels."
    fi
}

repair_boot_perms() {
    log "→ Repairing /boot permissions..."

    shopt -s nullglob

    local targets=(
        /boot/vmlinuz-*
        /boot/initrd.img-*
        /boot/System.map-*
        /boot/config-*
    )

    local f

    for f in "${targets[@]}"; do
        chown root:root "$f"
        chmod 0644 "$f"
    done

    shopt -u nullglob
}

update_root_symlinks() {
    log "→ Refreshing root symlinks..."

    local newest_vmlinuz=""
    local previous_vmlinuz=""
    local newest_initrd=""
    local previous_initrd=""

    local -a vmlinuz_files=()

    mapfile -t vmlinuz_files < <(
        find /boot \
            -maxdepth 1 \
            -type f \
            -name 'vmlinuz-*' \
            -printf '%T@ %p\n' 2>/dev/null |
        sort -nr |
        awk '{print $2}'
    )

    newest_vmlinuz="${vmlinuz_files[0]:-}"
    previous_vmlinuz="${vmlinuz_files[1]:-}"

    get_initrd_for() {
        local v="$1"

        [[ -z "$v" ]] && return 1

        local stem="${v#/boot/vmlinuz-}"
        local candidate="/boot/initrd.img-${stem}"

        [[ -e "$candidate" ]] && printf '%s\n' "$candidate"
    }

    newest_initrd="$(get_initrd_for "$newest_vmlinuz")"
    previous_initrd="$(get_initrd_for "$previous_vmlinuz")"

    if [[ -n "$newest_vmlinuz" ]]; then
        ln -sfT "$newest_vmlinuz" /vmlinuz
    fi

    if [[ -n "$newest_initrd" ]]; then
        ln -sfT "$newest_initrd" /initrd.img
    fi

    if [[ -n "$previous_vmlinuz" ]]; then
        ln -sfT "$previous_vmlinuz" /vmlinuz.old
    fi

    if [[ -n "$previous_initrd" ]]; then
        ln -sfT "$previous_initrd" /initrd.img.old
    fi
}

refresh_installed_kbuild_and_headers() {
    local abi
    abi="$(abi_of "$(uname -r)")"

    log "→ Verifying headers/kbuild for active ABI: $abi"

    local -a pkgs=(
        "linux-headers-$abi"
        "linux-headers-$abi-generic"
        "linux-kbuild-$abi"
    )

    local p

    for p in "${pkgs[@]}"; do
        if dpkg-query -W -f='${Status}' "$p" 2>/dev/null |
            grep -q "ok installed"; then

            apt-get install \
                --reinstall \
                -y \
                -o APT::Install-Recommends=false \
                -o APT::Install-Suggests=false \
                "$p" || true

            apt-mark manual "$p" || true
        fi
    done
}

protect_metapackages() {
    log "→ Protecting kernel metapackages..."

    apt-mark manual "${PROTECTED_PKGS[@]}" \
        >/dev/null 2>&1 || true
}

# --- Main --------------------------------------------------------------------

{
    echo "==========================================="
    echo "Mintian Kernel Cleanup: $(date)"
    echo "==========================================="

    CURRENT="$(abi_of "$(uname -r)")"
    log "Running kernel ABI: $CURRENT"

    check_boot_space

    # -------------------------------------------------------------------------
    # Repair-only mode
    # -------------------------------------------------------------------------

    if (( REPAIR_ONLY )); then
        if [[ "$EUID" -ne 0 ]]; then
            die "Must be root for --repair-only"
        fi

        sanity_check_apt
        protect_metapackages
        repair_boot_perms
        update_root_symlinks
        refresh_installed_kbuild_and_headers

        if command -v update-grub >/dev/null 2>&1; then
            update-grub
        fi

        log "✅ Boot state repair complete."
        exit 0
    fi

    # -------------------------------------------------------------------------
    # Apply mode
    # -------------------------------------------------------------------------

    if (( APPLY )); then
        if [[ "$EUID" -ne 0 ]]; then
            die "Must be root for --apply"
        fi

        sanity_check_apt
    fi

    # -------------------------------------------------------------------------
    # Discover installed kernel packages
    # -------------------------------------------------------------------------

    declare -a PKGS=()
    declare -a VERSIONS=()
    declare -a TO_KEEP_VERSIONS=()
    declare -a TO_REMOVE_PKGS=()

    declare -A VERSION_PKGS=()
    declare -A KEEP_MAP=()

    TO_KEEP_VERSIONS+=("$CURRENT")

    mapfile -t PKGS < <(
        dpkg-query -W -f='${Package}\n' |
        grep -E '^linux-(image|headers|modules|modules-extra)-' |
        grep -Ev '(-dbg|-dbgsym|-source|-oem-|lowlatency|virtual|-common$|^linux-tools-common$)' ||
        true
    )

    for p in "${PKGS[@]}"; do
        local_abi=""

        case "$p" in
            linux-image-*)
                local_abi="${p#linux-image-}"
                ;;
            linux-headers-*)
                local_abi="${p#linux-headers-}"
                ;;
            linux-modules-extra-*)
                local_abi="${p#linux-modules-extra-}"
                ;;
            linux-modules-*)
                local_abi="${p#linux-modules-}"
                ;;
            linux-tools-*)
                local_abi="${p#linux-tools-}"
                ;;
            *)
                continue
                ;;
        esac

        local_abi="$(abi_of "$local_abi")"

        [[ -n "$local_abi" ]] || continue

        major="${local_abi%%.*}"

        if ! [[ "$major" =~ ^[0-9]+$ ]]; then
            continue
        fi

        if (( major < 6 )); then
            continue
        fi

        VERSION_PKGS["$local_abi"]+="$p "
    done

    # -------------------------------------------------------------------------
    # Determine kernels to keep
    # -------------------------------------------------------------------------

    if (( ${#VERSION_PKGS[@]} > 0 )); then
        mapfile -t VERSIONS < <(
            printf '%s\n' "${!VERSION_PKGS[@]}" |
            sort -V
        )

        newest_installed="$(
            printf '%s\n' "${VERSIONS[@]}" |
            sort -Vr |
            head -n1
        )"

        if [[ -n "$newest_installed" ]]; then
            TO_KEEP_VERSIONS+=("$newest_installed")
        fi

        mapfile -t newest_others < <(
            printf '%s\n' "${VERSIONS[@]}" |
            sort -Vr |
            grep -v -x "$CURRENT" |
            grep -v -x "$newest_installed" |
            head -n "$KEEP" ||
            true
        )

        TO_KEEP_VERSIONS+=("${newest_others[@]}")
    fi

    # -------------------------------------------------------------------------
    # Build keep map
    # -------------------------------------------------------------------------

    for k in "${TO_KEEP_VERSIONS[@]}"; do
        KEEP_MAP["$k"]=1
    done

    # -------------------------------------------------------------------------
    # Determine removable packages
    # -------------------------------------------------------------------------

    for v in "${VERSIONS[@]}"; do
        if [[ ${KEEP_MAP["$v"]:-0} -eq 1 ]]; then
            continue
        fi

        for p in ${VERSION_PKGS["$v"]:-}; do
            TO_REMOVE_PKGS+=("$p")
        done
    done

    if (( ${#TO_REMOVE_PKGS[@]} > 0 )); then
        mapfile -t TO_REMOVE_PKGS < <(
            printf '%s\n' "${TO_REMOVE_PKGS[@]}" |
            awk '!seen[$0]++'
        )
    fi

    # -------------------------------------------------------------------------
    # Apply or dry run
    # -------------------------------------------------------------------------

    if (( APPLY )); then

        if (( ${#TO_REMOVE_PKGS[@]} > 0 )); then
            echo
            log "The following packages will be removed:"
            printf '  %s\n' "${TO_REMOVE_PKGS[@]}"
            echo

            read -rp "Proceed? [y/N]: " CONFIRM

            case "$CONFIRM" in
                [yY]|[yY][eE][sS])
                    log "Removing obsolete kernels..."
                    sleep 3

                    apt-get purge -y "${TO_REMOVE_PKGS[@]}"

                    protect_metapackages

                    log "→ Running controlled autoremove..."

                    apt-get autoremove \
                        -y \
                        -o APT::Install-Recommends=false \
                        -o APT::Install-Suggests=false

                    repair_boot_perms
                    update_root_symlinks
                    refresh_installed_kbuild_and_headers

                    if command -v update-grub >/dev/null 2>&1; then
                        update-grub
                    fi

                    log "✅ Cleanup complete."
                    ;;
                *)
                    log "❌ Aborted."
                    ;;
            esac
        else
            log "No obsolete kernels detected."
        fi

    else

        echo
        echo "=== DRY RUN ==="
        echo

        if (( ${#TO_REMOVE_PKGS[@]} > 0 )); then
            echo "The following packages would be removed:"
            echo
            printf '  %s\n' "${TO_REMOVE_PKGS[@]}"
        else
            echo "No packages would be removed."
        fi
    fi

} 2>&1 | tee -a "$LOG_FILE"
