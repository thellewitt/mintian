#!/bin/bash
# repair-projects-execbits.sh
# Recursively restore +x on shell scripts and executables under ~/Projects

cd ~/Projects || exit 1

find . -type f -print0 | while IFS= read -r -d '' f; do
    mime=$(file --mime-type -b "$f")
    case "$mime" in
        application/x-executable|text/x-shellscript)
            chmod +x "$f"
            echo "Made executable: $f"
            ;;
        text/plain)
            # fallback: plain text with shebang
            if head -n1 "$f" | grep -q '^#!'; then
                chmod +x "$f"
                echo "Made executable (shebang): $f"
            fi
            ;;
    esac
done
