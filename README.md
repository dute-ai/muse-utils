# mac-remote

Give your Muse a remote terminal on your Mac.

`mac-remote` is a [Muse](https://muse.ai) skill that connects Muse to your Mac
over SSH via Tailscale. Muse can run commands, start persistent terminal
sessions, read their output, and interact with them — for example, to
supervise coding agents like Claude Code or Codex running on your machine.

## Install

Ask Muse to install it:

> Install the mac-remote skill from https://github.com/dute-ai/mac-remote:
> clone it to ~/workspace/mac-remote and run install.sh.

Muse will then guide you through the one-time Mac setup: enabling Remote
Login, joining the same Tailscale network, and authorizing an SSH key.
(Details: `skills/mac-remote/references/setup.md`.)

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

> Start Claude Code in ~/relay, call the session `driver`, and have it work
> through the refactor. Start Codex in ~/relay, call it `reviewer`, and have
> it review each completed step. Watch both sessions and notify me whenever
> either finishes a step, gets stuck, or needs a decision.

Muse runs the loop: it reads each session's output, keeps the agents moving,
and only taps you when something actually needs you.

The skill ships two helpers:

- `bin/mac-ssh` — SSH transport to the Mac over the Tailscale tunnel proxy
- `bin/mac-tmux` — tmux session management: `list`, `new`, `see`, `send`, `key`, `kill`

## Requirements

- Mac with Tailscale installed, Remote Login enabled, and tmux (`brew install tmux`)
- Muse VM on the same Tailscale network (handled during setup)

## Repository layout

```
install.sh                  installs the skill into ~/workspace/skills/
skills/mac-remote/
  SKILL.md                  the skill: purpose, tooling, auth, operating rules
  bin/mac-ssh               SSH to the Mac over the Tailscale tunnel proxy
  bin/mac-tmux              tmux sessions: new / see / send / key / list / kill
  references/setup.md       one-time setup walkthrough
  references/gotchas.md     SSH/tmux/AppleScript pitfalls and how they're handled
state/                      your config + SSH keys (gitignored, created by install.sh)
```

## Development

The repo is the source of truth. `install.sh` cleanly reinstalls the skill
into `~/workspace/skills/mac-remote/` (your `state/` is untouched). Edit in
the repo, reinstall, and push.
