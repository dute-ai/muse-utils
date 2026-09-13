# mac-remote

Give your Muse a remote terminal on your Mac.

`mac-remote` is a [Muse](https://muse.ai) skill that connects Muse to your Mac
over SSH via Tailscale. Muse can run commands, start persistent terminal
sessions, read their output, and interact with them — for example, to
supervise coding agents like Claude Code or Codex running on your machine.

## Install

Ask Muse to install it:

> Install the mac-remote skill from https://github.com/dute-ai/muse-utils:
> clone it to ~/workspace/muse-utils and run install.sh.

Muse will then guide you through the one-time Mac setup: enabling Remote
Login, joining the same Tailscale network, and authorizing an SSH key.
(Details: `../skills/mac-remote/references/setup.md`.)

## Usage

Once installed, just ask:

- "Run `uptime` on my Mac."
- "Start a Claude Code session in ~/myproject and call it `review`."
- "What's showing in the `review` session?"
- "Tell the `review` session to continue."

### Example: supervising a multi-agent workflow

Before: two terminal windows, constant context-switching, and a coding agent
silently stuck on a confirmation prompt you didn't notice for an hour.

Now, from one chat:

> Start Claude Code in ~/myproject as a `driver` pane and Codex as a
> `reviewer` pane, side by side in one window. Have the driver work through
> the refactor and the reviewer check each completed step. Watch both panes
> and notify me whenever either finishes a step, gets stuck, or needs a decision.

Muse runs the loop: it reads each pane's output, keeps the agents moving,
and only taps you when something actually needs you.

The `bin/mac-watch` helper does the polling behind that loop: it tracks
watched panes and shows what's changed in each. Muse reads the report
and makes the call — whether a pane's agent needs input, finished a step, or
stalled — and only taps you when something actually needs you.

The skill ships three helpers:

- `bin/mac-ssh` — SSH transport to the Mac over the Tailscale tunnel proxy
- `bin/mac-tmux` — tmux panes and sessions: `list`, `new`, `split`, `panes`,
  `layout`, `see`, `send`, `key`, `kill`
- `bin/mac-watch` — watch panes; report CHANGED / QUIET / GONE

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
state/                      your config + SSH keys (gitignored, created by install.sh)
```

## Development

The repo is the source of truth. `install.sh` cleanly reinstalls the skill
into `~/workspace/skills/mac-remote/` without touching `state/`. Edit in
the repo, reinstall, and push.
