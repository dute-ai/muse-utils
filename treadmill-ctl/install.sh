#!/bin/bash
# install.sh — install the treadmill-ctl skill.
#
# Standalone: this directory is self-contained. Download just treadmill-ctl/
# (no need for the full muse-utils repo) and run this script.
set -euo pipefail
UTIL_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="treadmill-ctl"
DEST="$HOME/workspace/skills/$NAME"

rm -rf "$DEST"
mkdir -p "$DEST"
# explicit skill payload — README.md, install.sh and tests/ stay out
cp "$UTIL_DIR/SKILL.md" "$DEST/"
cp "$UTIL_DIR"/treadmill_ctl.py "$UTIL_DIR"/probe.py "$UTIL_DIR"/scan.py \
   "$UTIL_DIR"/ftms_status.py "$DEST/"
cp "$UTIL_DIR"/launch_scan.scpt "$UTIL_DIR"/read_win.scpt "$DEST/"
mkdir -p "$DEST/workouts"
cp "$UTIL_DIR"/workouts/*.json "$DEST/workouts/"

echo "Installed skill -> $DEST"
echo
echo "The scripts run on a Mac with Bluetooth (see README.md):"
echo "  System Settings -> Privacy & Security -> Bluetooth -> enable Terminal"
