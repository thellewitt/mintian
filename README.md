# XFCE4-Terminal Dynamic Color Theme Script

## Overview

This Bash script dynamically changes the color theme of the XFCE4 Terminal. It generates random background and foreground colors, ensuring they meet the Web Content Accessibility Guidelines (WCAG) 2.0 contrast ratio for readability. Additionally, it applies a unique random background color to each open tab.

The script is designed to provide an aesthetically pleasing and accessible terminal experience with every new terminal window or tab.

## Features

* **Dynamic Color Generation:** Generates random hexadecimal color codes for the terminal background and foreground.
* **WCAG 2.0 Contrast Compliance:** Ensures that the generated foreground text color has sufficient contrast against the background color, adhering to the WCAG 2.0 AA contrast ratio of at least 4.5:1 for normal text.
* **Tab-Specific Backgrounds:** Applies a unique random background color to each open tab in the terminal.
* **Customizable Contrast Threshold:** Allows users to specify the minimum contrast ratio via a command-line argument.
* **Loop Prevention:** Includes a maximum attempt counter to prevent infinite loops when searching for a compliant color combination.
* **Color Palette Generation:** Generates a diverse 16-color palette for the terminal.
* **Efficient Luminance Calculation:** Uses optimized `awk` for calculating color luminance.
* **Caching:** Implements caching for luminance values to improve performance.
* **Notifications (Optional):** Can send desktop notifications upon theme and tab color changes (requires `notify-send`).

## Usage

1.  **Save the Script:** Save the script to a file, for example, `xfce4-color-change.sh`.
2.  **Make it Executable:** Open a terminal and run:
    ```bash
    chmod +x xfce4-color-change.sh
    ```
3.  **Run the Script:** Execute the script. This is typically done when launching a new XFCE4 Terminal window or tab by piping the output to `xfce4-terminal`:
    ```bash
    ./xfce4-color-change.sh | xfce4-terminal
    ```
    You can also set this as the command to run when opening a new terminal in your XFCE4 settings.

### Command-Line Arguments

* `${1:-7.0}`: (Optional) Specifies the minimum contrast ratio. Defaults to `7.0` (WCAG 2.0 AAA for enhanced contrast).
* `${2:-50}`: (Optional) Specifies the maximum number of attempts to find a compliant color combination. Defaults to `50`.

**Example:**

To run the script with a contrast threshold of 5.0:

```bash
./xfce4-color-change.sh 5.0 | xfce4-terminal

Requirements:

    bash
    xfconf-query (part of the XFCE desktop environment)
    awk
    notify-send (optional, for desktop notifications)

Installation:

No specific installation is required. Simply save the script and make it executable.

Configuration:

The main configuration options are available as command-line arguments (contrast threshold and maximum attempts). You can adjust these values to your preference.
Contributing

Feel free to fork this repository and submit pull requests for any improvements or bug fixes.

    Inspired by the desire for a dynamic and accessible terminal color scheme.
    Utilizes the WCAG 2.0 guidelines for color contrast.
