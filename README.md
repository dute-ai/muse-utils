# muse-utils

A collection of small [Muse](https://muse.ai) utilities — skills and scripts
that give your Muse useful powers. Install one or all of them.

## Utilities

- **[mac-remote](mac-remote/)** — a remote terminal on your Mac over Tailscale
  SSH, so Muse can run commands and supervise coding agents in tmux panes.
- **[youtube-lounge](youtube-lounge/)** — play, pause, and check YouTube on
  any TV via the "Link with TV code" lounge protocol.

## Install

Ask Muse to install from https://github.com/dute-ai/muse-utils:

> Install the skills from https://github.com/dute-ai/muse-utils: clone it to
> ~/workspace/muse-utils and run install.sh.

`install.sh` copies every skill under `skills/` into `~/workspace/skills/`
(clean reinstall; any existing `state/` is untouched). Each utility's README
covers its own one-time setup.

## Repository layout

```
install.sh            installs all skills into ~/workspace/skills/
skills/               the installable skills (one dir per skill)
mac-remote/           docs for the mac-remote utility
youtube-lounge/       the yt-tv remote script + its docs
state/                your machine-specific config + keys (gitignored)
```
