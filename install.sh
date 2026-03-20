#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_LABEL="net.axiomfolly.desktop-sweep"
PLIST_TEMPLATE="$SCRIPT_DIR/$PLIST_LABEL.plist"
DEST_SCRIPT="$HOME/scripts/archive-desktop.sh"
DEST_PLIST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
ARCHIVE_DIR="$HOME/Desktop/Archive"
CONFIG_FILE="$ARCHIVE_DIR/config.cfg"

# Defaults (overridden by config.cfg if present)
SCHEDULE_HOUR=9
SCHEDULE_MINUTE=0

echo "=== Desktop Cleaner Installer ==="
echo ""
echo "Installing for user: $(whoami) ($HOME)"
echo ""

echo "Creating directories..."
mkdir -p "$HOME/scripts"
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

if [[ -f "$CONFIG_FILE" ]]; then
    echo "Found existing config.cfg — preserving it"
else
    echo "Installing default config.cfg -> $CONFIG_FILE"
    cp "$SCRIPT_DIR/config.cfg" "$CONFIG_FILE"
fi

# Read schedule from config
while IFS='=' read -r key value; do
    key="$(echo "$key" | xargs)"
    value="$(echo "$value" | xargs)"
    [[ -z "$key" || "$key" == \#* ]] && continue
    case "$key" in
        SCHEDULE_HOUR)   SCHEDULE_HOUR="$value" ;;
        SCHEDULE_MINUTE) SCHEDULE_MINUTE="$value" ;;
    esac
done < "$CONFIG_FILE"

echo "Schedule: daily at $(printf '%02d:%02d' "$SCHEDULE_HOUR" "$SCHEDULE_MINUTE")"

echo "Installing archive-desktop.sh -> $DEST_SCRIPT"
cp "$SCRIPT_DIR/archive-desktop.sh" "$DEST_SCRIPT"
chmod +x "$DEST_SCRIPT"

if launchctl list "$PLIST_LABEL" &>/dev/null; then
    echo "Unloading existing launchd agent..."
    launchctl unload "$DEST_PLIST" 2>/dev/null || true
fi

echo "Installing launchd plist -> $DEST_PLIST"
sed -e "s|__HOME__|$HOME|g" \
    -e "s|<integer>9</integer><!-- HOUR -->|<integer>$SCHEDULE_HOUR</integer><!-- HOUR -->|g" \
    -e "s|<integer>0</integer><!-- MINUTE -->|<integer>$SCHEDULE_MINUTE</integer><!-- MINUTE -->|g" \
    "$PLIST_TEMPLATE" > "$DEST_PLIST"

echo "Loading launchd agent..."
launchctl load "$DEST_PLIST"

echo ""
echo "Installation complete!"
echo ""
echo "  Script:  $DEST_SCRIPT"
echo "  Plist:   $DEST_PLIST"
echo "  Config:  $CONFIG_FILE"
echo "  Archive: $ARCHIVE_DIR/"
echo "  Log:     $ARCHIVE_DIR/archive.log"
echo ""
echo "To test now:  $DEST_SCRIPT --dry-run"
echo "To run now:   $DEST_SCRIPT"
echo ""
echo "To uninstall:"
echo "  launchctl unload $DEST_PLIST"
echo "  rm $DEST_PLIST $DEST_SCRIPT"
