#!/usr/bin/env bash
# Robust exo-open → xfce-open migration script (XFCE4 + XDG)

set -euo pipefail

# Ensure xfce-open is available before starting
if ! command -v xfce-open >/dev/null 2>&1; then
    echo "Error: xfce-open was not found in PATH." >&2
    exit 1
fi

BACKUP_DIR="$HOME/.config/xfce4/backup_exo_open_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Initializing backup directory at: $BACKUP_DIR"

declare -a files=(
    "$HOME/.config/xfce4/panel/xfce4-clipman-actions.xml"
    "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml"
    "$HOME/.config/mimeapps.list"
    "$HOME/.local/share/applications/mimeapps.list"
    "$HOME/.config/Thunar/uca.xml"
)

while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find "$HOME/.config/xfce4/panel" -type f -name "launcher*.desktop" -print0 2>/dev/null)

if [[ -d "$HOME/.local/share/applications" ]]; then
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$HOME/.local/share/applications" -type f -name "*.desktop" -print0 2>/dev/null)
fi

echo "✨ Processing configuration files..."

for f in "${files[@]}"; do
    if [[ -f "$f" ]] && grep -qF 'exo-open' "$f"; then
        rel="${f#$HOME/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -a "$f" "$BACKUP_DIR/$rel"
        
        sed -i 's/\bexo-open\b/xfce-open/g' "$f"
        echo "  Updated: $rel"
    fi
done

echo "🎉 Migration complete!"
echo "Backups stored safely in: $BACKUP_DIR"
