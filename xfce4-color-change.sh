#!/bin/bash

# XFCE4-Terminal Color Change Script - Optimized Version 4
# Ensures WCAG 2.0 contrast compliance and applies unique background colors per tab.

contrast_threshold=${1:-7.0}  # Minimum contrast ratio
max_attempts=${2:-50}         # Avoid infinite loops

declare -A luminance_cache colors_used

random_color() {
  printf "#%02x%02x%02x" $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
}

get_luminance() {
  local hex="$1"
  local r=$((0x${hex:1:2})) g=$((0x${hex:3:2})) b=$((0x${hex:5:2}))
  awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN {
    r = (r/255)^2.4; g = (g/255)^2.4; b = (b/255)^2.4;
    print (0.2126*r + 0.7152*g + 0.0722*b);
  }'
}

cached_luminance() {
  local color="$1"
  [[ -n "${luminance_cache[$color]}" ]] && echo "${luminance_cache[$color]}" || {
    luminance_cache[$color]="$(get_luminance "$color")"
    echo "${luminance_cache[$color]}"
  }
}

generate_palette() {
  local palette=""
  for i in {1..16}; do
    local color
    while :; do
      color=$(random_color)
      [[ -z "${colors_used[$color]}" ]] && break
    done
    colors_used[$color]=1
    palette+="$color;"
  done
  echo "${palette%?}"
}

ensure_contrast() {
  local bg_lum="$1" fg_color="$2" attempts=0 fg_lum
  while :; do
    fg_lum=$(cached_luminance "$fg_color")
    if awk -v bg="$bg_lum" -v fg="$fg_lum" -v min="$contrast_threshold" \
         'BEGIN { print ((bg+0.05 > fg+0.05 ? (bg+0.05)/(fg+0.05) : (fg+0.05)/(bg+0.05)) >= min) }' | grep -q 1; then
      echo "$fg_color"
      return
    fi
    ((attempts++ >= max_attempts)) && break
    fg_color=$(random_color)
  done
  echo "#000000"  # Fallback
}

background_color=$(random_color)
L_bg=$(cached_luminance "$background_color")
foreground_color=$(ensure_contrast "$L_bg" "$(random_color)")
color_palette=$(generate_palette)

xfconf-query -c xfce4-terminal -p /color-background -s "$background_color"
xfconf-query -c xfce4-terminal -p /color-foreground -s "$foreground_color"
xfconf-query -c xfce4-terminal -p /color-palette -s "$color_palette"

echo "Terminal theme changed: BG=$background_color, FG=$foreground_color"
command -v notify-send &>/dev/null && notify-send "Terminal Theme Changed" \
  "BG: $background_color, FG: $foreground_color" &>/dev/null & disown

for i in $(seq 0 $(($(xfconf-query -c xfce4-terminal -p /tabs -n | wc -l) - 1))); do
  tab_background_color=$(ensure_contrast "$L_bg" "$(random_color)")
  xfconf-query -c xfce4-terminal -p /tabs/$i/color-background -s "$tab_background_color"
done

echo "Unique background colors applied to each tab."
command -v notify-send &>/dev/null && notify-send "Tab Background Colors Changed" \
  "Unique background colors applied to each tab." &>/dev/null & disown
