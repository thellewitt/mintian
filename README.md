
## Overview

This Bash script dynamically changes the color theme of the XFCE4 Terminal. It generates random background and foreground colors, ensuring they meet the Web Content Accessibility Guidelines (WCAG) 2.0 contrast ratio for readability. Additionally, it applies a unique random background color to each open tab.

The script is designed to provide an aesthetically pleasing and accessible terminal experience with every new terminal window or tab.

---

## ✨ Features

- **Dynamic Color Generation** – Random hex color codes for background and foreground.
- **WCAG 2.0 Contrast Compliance** – Ensures at least a 4.5:1 contrast ratio (AA standard).
- **Unique Per Tab** – Each open tab can have its own unique background.
- **Customizable Contrast Threshold** – User-defined minimum contrast via CLI.
- **Loop Prevention** – Maximum attempt count to avoid infinite loops.
- **Full 16-Color Palette** – Generates and applies a custom palette.
- **Optimized Luminance Calculation** – Uses efficient `awk` math.
- **Luminance Caching** – Reduces redundant calculations.
- **Desktop Notifications** – Optional `notify-send` alerts when themes change.

---

## 🧪 Usage

1. **Save the Script**  
   Save the file as `xfce4-color-change.sh`.

2. **Make it Executable**
   ```bash
   chmod +x xfce4-color-change.sh

    Run the Script
    Pipe it into xfce4-terminal:

    ./xfce4-color-change.sh | xfce4-terminal

    Auto-run on Terminal Launch
    Set this script in your XFCE4 terminal’s launch command (under Preferences > General).

🛠️ Command-Line Arguments
Argument	Description	Default
${1}	Minimum contrast ratio (e.g., 5.0 for AA, 7.0 for AAA)	7.0
${2}	Max attempts to find a compliant color combo	50

Example:

./xfce4-color-change.sh 5.0 | xfce4-terminal

📦 Requirements

    bash

    xfconf-query (XFCE environment)

    awk

    notify-send (optional)

🔧 Configuration

No formal installation needed. Save the script, make it executable, and run it. You can tweak the contrast threshold or max attempts via CLI args.
🤝 Contributing

Pull requests welcome!
Feel free to fork and submit improvements, ideas, bug fixes, or translations.

    Inspired by the desire for a dynamic and accessible terminal color scheme.
    Based on WCAG 2.0 color contrast guidelines for inclusivity and readability.

🪪 License

This script is released into the public domain. You are free to use, modify, distribute, and share it as you wish—no attribution required, but always appreciated.
