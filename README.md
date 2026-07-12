<div align="center">

# HeartEyes 😍

**A tiny native macOS menu-bar app for the 20‑20‑20 rule.**
Every 20 minutes, look at something 20 feet away for 20 seconds — HeartEyes gently
covers your screens with a GIF of your choice and a 20‑second countdown, then fades away.

[![CI](https://github.com/AshCatchEmAll/HeartEyes/actions/workflows/ci.yml/badge.svg)](https://github.com/AshCatchEmAll/HeartEyes/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Sponsor](https://img.shields.io/badge/♥-Sponsor-ff5b7c.svg)](https://github.com/sponsors/AshCatchEmAll)

[Website](https://hearteyes.app) · [Report a bug](https://github.com/AshCatchEmAll/HeartEyes/issues) · [Request a feature](https://github.com/AshCatchEmAll/HeartEyes/issues) · [Sponsor](#-support-the-project)

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
- 🖥️ **Every display** — the overlay sits above full‑screen apps and the menu bar.
- 👁️ **Gentle blink reminders** — optional, wordless nudges from the menu bar or a whole‑screen eyelid.
- 🎥 **Smart auto‑pause** — holds breaks during calls and full‑screen video, and skips one when you've stepped away.
- 📊 **Weekly reflection** — a private *This week…* look at your rest, computed on your Mac.
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
  how much of your screen time was rest, breaks taken vs. skipped, and time held during
  calls. On‑device and deletable — never a daily score.
- **Take a break now** (⌘B) — trigger a break immediately
- **Pause / Resume** (⌘P)
- **Break GIF…** — one window to pick what you see during breaks: drop a file on the
  preview, browse for one, or paste a **Giphy** / **Tenor** / `.gif` link. Share links
  resolve to the real image, download, and cache locally. If you've already copied a
  link or a GIF, it's offered to you in one click.
- **Work interval** — 10 / 20 / 30 / 45 / 60 min (plus a 1‑min test mode)
- **Break length** — 10 / 20 / 30 / 60 sec
- **Blink reminders** — off, or every 3 / 5 / 10 min, in four styles (Hearts, Sparkles,
  Dewdrops, Just the blink), shown from the menu bar or as a whole‑screen eyelid.
- **Hold breaks during calls & video** — smart auto‑pause; holds a break while a call
  or full‑screen video is going. On by default.
- **Count time away as a break** — skip a break when you've already been away from the
  keyboard. On by default.
- **Launch at login** — start HeartEyes automatically
- **Quit** (⌘Q)

During a break, press **Esc** (or click **Skip**) to end it early.

## Privacy

HeartEyes has **no account, no telemetry, and no cloud** — and **no camera** or special
permissions to grant. Your GIF, settings, and a 90‑day rest history all live on your Mac
(the history is deletable in one click). The only network request it ever makes is
downloading a GIF you explicitly paste in.

## Contributing

Issues and PRs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and our
[Code of Conduct](CODE_OF_CONDUCT.md). The whole app lives in
[`Sources/`](Sources/) — a handful of dependency‑free Swift files.

## 💙 Support the project

HeartEyes is free and open source, and always will be — sponsoring simply funds
new work and keeps it independent. It's **never a paywall on your eye health**.

- **[GitHub Sponsors](https://github.com/sponsors/AshCatchEmAll)** — monthly or one‑time
- Or sponsor from the [website](https://hearteyes.app/#sponsor)

## License

[MIT](LICENSE) © 2026 - AshCatchEmAll built with love for tired eyes.
