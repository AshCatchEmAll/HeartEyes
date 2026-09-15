# Changelog

All notable changes to HeartEyes are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Break routine** (optional, off by default). Give each break something to do. Choose
  how many breaks a routine spans (12, then it starts over), then place tasks on them:
  taking turns (push‑ups → squats → plank → …), every Nth break (water every 3rd), or on
  specific breaks (a 30‑minute walk on break 12). Each task has its own length and can
  carry a line and a GIF of its own for that break. Start from a built‑in routine or build
  your own in **Break routine…**; a live strip shows exactly what every break will be, the
  routine's span translates to hours at your interval, and the menu says what's up next.
  Only breaks you're actually shown count, and the count starts over each morning. Every
  break still protects its first seconds for your eyes — **Done** unlocks only after that.
  It adds no interruptions; it fills the ones you already take. The editor scrolls and
  fits any screen height.
- **Hard mode** — **Breaks can't be skipped** (off by default). The Skip button goes away
  and Esc becomes a three‑second hold, so a skip is a decision rather than a reflex. Calls
  and video still hold breaks exactly as before.
- **MCP server** — `HeartEyes --mcp` speaks the Model Context Protocol over stdio, so an
  agent such as Claude can set up a routine (tasks, placement, lines, GIF links), change the
  break screen, interval or break length, or read the week's reflection — on your request.
  Changes reach the running app immediately and are announced in the menu bar. Hard mode is
  deliberately not exposed. No dependencies; the only network use is fetching a GIF link.
  **Connect an agent…** in the menu shows the exact command or config snippet for your
  copy's location (Claude Code, Codex, or JSON for Claude Desktop, Cursor and others), with
  a Copy button, and warns if the app is running from a Gatekeeper temporary copy.
- **Preview a break** from the routine editor, and a one‑time preview after you set a
  routine up, so nothing on the break screen is a surprise.
- `HEARTEYES_SNAPSHOT=<dir>` writes the break screen to a PNG each second, for checking
  layouts without screen‑recording permission.

### Changed

- **This week…** now reads the rest ratio as *minutes of break for every hour at the
  screen* instead of a percentage, so a week with a daily walk and a week of plain
  20‑second breaks both read sensibly. It also names the break you skipped most, when one
  dominates. Long breaks are filed across the days they span.
- The break timer is now a deadline rather than a tick count, so a long break survives
  the display sleeping.
- After a break, HeartEyes keeps its own window in front if that's what you were in.

- **App icon.** A proper bundle icon — the sleepy 3D heart — now ships with the
  app, so HeartEyes shows its face in Finder and the Applications folder.

## [1.0.0] — 2026-07-11

The first public release. A native macOS menu-bar app that keeps the 20-20-20
rule for you — free, open source, private, and offline.

### Added

- **The break.** Every 20 minutes a full-screen overlay rises on _every_ display
  (above full-screen apps and the menu bar) with a depleting countdown ring and a
  “Look 20 feet away” prompt, then fades away. End early with Esc or Skip, take one
  on demand (⌘B), or pause the timer (⌘P).
- **Bring your own GIF.** Choose a local GIF or image, drag-and-drop, browse, or
  paste a Giphy, Tenor or direct `.gif` link — HeartEyes resolves it (following
  `og:image` for share links), downloads it with inline progress, caches it, and
  plays it full-size during every break. Revert to the default any time. Downloads
  are size-capped (40 MB) and check the HTTP status.
- **Gentle blink reminders** (optional, off by default). Wordless nudges every
  3/5/10 minutes in four styles — Hearts, Sparkles, Dewdrops, or Just the blink —
  shown from the menu bar or as a whole-screen eyelid. No banner, no sound, nothing
  to dismiss; Reduce Motion is respected.
- **Smart auto-pause** (on by default). Holds breaks while you’re on a call
  (microphone in use) or watching something full-screen — video players, Zoom
  screen-share, Keynote, PowerPoint, Google Slides — with a grace period after a
  call ends.
- **Natural breaks** (on by default). Skips a scheduled break when you’ve already
  been away from the keyboard long enough, so you’re only nudged when you’re
  actually at the screen.
- **Weekly reflection** — the “This week…” panel. An on-demand, on-device look back:
  your longest stretch without a break, how much of your screen time was rest,
  breaks taken vs. skipped, and time held during calls. Never a daily score.
- **Configurable rhythm.** Work interval of 10/20/30/45/60 minutes and break length
  of 10/20/30/60 seconds. Choices are remembered between launches.
- **Launch at login**, via `SMAppService`.
- **Private & offline by design.** No account, no telemetry, no cloud, no camera —
  and no microphone, screen-recording or accessibility permissions. Settings and a
  90-day, hourly-coarse rest history stay on your Mac, and the history is deletable
  in one click. The only network request is fetching a GIF you paste in.
- **Native & tiny.** A dependency-free Swift/AppKit app shipped as a universal
  binary (Apple silicon + Intel), menu-bar only with no Dock icon. macOS 13+.

[Unreleased]: https://github.com/AshCatchEmAll/HeartEyes/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/AshCatchEmAll/HeartEyes/releases/tag/v1.0.0
