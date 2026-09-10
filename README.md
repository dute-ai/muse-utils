# mac-remote

A [Muse](https://muse.ai) skill that lets your Muse drive your Mac: SSH into it
over Tailscale, and start/observe/interact with terminal sessions (tmux)
hosting coding agents like Claude Code or Codex.

This is the packaged version of a real late-night session: SSH key auth over
the Tailscale tunnel proxy, tmux `capture-pane` to *see* a session,
`send-keys` to *type into it* — plus every gotcha we hit along the way
(documented in `skills/mac-remote/references/gotchas.md` so you don't
rediscover them).

## Install

On your Muse VM:

```bash
git clone <this-repo> ~/workspace/mac-remote
~/workspace/mac-remote/install.sh
```

This copies the skill to `~/workspace/skills/mac-remote/` (where Muse's skill
search finds it) and creates `~/workspace/mac-remote/state/` for your
machine-specific config and SSH keys (gitignored — never commit it).

Then follow the one-time setup: `~/workspace/skills/mac-remote/references/setup.md`
(enable Remote Login on the Mac, join Tailscale on both ends, generate a key,
trust it on the Mac, write `state/config`).

## Use

Once set up, just talk to Muse:

- "run `uptime` on my Mac"
- "start a Claude Code session in ~/myproject in tmux, named `review`"
- "what's showing in the `review` session?"
- "tell the `review` session to continue"

Or call the helpers directly:

```bash
skills/mac-remote/bin/mac-ssh 'uptime'
skills/mac-remote/bin/mac-tmux new review ~/myproject claude
skills/mac-remote/bin/mac-tmux see review
skills/mac-remote/bin/mac-tmux send review "continue"
skills/mac-remote/bin/mac-tmux key review C-c
```

## Layout

```
install.sh                  installs the skill into ~/workspace/skills/
skills/mac-remote/
  SKILL.md                  the skill: purpose, tooling, auth, operating rules
  bin/mac-ssh               SSH to the Mac over the Tailscale tunnel proxy
  bin/mac-tmux              tmux sessions: new / see / send / key / list / kill
  references/setup.md       one-time setup walkthrough
  references/gotchas.md     hard-won lessons (read before debugging)
state/                      YOUR config + keys (gitignored, created by install.sh)
```

## Requirements

- A Mac with Tailscale, Remote Login enabled, and tmux installed
  (`brew install tmux`)
- The Muse VM on the same Tailscale network

## Notes for hackers

- The repo is the source of truth; `install.sh` copies (cleanly reinstalls)
  into `~/workspace/skills/mac-remote/`. Edit in the repo, reinstall.
- Config resolution: env vars (`MAC_REMOTE_USER`, `MAC_REMOTE_HOST`,
  `MAC_SSH_KEY`, `MAC_REMOTE_TMUX`) win over `<state-dir>/config`.
