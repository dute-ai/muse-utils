# mac-remote

Give your Muse a remote terminal on your Mac. Once set up, Muse connects
over Tailscale SSH and can run commands, start persistent terminal
sessions, read their output, and interact with them — for example,
supervising Claude Code or Codex agents working side by side in tmux
panes, and only interrupting you when something finishes, gets stuck, or
needs a decision.

Part of the [muse-utils](https://github.com/dute-ai/muse-utils) collection.

## Use it

Paste into Muse:

> Install the mac-remote skill from https://github.com/dute-ai/muse-utils:
> clone it to ~/workspace/muse-utils and run install.sh. Then walk me
> through the one-time Mac setup: enabling Remote Login, joining the same
> Tailscale network, and authorizing an SSH key.

After that, just ask:

- "Run `uptime` on my Mac."
- "Start a Claude Code session in ~/myproject and call it `review`."
- "What's showing in the `review` session?"
- "Start Claude Code in ~/myproject as a `driver` pane and Codex as a
  `reviewer` pane, side by side in one window. Watch both and notify me
  whenever either finishes a step, gets stuck, or needs a decision."
