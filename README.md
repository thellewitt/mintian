# XFCE4 Color Change Script v3.1

## Mirror Edition — Precision Cached Luminance

A lightweight Bash utility for generating dynamic XFCE4-Terminal color themes with automatic contrast handling, palette generation, and color personality detection.

Originally developed as part of the **XFCE4-Terminal Mirror**, this standalone edition brings the color engine into a simple script that can be used independently.

## Features

* 🎨 Generates unique terminal color themes on demand
* 🌈 Detects the generated palette's color character:

  * `ember` — reds and crimson tones
  * `solar` — oranges and yellows
  * `warm` — yellow-green tones
  * `cool` — greens and teals
  * `frost` — cyan and blue tones
  * `lunar` — purples, pinks, and magentas
  * `void` — rare near-black palettes
* 💡 Calculates luminance and enforces readable foreground/background contrast
* 🧮 Uses cached luminance calculations for faster repeated generation
* 🔄 Maintains palette history to avoid immediate repeats
* 🌬️ Includes a subtle palette breathing animation after theme generation
* 🔔 Optional desktop notification support

## Requirements

* Bash
* XFCE4-Terminal
* `xfconf-query`
* `awk`
* Optional:

  * `notify-send` for desktop notifications

## Installation

Make the script executable:

```bash
chmod +x xfce4-color-change-v3.1.sh
```

Run:

```bash
./xfce4-color-change-v3.1.sh
```

The script will generate a new terminal theme and apply it immediately.

## Options

The script accepts optional parameters:

```bash
./xfce4-color-change-v3.1.sh [contrast_threshold] [max_attempts]
```

Example:

```bash
./xfce4-color-change-v3.1.sh 7 100
```

Where:

* `contrast_threshold` controls the minimum WCAG-style contrast ratio
* `max_attempts` controls how many attempts are made when searching for a readable foreground color

Defaults:

```text
contrast_threshold = 4.5
max_attempts       = 50
```

## Example Output

```text
Mirror Aura: frost * ~ *
BG:          #4b6f71
FG:          #f3f9ff
```

## Design Notes

The color engine does not simply choose random colors. Generated palettes are processed through luminance analysis, contrast correction, hue classification, and polarity control to keep the result both visually interesting and usable.

The goal is a terminal theme that feels discovered rather than assigned.

## Version History

### v3.1 — Precision Cached Luminance Edition

* Added luminance caching
* Improved contrast handling
* Added palette history tracking
* Added Mirror Aura hue classification
* Improved generated palette polarity
* Added background breathing animation
* Extracted from the XFCE4-Terminal Mirror engine

## License

Released as part of the Mintian Utilities collection.
