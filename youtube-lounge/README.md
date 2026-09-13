# youtube-lounge

Control YouTube playback on any TV from the command line — or from your
AI assistant — using YouTube's unofficial **Link with TV code** lounge
protocol. No same-network requirement: commands go from here through
YouTube's cloud to the TV.

Part of a [collection of Muse utilities](https://github.com/dute-ai/muse-utils).

## Setup

The script is standalone — no install step, just run `./yt-tv` directly.

Prerequisites: Python 3, `pip install requests yt-dlp`.

1. On the TV, open the YouTube app → **Settings** → **Link with TV code**.
   A 12-digit code appears.
2. Pair it (do this once per TV; pairing is permanent):

```bash
./yt-tv --tv "Living Room" pair 123456789012
```

Credentials are stored in `~/.config/youtube-lounge/` (override with
`$YOUTUBE_LOUNGE_DIR`). Lounge tokens last ~14 days and refresh
automatically before each command.

## Usage

```bash
./yt-tv --tv "Living Room" play dQw4w9WgXcQ        # video id, watch URL, or search text
./yt-tv --tv "Living Room" play "lofi hip hop radio"
./yt-tv pause | resume | stop | status
./yt-tv search "Dwarkesh Patel AI 2027"             # resolve a title to an id
```

If you have exactly one paired TV you can drop `--tv`; otherwise set a
default with `$YOUTUBE_LOUNGE_TV`. The sender name shown on the TV
defaults to `Muse`, override with `--name` or `$YOUTUBE_LOUNGE_NAME`.

The YouTube app must already be open on the TV — this tool doesn't launch
apps, it drives playback. If the TV is asleep, wake it / open YouTube
manually first.

## Watch history

Playback started through this remote is attributed to whichever Google
account the TV's YouTube app is signed into. The pairing here is
anonymous, so for videos to appear in *your* YouTube history, link the TV
to your account first from your phone: YouTube app → Settings → Link with
TV code, while signed in. (Once linked, this remote's playback shows up
in history; re-link if the TV is ever signed out or reset.)

## Protocol notes

From public wire specs (e.g. the MIT-licensed ytcast project):

- Bodies are `application/x-www-form-urlencoded` with
  `Origin: https://www.youtube.com`.
- `bind` responses are `<len>\n<JSON>` chunks; the session id arrives as
  `["c", sid, "", 8]`, `gsessionid` as `["S", gsessionid]`.
- Commands go on `req0__sc` — note the **double** underscore — while
  arguments use a single underscore (`req0_videoId`).
- Use a fresh `bind` per command batch; rebind on HTTP 400/404, refresh
  the lounge token on 410.
- Every POST carries a form body (`count=0`/`count=1`): some
  networks/proxies answer empty-body POSTs with 411.
- After `setPlaylist`, the `videoId` in a status snapshot can lag one
  video behind; `duration`/`currentTime` reflect the new video.

## As a Muse skill

`../skills/youtube-lounge/SKILL.md` documents this for an AI agent; run
`./install.sh` at the repo root to install it alongside the other skills.
