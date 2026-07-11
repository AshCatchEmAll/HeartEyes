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

<!-- TODO: add a screenshot/GIF of a break overlay here — it's the single most
     valuable thing for the README and for App-store/AI listings. -->

## Why HeartEyes

Staring at a screen all day tires your eyes. Optometrists recommend the
**20‑20‑20 rule** — every 20 minutes, look 20 feet away for 20 seconds — to ease
digital eye strain. HeartEyes keeps that rhythm for you, and makes the break
something you'll actually enjoy instead of dismiss.

- 🕒 **The 20‑20‑20 rule, automated** — a countdown lives in your menu bar.
- 🖼️ **Your GIF, full screen** — pick any local GIF or paste a Giphy link.
- 🖥️ **Every display** — the overlay sits above full‑screen apps and the menu bar.
- 🔒 **Private & offline** — no account, no telemetry, no cloud. Everything stays on your Mac.
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

> **Homebrew & a notarized download are on the roadmap.** Until then, the app is
> ad‑hoc signed, so on first launch macOS may ask you to confirm in
> **System Settings → Privacy & Security**.

## Menu

- **Take a break now** (⌘B) — trigger a break immediately
- **Pause / Resume** (⌘P)
- **Break GIF…** — one window to pick what you see during breaks: drop a file on the
  preview, browse for one, or paste a **Giphy** / **Tenor** / `.gif` link. Share links
  resolve to the real image, download, and cache locally. If you've already copied a
  link or a GIF, it's offered to you in one click.
- **Work interval** — 10 / 20 / 30 / 45 / 60 min (plus a 1‑min test mode)
- **Break length** — 10 / 20 / 30 / 60 sec
- **Launch at login** — start HeartEyes automatically
- **Quit** (⌘Q)

During a break, press **Esc** (or click **Skip**) to end it early.

## Privacy

HeartEyes has **no account, no telemetry, and no cloud**. Your GIF, interval, and
break length are stored locally and remembered between launches. The only network
request it ever makes is downloading a GIF you explicitly paste in.

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
