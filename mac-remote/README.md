# mac-remote

A remote terminal on your Mac over Tailscale SSH: run commands and
supervise long-lived terminal sessions (tmux) — from your Muse VM, or
straight from the command line.

It ships as a [Muse](https://muse.ai) skill (an AI assistant can drive
the whole thing: see `../skills/mac-remote/SKILL.md`), but the helpers
are plain scripts you can run yourself.

## Install

```bash
git clone https://github.com/dute-ai/muse-utils ~/workspace/muse-utils
cd ~/workspace/muse-utils && ./install.sh
```

One-time Mac setup: enable Remote Login, join the same Tailscale network
on both ends, and authorize an SSH key.
(Details: `../skills/mac-remote/references/setup.md`.)

## Usage

The helpers live in `skills/mac-remote/bin/` (shown as `bin/` below).

Run a command on the Mac:

```bash
bin/mac-ssh 'uptime'
```

Start a persistent session and interact with it:

```bash
bin/mac-tmux new review ~/myproject claude   # start 'review' running claude in ~/myproject
bin/mac-tmux see review                       # read what's on screen
bin/mac-tmux send review "continue"           # type text, then Enter
bin/mac-tmux key review C-c                   # send a raw key
bin/mac-tmux list                             # all sessions
```

Tile several agents side by side in one window:

```bash
bin/mac-tmux split review ~/myproject codex   # split the pane, run codex; prints the new %pane-id
bin/mac-tmux layout review tiled
bin/mac-tmux panes review
```

Targets accept session names, `session:window.pane`, or `%pane-id`.

Watch sessions for changes:

```bash
bin/mac-watch add review
bin/mac-watch check        # per session: CHANGED (new lines) / QUIET (how long) / GONE
```

`mac-watch` reports mechanics only — what changed, not what it means.
The skill teaches an assistant how to interpret the report and run the
supervision loop: poll, read each pane's output, keep the agents moving,
and only interrupt you when something actually needs a decision.

## Requirements

- Mac with Tailscale installed, Remote Login enabled, and tmux (`brew install tmux`)
- Muse VM on the same Tailscale network (handled during setup)

## Repository layout

Part of the [muse-utils](https://github.com/dute-ai/muse-utils) collection.
This directory holds the mac-remote docs; the skill itself lives at
`skills/mac-remote/` in the repo root:

```
install.sh                  installs the skills into ~/workspace/skills/
skills/mac-remote/
  SKILL.md                  the skill: purpose, tooling, auth, operating rules
  bin/mac-ssh               SSH to the Mac over the Tailscale tunnel proxy
  bin/mac-tmux              tmux panes/sessions: new / split / see / send / key / panes / layout / list / kill
  bin/mac-watch             watch panes; report CHANGED / QUIET / GONE
  references/setup.md       one-time setup walkthrough
  references/gotchas.md     SSH/tmux/AppleScript pitfalls and how they're handled
state/                      machine-specific config + SSH keys (gitignored, created by install.sh)
```

## Development

The repo is the source of truth. `install.sh` cleanly reinstalls the skill
into `~/workspace/skills/mac-remote/` without touching `state/`. Edit in
the repo, reinstall, and push.
