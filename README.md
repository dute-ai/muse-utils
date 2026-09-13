# muse-utils

Utilities for [Muse](https://muse.ai), built while working with it. Each
one is a skill: install it once, then tell Muse what you want in plain
language.

## Demo

Kuku watches the coding agents on my Mac while I'm away:

![Kuku supervising Codex and Claude in a Mac terminal](mac-remote/demo/kuku-supervises-coding-agents.mp4)

Two agents share one Mac terminal — Codex builds a small CLI, Claude reviews
it. Kuku watches both panes: it picks up the review findings, answers the
one design question from what it already knows about my preferences
(single-file, keep it simple), and guides the builder to fix and re-test.
The phone never buzzes.

| Utility | What it's for |
|---|---|
| [mac-remote](mac-remote/) | Give Muse a remote terminal on your Mac — run commands, supervise coding agents in tmux panes |
| [youtube-lounge](youtube-lounge/) | Control YouTube playback on your TV from a chat message |

## Install

Everything at once — paste into Muse:

> Install the skills from https://github.com/dute-ai/muse-utils: clone it
> to ~/workspace/muse-utils and run install.sh.

Or one utility at a time:

> Install just the mac-remote skill from
> https://github.com/dute-ai/muse-utils: clone it to ~/workspace/muse-utils
> and run install.sh mac-remote. Then walk me through the one-time Mac
> setup: enabling Remote Login, joining the same Tailscale network, and
> authorizing an SSH key.

> Install just the youtube-lounge skill from
> https://github.com/dute-ai/muse-utils: clone it to ~/workspace/muse-utils
> and run install.sh youtube-lounge. Then pair my TV using the 12-digit
> code I'll paste from the TV's YouTube app → Settings → Link with TV
> code (the code expires quickly, so I'll send it while it's on screen).

Each utility directory is self-contained: you can also grab just one of
them (e.g. only `youtube-lounge/`) and run the `install.sh` inside it —
no need to clone the whole repo.
