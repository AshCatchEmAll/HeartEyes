<div align="center">

<img src="assets/logo.png" alt="HeartEyes" width="140" height="140">

# HeartEyes 😍

**A tiny native macOS menu-bar app for the 20‑20‑20 rule.**
Every 20 minutes, look at something 20 feet away for 20 seconds — HeartEyes gently
covers your screens with a GIF of your choice and a 20‑second countdown, then fades away.

[![CI](https://github.com/AshCatchEmAll/HeartEyes/actions/workflows/ci.yml/badge.svg)](https://github.com/AshCatchEmAll/HeartEyes/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Stars](https://img.shields.io/github/stars/AshCatchEmAll/HeartEyes?style=flat&logo=github&color=f5a623)](https://github.com/AshCatchEmAll/HeartEyes)

[Website](https://hearteyez.netlify.app) · [Report a bug](https://github.com/AshCatchEmAll/HeartEyes/issues) · [Request a feature](https://github.com/AshCatchEmAll/HeartEyes/issues) · [Star it ⭐](https://github.com/AshCatchEmAll/HeartEyes)

</div>

<p align="center">
  <img src="https://github.com/user-attachments/assets/007ef759-e03c-497b-932b-a9c711016e98" alt="HeartEyes: pick 'Take a break now' and the break overlay dims the screen with your GIF and a 20-second countdown" width="760">
</p>

## Why HeartEyes

Staring at a screen all day tires your eyes. Optometrists recommend the
**20‑20‑20 rule** — every 20 minutes, look 20 feet away for 20 seconds — to ease
digital eye strain. HeartEyes keeps that rhythm for you, and makes the break
something you'll actually enjoy instead of dismiss.

- 🕒 **The 20‑20‑20 rule, automated** — a countdown lives in your menu bar.
- 🖼️ **Your GIF, full screen** — pick any local GIF or paste a Giphy/Tenor link.
- ✍️ **Or your own words** — a list of quotes instead, one on screen each break.
- 🖥️ **Every display** — the overlay sits above full‑screen apps and the menu bar.
- 👁️ **Gentle blink reminders** — optional, wordless nudges from the menu bar or a whole‑screen eyelid.
- 🎥 **Smart auto‑pause** — holds breaks during calls and full‑screen video, and skips one when you've stepped away.
- 🏃 **Break routine** — optional: give each break something to do. Say how many breaks a routine spans, place tasks on them — taking turns, every 5th, or on break 20 — each with its own length, a line of your own, and a GIF of its own. Adds nothing new; it fills the breaks you already take.
- 🔒 **Hard mode** — optional: breaks can't be skipped with a reflex. Hold Esc for three seconds if you really must.
- 📊 **Weekly reflection** — a private *This week…* look at your rest, computed on your Mac.
- 🤖 **Works with your agent** — a built‑in MCP server lets Claude (or any MCP client) set up a routine, pick GIFs and lines per task, or read your week — on your say‑so.
- 🔒 **Private & offline** — no account, no telemetry, no cloud, no camera. Everything stays on your Mac.
- 🪶 **Tiny & native** — dependency‑free Swift (AppKit). Universal binary, macOS 13+.
- 💙 **Free & open source, forever** — MIT licensed.

## Install

### Build from source

Requires macOS 13+ and the Xcode command‑line tools (`xcode-select --install`).

```bash
git clone https://github.com/AshCatchEmAll/HeartEyes.git
cd HeartEyes
./build.sh
open build/HeartEyes.app
```

Install it permanently:

```bash
cp -R build/HeartEyes.app /Applications/
```

There's no Dock icon — look for the heart mark and its **`20:00`** countdown in your
menu bar.

> **A one‑click, notarized download and a Homebrew cask are on the roadmap** —
> ⭐ star the repo to help get there. Building from source (above) runs with **no
> Gatekeeper prompt**, since a locally built app isn't quarantined.

## Menu

- **This week…** — a private weekly reflection: your longest stretch without a break,
  minutes of break for every hour at the screen, breaks taken vs. skipped, and time held
  during calls. On‑device and deletable — never a daily score.
- **Take a break now** (⌘B) — trigger a break immediately
- **Pause / Resume** (⌘P)
- **Break screen…** — one window to pick what you see during breaks, either
  **a picture** or **your words**. For a picture: drop a file on the preview, browse
  for one, or paste a **Giphy** / **Tenor** / `.gif` link. Share links resolve to the
  real image, download, and cache locally. If you've already copied a link or a GIF,
  it's offered to you in one click. For words: type a quote per line — anything that
  gets you out of the chair — and a different one fills the screen each break.
- **Break routine…** — off by default. Give each break something to do. Choose how many
  breaks the routine spans (say 12, then it starts over), then add tasks and place them:
  **taking turns** (10 push‑ups → 10 squats → hold a plank → …), **every Nth break**
  (water every 3rd), or **on specific breaks** (a 30‑minute walk on break 12). Each task
  has its own length, and can carry a line of your own and a GIF of its own for that
  break. Start from a built‑in routine or build your own; a live strip shows exactly what
  every break will be, and the menu always says what's up next. Counts only breaks you're
  actually shown, and starts over each morning. Every break still protects its first
  seconds for your eyes — **Done** only unlocks after that.
- **Work interval** — 10 / 20 / 30 / 45 / 60 min (plus a 1‑min test mode)
- **Break length** — 10 / 20 / 30 / 60 sec
- **Blink reminders** — off, or every 3 / 5 / 10 min, in four styles (Hearts, Sparkles,
  Dewdrops, Just the blink), shown from the menu bar or as a whole‑screen eyelid.
- **Hold breaks during calls & video** — smart auto‑pause; holds a break while a call
  or full‑screen video is going. On by default.
- **Count time away as a break** — skip a break when you've already been away from the
  keyboard. On by default.
- **Breaks can't be skipped** — hard mode, off by default. The Skip button goes away; to
  get out you hold **Esc** for three seconds, so a skip is a decision rather than a reflex.
  Calls and video still hold breaks as before.
- **Launch at login** — start HeartEyes automatically
- **Connect an agent…** — the command or config snippet that points Claude Code, Codex,
  Claude Desktop or any MCP client at HeartEyes' built‑in server, with a Copy button.
- **Quit** (⌘Q)

During a break, press **Esc** (or click **Skip**) to end it early. With a routine on, a
**Done** button unlocks once the eye‑rest part is over — for when the push‑ups are done
before the timer is.

## Let your agent set it up

HeartEyes has a built‑in [MCP](https://modelcontextprotocol.io) server, so an agent can
configure it for you: *"make me a desk‑workout routine for a 6‑hour day, with water every
third break and a walk at the end"*, *"give the walk a GIF of a forest"*, *"how did my week
go?"*. It's the same binary with a flag — no extra install.

The easiest way: **Connect an agent…** in the menu shows the exact command or snippet
for wherever your copy of HeartEyes lives — Claude Code, Codex, or JSON for Claude
Desktop, Cursor and others — with a Copy button. Or by hand:

**Claude Code**

```bash
claude mcp add hearteyes -- /Applications/HeartEyes.app/Contents/MacOS/HeartEyes --mcp
```

**Claude Desktop** (or any MCP client) — add to its `mcpServers`:

```json
{
  "hearteyes": {
    "command": "/Applications/HeartEyes.app/Contents/MacOS/HeartEyes",
    "args": ["--mcp"]
  }
}
```

Tools: `get_settings`, `set_routine`, `set_break_screen`, `set_interval`,
`set_break_length`, `read_reflection`. Changes apply to the running app immediately and
you're told in the menu bar ("Your agent set up a new routine — next: 10 push‑ups").
Deliberately **not** exposed: hard mode — that's a decision you make by hand.

The server never opens a connection on its own; the only network use is fetching a GIF
link the agent passes on your behalf. `read_reflection` hands your weekly numbers to
whichever agent you asked — nothing else ever leaves the Mac.

## Privacy

HeartEyes has **no account, no telemetry, and no cloud** — and **no camera** or special
permissions to grant. Your GIF, settings, and a 90‑day rest history all live on your Mac
(the history is deletable in one click). The only network request it ever makes is
downloading a GIF you explicitly paste in.

## Contributing

Issues and PRs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and our
[Code of Conduct](CODE_OF_CONDUCT.md). The whole app lives in
[`Sources/`](Sources/) — a handful of dependency‑free Swift files.

## ⭐ If it helped, star it

HeartEyes is free and open source, and always will be — there's nothing to buy and
nothing to subscribe to. A star is the only thing it ever asks for: it's how the next
person with aching eyes finds this repo, and it's the signal that tells me what to
build next.

- ⭐ **[Star HeartEyes](https://github.com/AshCatchEmAll/HeartEyes)** — two seconds, costs nothing
- 🗣️ Send it to someone whose eyes are screaming by 5pm
- 🛠️ [Open an issue or a PR](https://github.com/AshCatchEmAll/HeartEyes/issues) — it's a handful of dependency‑free Swift files

## License

[MIT](LICENSE) © 2026 - AshCatchEmAll built with love for tired eyes.
