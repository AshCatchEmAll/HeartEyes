# Changelog

All notable changes to HeartEyes are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
