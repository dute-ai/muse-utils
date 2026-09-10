---
name: "mac_remote"
description: "Drive the user's Mac from this VM over Tailscale SSH: run shell commands, and start, observe, and interact with terminal sessions (tmux) hosting coding agents like Claude Code or Codex. Use when asked to do something on the user's Mac, check on a Mac terminal session, or send input to one."
---

# mac-remote

## Purpose
Reach the user's Mac from this VM and work with it: run shell commands, and host long-lived terminal sessions you can see into and type into.

## Tooling
Helpers live in `bin/` — always use them, never hand-roll the SSH/tmux plumbing.

- `bin/mac-ssh [args...]` — SSH to the Mac. Example: `bin/mac-ssh 'uptime'`
- `bin/mac-tmux <cmd>` — terminal sessions on the Mac via tmux:
  - `new <name> <dir> <cmd...>` — start a detached session running `cmd` in `dir`
  - `see <name> [lines]` — read the pane's screen text (what the agent sees)
  - `send <name> <text...>` — type text literally, then Enter (submits a prompt)
  - `key <name> <key>` — send a raw key: `C-c`, `Escape`, `Up`
  - `list`, `kill <name>`
- `bin/mac-watch <cmd>` — supervise sessions: `add` / `rm` / `list` the
  watchlist; `check [--json]` captures each watched pane, diffs it against
  the last check, and prints one line per session plus blocks of new output.
  Reports mechanics only (CHANGED / QUIET / GONE) — it never judges
  "needs input" or "stuck". State in `<state-dir>/watch/`.

## Auth
SSH key auth. One-time setup is in `references/setup.md`: enable Remote Login on the Mac, join the same Tailscale network on both ends, generate a keypair on the VM, add the public key to the Mac's `~/.ssh/authorized_keys`, and write `MAC_REMOTE_USER` / `MAC_REMOTE_HOST` to the state config. The first tunnel connection needs the user's approval — let it sit, don't retry.

## Operating Rules
1. BatchMode is on: there are no password prompts. If auth fails, re-check setup (`references/setup.md`) instead of retrying in a loop.
2. Prefer tmux sessions for anything you may need to observe or interact with later.
3. `send` types into a live session: only send what the user asked for. Never send interrupt keys (`C-c`) to a session you didn't start unless asked.
4. You cannot see the Mac's screen (`screencapture` fails — an SSH session has no display) and cannot inject keystrokes/clicks into GUI apps (Accessibility denies it). Launching apps with `open -a` and driving Terminal.app via AppleScript (`do script`, `contents of tab`) do work — see `references/gotchas.md`.
5. Keep the Mac's Tailscale IP, username, and key paths in the state config, never in chat or logs. Never print a private key.
6. The helpers resolve config from env vars first, then `<state-dir>/config`. When run from this repo the state dir is `<repo>/state` (gitignored); when installed, `~/workspace/mac-remote/state`.
7. `mac-watch` is a mechanical reporter, not a judge. `check` captures each
   watched pane, diffs it against the last check, and shows what changed —
   CHANGED with the new lines, QUIET with how long it's been quiet, GONE if
   the session vanished. It never classifies "needs input" or "stalled";
   that call is yours when you read a scheduled `check` run. Surface to the
   user only what's actually new. (Timer/status-bar ticks show up as
   1-new-line CHANGEDs — ignore those.)
