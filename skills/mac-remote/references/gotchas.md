# Gotchas learned the hard way

## SSH identity lookup
On this VM, shell commands run as root, and `ssh` resolves identity files via
getpwuid (`/root/.ssh`), not `$HOME` (`/home/hatch/.ssh`). A bare `ssh` never
finds the real key — `bin/mac-ssh` always passes `-i` explicitly. Don't
"fix" this by copying keys to `/root/.ssh`; it doesn't persist.

## Persistence
Only `~/workspace/` survives VM restarts. Keys, config, and the helpers'
state live there. Anything under `/root`, `/tmp`, or `/home/hatch/.ssh`
should be treated as ephemeral.

## The tunnel proxy
- The tailnet is reachable only through the runtime HTTP proxy with CONNECT,
  port changed to **3130** (that port selects Tailscale). `bin/mac-ssh`
  derives host and credentials from `$HTTPS_PROXY`.
- TCP only. `ping` and anything UDP/ICMP never reach the tailnet — a failed
  ping means nothing. Opening a TCP connection is the only reachability test.
- The first tunnel connection needs the user's approval. It may hang while
  they answer: let it sit, don't time out or retry in a loop.

## Non-interactive PATH
SSH/tmux sessions don't load the user's login shell, so `/opt/homebrew/bin`
is missing from PATH. Homebrew CLIs installed as `#!/usr/bin/env node`
wrappers (e.g. Codex) then die with `env: node: No such file or directory`.
`bin/mac-tmux new` sets an explicit PATH (`/opt/homebrew/bin:...`) on every
session command. tmux `new-session` inherits the invoking client's
environment, which is why the prefix works.

## send-keys Enter race
`tmux send-keys -l <text>` followed immediately by `send-keys Enter` can
drop the Enter: the TUI is still rendering the pasted text when Enter
arrives, so the prompt sits unsubmitted. `bin/mac-tmux send` waits 0.7s
between typing and Enter.

## Terminal.app AppleScript (no-tmux fallback)
Apple Events to Terminal.app work over SSH without Accessibility permission
(unlike System Events UI scripting, which is denied):
- Launch / run: `osascript -e 'tell application "Terminal" to do script "cmd"'`
- Read a tab: `tell application "Terminal" to get contents of tab 1 of window id <id>`
- Type into a live tab: `do script "<text>" in <tab>` (text + Return; no raw keys)
- Find tabs by `custom title` — but TUIs like Claude Code overwrite it
  (becomes "✳ Claude Code"), so list windows first and match by id.
Write multi-line AppleScript via a heredoc to a temp `.scpt` file; nested
quoting through ssh → zsh → osascript is not worth fighting inline.

## What doesn't work over SSH
- `screencapture`: "could not create image from display" — no display attached.
- Keystroke/click injection via System Events: "not allowed to send keystrokes".
- ChatGPT.app's AppleScript dictionary is Standard Suite only — no scriptable
  "new conversation". Check `sdef /Applications/<App>.app` before assuming.
