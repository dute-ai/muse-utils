#!/bin/bash
# install.sh — install muse-utils skills into this Muse VM.
# Usage: ./install.sh [utility-name]   (no argument = install all utilities)
# Safe to re-run: each utility installer cleanly reinstalls without
# touching state/.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# A utility is a directory with a SKILL.md and an executable install.sh.
list_utils() {
    for d in "$REPO_ROOT"/*/; do
        [ -f "$d/SKILL.md" ] && [ -x "$d/install.sh" ] && basename "$d"
    done
}

install_util() {
    local name="$1"
    if [ ! -f "$REPO_ROOT/$name/SKILL.md" ] || [ ! -x "$REPO_ROOT/$name/install.sh" ]; then
        echo "unknown utility: $name (available: $(list_utils | tr '\n' ' '))" >&2
        exit 1
    fi
    bash "$REPO_ROOT/$name/install.sh"
}

if [ "${1:-}" != "" ]; then
    install_util "$1"
else
    for u in $(list_utils); do
        install_util "$u"
    done
fi
