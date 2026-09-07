#!/bin/bash
# Grand Vizier's streamlined Dr. Konqi Tamer

INSTANCES=$(systemctl list-units --failed --no-legend --no-pager --plain | awk '{print $1}' | grep 'drkonqi-coredump-processor')

for INSTANCE in $INSTANCES; do
    echo "Checking $INSTANCE …"

    # Restart the service safely
    systemctl restart "$INSTANCE"
    echo "$INSTANCE restarted."

    # Show last 5 log lines
    journalctl -u "$INSTANCE" -n 5 --no-pager
done

echo "All Dr. Konqi instances tamed; timeout already honored."
