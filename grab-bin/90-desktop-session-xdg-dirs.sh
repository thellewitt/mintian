#!/bin/sh
# /etc/profile.d/90-desktop-session-xdg-dirs.sh
# Sets up sane, deduplicated XDG_* vars for Mintian desktops (POSIX-compliant).

# --- Defaults ---
DEFAULT_XDG_CONFIG_DIRS="/etc/xdg"
DEFAULT_XDG_DATA_DIRS="/usr/local/share:/usr/share"

# Include /usr/local/etc/xdg if it exists
[ -d /usr/local/etc/xdg ] && DEFAULT_XDG_CONFIG_DIRS="/usr/local/etc/xdg:$DEFAULT_XDG_CONFIG_DIRS"

# Initialize XDG vars if empty
XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-$DEFAULT_XDG_CONFIG_DIRS}"
XDG_DATA_DIRS="${XDG_DATA_DIRS:-$DEFAULT_XDG_DATA_DIRS}"

# --- Desktop-Specific Paths ---
CONFIG_DESKTOP_DIRS="
/usr/local/etc/xdg/xfce4
/etc/xdg/lxqt
/etc/xdg/lxlauncher
/etc/xdg/lxpanel
/etc/xdg/lxsession
/usr/share/desktop-base/kf5-settings
/etc/xdg/openbox
"

DATA_DESKTOP_DIRS="
/usr/local/share/xfce4
/usr/share/lxqt
/usr/share/mate
/usr/share/lxde
/usr/share/budgie-desktop
/usr/share/cinnamon
/usr/share/gnome
/usr/share/plasma
"

# --- Extra Integration ---
EXTRA_DATA_DIRS="/var/lib/flatpak/exports/share"
[ -n "$HOME" ] && [ -d "$HOME/.local/share/flatpak/exports/share" ] && \
    EXTRA_DATA_DIRS="$EXTRA_DATA_DIRS:$HOME/.local/share/flatpak/exports/share"
SNAP_DIR="/var/lib/snapd/desktop"

# --- Utilities ---

# Prepend path if it exists and is not already in the list
prepend_unique_path() {
    list="$1"
    path="$2"
    [ ! -d "$path" ] && printf "%s" "$list" && return
    case ":$list:" in
        *:"$path":*) printf "%s" "$list" ;;
        *) [ -n "$list" ] && printf "%s:%s" "$path" "$list" || printf "%s" "$path" ;;
    esac
}

# Append path if it exists and is not already in the list
append_unique_path() {
    list="$1"
    path="$2"
    [ ! -d "$path" ] && printf "%s" "$list" && return
    case ":$list:" in
        *:"$path":*) printf "%s" "$list" ;;
        *) [ -n "$list" ] && printf "%s:%s" "$list" "$path" || printf "%s" "$path" ;;
    esac
}

# Remove duplicates and non-existent dirs from colon-separated list (more resilient)
sanitize_path_list() {
    input="$1"
    result=""
    seen=""
    set -f   # Disable pathname expansion
    IFS=':'
    for d in $input; do
        [ -z "$d" ] || [ ! -d "$d" ] && continue
        d="${d%/}"
        case ":$seen:" in
            *":$d:"*) continue ;;
        esac
        [ -z "$result" ] && result="$d" || result="$result:$d"
        seen="$seen:$d"
    done
    set +f
    unset IFS
    printf "%s" "$result"
}

# --- Construct Variables ---

# Sanitize initial vars
XDG_CONFIG_DIRS=$(sanitize_path_list "$XDG_CONFIG_DIRS")
XDG_DATA_DIRS=$(sanitize_path_list "$XDG_DATA_DIRS")

# Prepend desktop-specific dirs
for dir in $CONFIG_DESKTOP_DIRS; do
    XDG_CONFIG_DIRS=$(prepend_unique_path "$XDG_CONFIG_DIRS" "$dir")
done

for dir in $DATA_DESKTOP_DIRS $EXTRA_DATA_DIRS; do
    XDG_DATA_DIRS=$(prepend_unique_path "$XDG_DATA_DIRS" "$dir")
done

# Append Snap last
XDG_DATA_DIRS=$(append_unique_path "$XDG_DATA_DIRS" "$SNAP_DIR")

# Final sanitization
XDG_CONFIG_DIRS=$(sanitize_path_list "$XDG_CONFIG_DIRS")
XDG_DATA_DIRS=$(sanitize_path_list "$XDG_DATA_DIRS")

export XDG_CONFIG_DIRS
export XDG_DATA_DIRS
