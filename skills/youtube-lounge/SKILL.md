---
name: "youtube_lounge"
description: "Play, pause, resume, stop, and check status of YouTube videos on the user's TV(s) via the 'Link with TV code' lounge protocol. Use when the user asks to play a video on a TV, control TV playback, or check what's playing."
---

# youtube-lounge

## Purpose
Drive YouTube playback on TVs that are paired via YouTube's "Link with TV
code" lounge protocol. Commands travel through YouTube's cloud, so the TV
does not need to be on the same network — but the YouTube app must already
be open on the TV (this tool cannot launch apps or wake the TV).

## Tooling
The `yt-tv` script lives next to this file (installed at
`~/workspace/skills/youtube-lounge/yt-tv`; executable, Python 3,
needs `requests` and `yt-dlp`). Always use it; never hand-roll the lounge
protocol.

- `yt-tv --tv "Name" pair <12-digit-code>` — one-time pairing per TV; the
  code comes from the TV's YouTube app → Settings → Link with TV code.
- `yt-tv --tv "Name" play <id|url|search-text>` — replace queue, play now.
  Accepts a raw 11-char video id, a watch/shorts URL, or free text (resolved
  via `yt-dlp ytsearch`, first result).
- `yt-tv --tv "Name" pause | resume | stop | status`
- `yt-tv search <query>` — print top 3 `id<TAB>title` matches.

## Config
- Credentials: `~/.config/youtube-lounge/<tv-slug>.json`
  (`$YOUTUBE_LOUNGE_DIR` overrides). Tokens last ~14 days, auto-refresh.
  **Never commit these files or print their contents.**
- TV selection: `--tv NAME`, else `$YOUTUBE_LOUNGE_TV`, else the only paired
  TV if there is exactly one.
- Sender name shown on the TV: `--name` or `$YOUTUBE_LOUNGE_NAME`
  (default `Muse`).

## Operating Rules
1. Pairing is anonymous: playback is attributed to whatever Google account
   the TV's YouTube app is signed into. For videos to land in the user's
   watch history, the TV must be linked to their account from their phone
   (YouTube app → Settings → Link with TV code, while signed in). If the TV
   is ever signed out/reset, history attribution stops until they re-link —
   the remote itself cannot fix that.
2. If `status` reports "no playback state" the YouTube app is probably
   closed or in menus — ask the user to open YouTube on the TV; do not
   debug blindly.
3. After a `play`, the `videoId` in a status snapshot can lag one video
   behind; trust `duration`/`currentTime` for what's actually playing.
4. A fresh `bind` is used per command batch inside the script; HTTP
   400/404 → rebind, 410 → token refresh are handled automatically.
5. This repo's `install.sh` installs this skill to `~/workspace/skills/`.
