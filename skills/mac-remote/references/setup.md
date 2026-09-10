# One-time setup: this VM → the user's Mac

Do these once. Afterwards `bin/mac-ssh 'echo ok'` should print `ok`.

## 1. Tailscale on both ends

- The VM joins with `tailscale up` (the user approves the join URL — only they can).
- The Mac needs the Tailscale app / `tailscale` CLI on the same network.
- Confirm from the VM: `tailscale status` lists the Mac. Note its Tailscale IP
  (e.g. `100.100.226.1`; on the Mac, `tailscale ip`). There is no MagicDNS here —
  always address machines by tailnet IP.

## 2. SSH on the Mac

On the Mac, as the user who will own the sessions:

1. System Settings → General → Sharing → turn on **Remote Login**
   (or `sudo systemsetup -setremotelogin on`).
2. If Remote Login is restricted to specific users, add that username.
3. Keep the Mac awake while you need access (sleep kills reachability).

## 3. Keypair on the VM

```bash
mkdir -p ~/workspace/mac-remote/state
ssh-keygen -t ed25519 -f ~/workspace/mac-remote/state/id_ed25519 -N "" -C "muse-vm"
cat ~/workspace/mac-remote/state/id_ed25519.pub
```

Keys must live under `~/workspace/` — it is the only tree that survives VM
restarts. Never commit `state/` (it is gitignored); never paste the private key
anywhere.

## 4. Trust the key on the Mac

On the Mac, run once (as the same user):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "<paste the public key line here>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Verify from the VM that the key actually landed, e.g.:

```bash
bin/mac-ssh 'whoami'
```

but `bin/mac-ssh` needs step 5 first — so for the very first check, use the long
form or just trust the file perms (`~/.ssh` 700, `authorized_keys` 600, owned by
the user, key on one unbroken line).

## 5. Write the state config

`~/workspace/mac-remote/state/config` (or wherever `MAC_REMOTE_STATE_DIR`
points), `KEY=VALUE` lines:

```bash
MAC_REMOTE_USER=gqchen          # the macOS username from step 2
MAC_REMOTE_HOST=100.100.226.1   # the Tailscale IP from step 1
# MAC_SSH_KEY=...               # default: <state-dir>/id_ed25519
# MAC_REMOTE_TMUX=...           # default: /opt/homebrew/bin/tmux
```

## 6. Test

```bash
bin/mac-ssh 'echo ok; whoami; hostname'
bin/mac-tmux list
```

If the Mac has tmux (`command -v tmux` there), you're done. If not,
`bin/mac-ssh 'brew install tmux'` — or fall back to the Terminal.app
AppleScript patterns in `references/gotchas.md`.
