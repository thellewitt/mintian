#!/bin/bash
# xfce4-color-change-v3.1.sh
# Version: 3.1
# Released: 2026-07-28

# =======================================================================================
# XFCE4 Color Change Script  •  v3.1
# Mirror Edition (Precision Cached Luminance)
# =======================================================================================
contrast_threshold="${1:-4.5}"
max_attempts="${2:-50}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/mirror-terminal"
history_file="$cache_dir/palette_history"
mkdir -p "$cache_dir"

declare -A LUM_CACHE

# Fast, native Bash hex parsing helper
hex_to_rgb() {
    local hex="${1#\#}"
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
}

random_color() {
    printf "#%06x" $(( ((RANDOM << 15) | RANDOM) & 0xffffff ))
}

background_not_recent() {
    local color="$1"
    [[ ! -f "$history_file" ]] && return 0
    ! grep -qi "^$color$" "$history_file"
}

cached_luminance() {
    local hex="$1"
    [[ -n "${LUM_CACHE[$hex]:-}" ]] && { echo "${LUM_CACHE[$hex]}"; return; }

    hex_to_rgb "$hex"
    local lum
    lum=$(awk -v r="$r" -v g="$g" -v b="$b" '
        function ch(c) { c/=255; return (c<=0.03928) ? c/12.92 : ((c+0.055)/1.055)^2.4 }
        BEGIN { printf "%.6f", (0.2126*ch(r) + 0.7152*ch(g) + 0.0722*ch(b)) }')
    LUM_CACHE[$hex]="$lum"
    echo "$lum"
}

clamp_luminance() {
    local color="$1" min="$2" max="$3"
    hex_to_rgb "$color"

    awk -v r="$r" -v g="$g" -v b="$b" -v min="$min" -v max="$max" '
        function lin(c) { c/=255.0; return (c <= 0.04045) ? c/12.92 : ((c+0.055)/1.055)^2.4 }
        function inv(c) { return (c <= 0.0031308) ? 12.92*c : 1.055*(c^(1/2.4)) - 0.055 }

        BEGIN {
            # Convert to linear RGB
            lr = lin(r)
            lg = lin(g)
            lb = lin(b)

            # Compute luminance
            lum = 0.2126*lr + 0.7152*lg + 0.0722*lb
            if (lum < 1e-6) lum = 1e-6

            # Determine target luminance
            target = lum
            if (lum < min)       target = min
            else if (lum > max)  target = max

            # Scale factor
            scale = target / lum

            # Apply scale in linear space
            lr *= scale
            lg *= scale
            lb *= scale

            # Clamp linear-light values to sRGB domain
            if (lr > 1) lr = 1; if (lg > 1) lg = 1; if (lb > 1) lb = 1
            if (lr < 0) lr = 0; if (lg < 0) lg = 0; if (lb < 0) lb = 0

            # Convert back to sRGB
            nr = inv(lr) * 255
            ng = inv(lg) * 255
            nb = inv(lb) * 255

            # Final clamp (integer domain)
            if (nr < 0) nr = 0; if (nr > 255) nr = 255
            if (ng < 0) ng = 0; if (ng > 255) ng = 255
            if (nb < 0) nb = 0; if (nb > 255) nb = 255

            printf "#%02x%02x%02x", int(nr+0.5), int(ng+0.5), int(nb+0.5)
        }'
}

ensure_contrast() {
    local bg_lum="$1"
    local fg_color="$2"
    local attempts=0
    local fg_lum ratio

    while (( attempts < max_attempts )); do
        fg_lum=$(cached_luminance "$fg_color")

        ratio=$(awk -v bg="$bg_lum" -v fg="$fg_lum" '
            BEGIN {
                b = bg + 0.05
                f = fg + 0.05
                printf "%.3f", (b > f ? b / f : f / b)
            }')

        if awk -v r="$ratio" -v min="$contrast_threshold" 'BEGIN { exit !(r >= min) }'; then
            echo "$fg_color"
            return
        fi

        # Preserve intended polarity while searching.
        if awk -v bg="$bg_lum" 'BEGIN{exit !(bg < 0.45)}'; then
            fg_color=$(clamp_luminance "$(random_color)" 0.80 0.98)
        else
            fg_color=$(clamp_luminance "$(random_color)" 0.02 0.15)
        fi

        ((attempts++))
    done

    # Guaranteed readable fallback.
    if awk -v bg="$bg_lum" 'BEGIN{exit !(bg < 0.45)}'; then
        echo "#ffffff"
    else
        echo "#000000"
    fi
}

force_indicator_polarity() {
    local color="$1" bg_lum="$2"
    if awk -v bg="$bg_lum" 'BEGIN{exit !(bg < 0.5)}'; then
        clamp_luminance "$color" 0.65 0.95
    else
        clamp_luminance "$color" 0.05 0.35
    fi
}

detect_palette_hue() {
    hex_to_rgb "$1"

    # Compute chroma (must come BEFORE Void logic)
    local max=$r; ((g>max)) && max=$g; ((b>max)) && max=$b
    local min=$r; ((g<min)) && min=$g; ((b<min)) && min=$b
    local chroma=$((max - min))

    # Void: extremely rare, true absence-of-light event
    if (( chroma < 25 )); then
        # Approximate perceptual luma
        local luma=$(( (r*2126 + g*7152 + b*722) / 10000 ))

        if (( luma < 18 )); then
            # Hybrid darkness test
            local avg=$(( (r + g + b) / 3 ))
            if (( avg < 30 )) && (( r < 40 && g < 40 && b < 40 )); then
                echo "void"
                return
            fi
        fi
    fi

    # Low chroma → neutral
    if (( chroma < 25 )); then
        echo "neutral"
        return
    fi

    # Compute hue angle (integer-safe approximation using awk)
    local h
    h=$(awk -v r="$r" -v g="$g" -v b="$b" -v c="$chroma" '
        BEGIN {
        if (c == 0) { print 0; exit }

        rr = r / c ; gg = g / c ; bb = b / c

        if (r >= g && r >= b)      h = 60 * (gg - bb)
        else if (g >= r && g >= b) h = 60 * (2 + (bb - rr))
        else                       h = 60 * (4 + (rr - gg))

        if (h < 0) h += 360
        print int(h)
        }')

    # Strict, non-overlapping territorial mapping
    if   (( h >= 340 || h < 20 ));  then echo "ember"   # True Reds/Crimsons
    elif (( h >=  20 && h < 65 ));  then echo "solar"   # Oranges and Yellows
    elif (( h >=  65 && h < 120 )); then echo "warm"    # Chartreuse and Yellow-Greens
    elif (( h >= 120 && h < 170 )); then echo "cool"    # Vibrant Greens and Teals
    elif (( h >= 170 && h < 255 )); then echo "frost"   # Cyans and Deep Blues
    elif (( h >= 255 && h < 340 )); then echo "lunar"   # Purples, Pinks, and Magentas
    else                                 echo "neutral" # Catch-all safety net
    fi
    }

# --- Main Engine Execution ---

attempt=0
while :; do
    background_color=$(random_color)
    background_not_recent "$background_color" && break
    ((attempt++))
    [[ $attempt -gt 40 ]] && break
done
L_bg=$(cached_luminance "$background_color")

if awk -v bg="$L_bg" 'BEGIN{exit !(bg < 0.45)}'; then
    foreground_color=$(clamp_luminance "$(random_color)" 0.80 0.98)
else
    foreground_color=$(clamp_luminance "$(random_color)" 0.02 0.15)
fi

foreground_color=$(ensure_contrast "$L_bg" "$foreground_color")

MIRROR_HUE=$(detect_palette_hue "$background_color")
export MIRROR_HUE

# Build Palette
palette_array=()
for i in {0..15}; do
    raw=$(random_color)
    palette_array+=("$(force_indicator_polarity "$raw" "$L_bg")")
done

color_palette=$(IFS=';'; echo "${palette_array[*]}")

echo "$background_color" >> "$history_file"
tail -n 200 "$history_file" > "${history_file}.tmp" && mv "${history_file}.tmp" "$history_file"

xfconf-query -c xfce4-terminal -p /color-background -s "$background_color"
xfconf-query -c xfce4-terminal -p /color-foreground -s "$foreground_color"
sleep 0.14
xfconf-query -c xfce4-terminal -p /color-palette    -s "$color_palette"

# Background Breathing Thread
breath_palette() {
    local base=("${palette_array[@]}")
    for cycle in {1..2}; do
        for shift in 4 8 12 8 4 0 -4 -8 -12 -8 -4 0; do
            local new=()
            for c in "${base[@]}"; do
                hex_to_rgb "$c"
                nr=$((r+shift)); ng=$((g+shift)); nb=$((b+shift))
                ((nr<0?nr=0:nr>255?nr=255:0)); ((ng<0?ng=0:ng>255?ng=255:0)); ((nb<0?nb=0:nb>255?nb=255:0))
                new+=("#$(printf "%02x%02x%02x" $nr $ng $nb)")
            done
            xfconf-query -c xfce4-terminal -p /color-palette -s "$(IFS=';'; echo "${new[*]}")"
            sleep 0.05
        done
    done
    xfconf-query -c xfce4-terminal -p /color-palette -s "$color_palette"
}
breath_palette & disown

# UI Interface Setup
case $MIRROR_HUE in
    void)   icon="[ . ]" ; p_clr="1;30" ;;
    solar)  icon="< O >" ; p_clr="1;33" ;;
    frost)  icon="* ~ *" ; p_clr="1;36" ;;
    ember)  icon="^ V ^" ; p_clr="1;31" ;;
    warm)   icon="{~~~}" ; p_clr="1;33" ;;
    cool)   icon="( - )" ; p_clr="1;32" ;;
    lunar)  icon="((O))" ; p_clr="1;35" ;;
    *)      icon="|- -|" ; p_clr="1;32" ;;
esac

if [[ "$BASH_SOURCE" != "$0" ]]; then
    PS1="\[\033[${p_clr}m\]$icon \[\033[0m\]\w \$ "
    echo -e "\033[1;31mMirror Aura:\033[0m $MIRROR_HUE $icon"
fi

echo "Mirror Aura: $MIRROR_HUE $icon"
echo "BG:          $background_color"
echo "FG:          $foreground_color"

if command -v notify-send &>/dev/null; then
    notify-send "Mirror Theme" \
        "Aura: $MIRROR_HUE $icon
BG: $background_color
FG: $foreground_color"
fi
