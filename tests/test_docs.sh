#!/bin/bash
# test_docs.sh — automates the repo audit: no stale rename notes or old
# repo URLs, and every relative doc link resolves to a real file.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }

# --- stale references (exclude tests/: this file matches its own patterns) ---
stale="$(grep -rniE "being renamed|rename pending" --include="*.md" --include="*.sh" \
    "$REPO" --exclude-dir=.git --exclude-dir=state --exclude-dir=tests || true)"
[ -z "$stale" ] && ok "no stale rename notes" || { fail "stale rename notes:"; echo "$stale"; }

oldurl="$(grep -rn "dute-ai/mac-remote" --include="*.md" --include="*.sh" \
    "$REPO" --exclude-dir=.git --exclude-dir=state --exclude-dir=tests || true)"
[ -z "$oldurl" ] && ok "no old repo URLs" || { fail "old repo URLs:"; echo "$oldurl"; }

# --- relative links in READMEs and SKILL.md files resolve ---
# A backtick path is checkable if it looks like a repo-relative path and
# doesn't start with ~, $, <, or contain a *.
is_checkable() {
    # reject URLs, variables, globs, and usage examples (spaces/quotes)
    case "$1" in "~"*|"\$"*|"<"*|*"*"*|http*|""|*" "*|*"'"*|*'"'*) return 1;; esac
    case "$1" in *.md|*.sh|yt-tv|*/yt-tv|install.sh|bin|bin/*|skills/*|state/*|mac-remote|mac-remote/*|youtube-lounge|youtube-lounge/*) return 0;; esac
    return 1
}

while IFS= read -r doc; do
    dir="$(dirname "$doc")"
    rel="${doc#$REPO/}"
    # backtick-quoted paths
    while IFS= read -r p; do
        is_checkable "$p" || continue
        if [ -e "$dir/$p" ] || [ -e "$REPO/$p" ]; then ok "resolves: $rel -> $p";
        else fail "broken: $rel -> $p"; fi
    done < <(grep -o '`[^`]*`' "$doc" | tr -d '`' | sort -u)
    # markdown links [text](target)
    while IFS= read -r p; do
        is_checkable "$p" || continue
        if [ -e "$dir/$p" ] || [ -e "$REPO/$p" ]; then ok "resolves: $rel -> $p";
        else fail "broken: $rel -> $p"; fi
    done < <(grep -o '\]([^)]*)' "$doc" | sed 's/^](//; s/)$//' | sort -u)
done < <(find "$REPO" \( -name "README.md" -o -name "SKILL.md" \) -not -path "*/.git/*" | sort)

# --- every utility dir (has SKILL.md) ships README.md + executable install.sh ---
while IFS= read -r skill; do
    udir="$(dirname "$skill")"
    urel="${udir#$REPO/}"
    [ -f "$udir/README.md" ] && ok "$urel has README.md" || fail "$urel missing README.md"
    [ -x "$udir/install.sh" ] && ok "$urel has executable install.sh" || fail "$urel missing executable install.sh"
done < <(find "$REPO" -maxdepth 2 -name "SKILL.md" -not -path "*/.git/*" | sort)

# --- every script a SKILL.md claims exists, exists ---
while IFS= read -r skill; do
    sdir="$(dirname "$skill")"
    while IFS= read -r p; do
        is_checkable "$p" || continue
        case "$p" in bin/*|yt-tv)
            [ -e "$sdir/$p" ] && ok "skill tool exists: ${skill#$REPO/} -> $p" \
                              || fail "skill tool missing: ${skill#$REPO/} -> $p";;
        esac
    done < <(grep -o '`[^`]*`' "$skill" | tr -d '`' | sort -u)
done < <(find "$REPO" -maxdepth 2 -name "SKILL.md" -not -path "*/.git/*" | sort)

[ "$fails" -eq 0 ]
