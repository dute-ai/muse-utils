# mac-remote

A [Muse](https://muse.ai) skill that gives your Muse a remote terminal on your Mac.

Muse connects to your Mac over SSH through Tailscale and can run commands,
start long-lived terminal sessions, read their output, and type into them —
useful for supervising coding agents such as Claude Code or Codex running on
your machine.

## Install

Only Muse can run commands on its VM, so installation is a prompt. Send your
Muse this:

> Install the mac-remote skill from https://github.com/dute-ai/mac-remote:
> clone it to ~/workspace/mac-remote and run install.sh.

Muse will install the skill and then walk you through the one-time Mac setup
(enabling Remote Login, joining the same Tailscale network, and trusting an
SSH key). The setup guide lives at `skills/mac-remote/references/setup.md`.

## Use

Once installed, just talk to Muse:

- "run `uptime` on my Mac"
- "start a Claude Code session in ~/myproject and call it `review`"
- "what's showing in the `review` session?"
- "tell the `review` session to continue"

The skill provides two helpers that Muse uses under the hood:

- `bin/mac-ssh` — SSH transport to the Mac over the Tailscale tunnel proxy
- `bin/mac-tmux` — tmux session control: `list`, `new`, `see`, `send`, `key`, `kill`

## Requirements

- A Mac with Tailscale installed, Remote Login enabled, and tmux (`brew install tmux`)
- The Muse VM on the same Tailscale network (covered during setup)

## Layout

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

## Configuration

Machine-specific settings resolve from environment variables first, then
`<state-dir>/config`:

| Variable | Meaning |
| -------- | ------- |
| `MAC_REMOTE_USER` | macOS username |
| `MAC_REMOTE_HOST` | Mac's Tailscale IP |
| `MAC_SSH_KEY` | SSH private key (default `<state-dir>/id_ed25519`) |
| `MAC_REMOTE_TMUX` | tmux binary (default `/opt/homebrew/bin/tmux`) |

## Development

The repo is the source of truth. `install.sh` cleanly reinstalls the skill
into `~/workspace/skills/mac-remote/` (your `state/` is untouched). Edit in
the repo, reinstall, and push.
