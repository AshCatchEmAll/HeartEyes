# Contributing to HeartEyes

Thanks for taking the time to contribute! HeartEyes is a small, dependency‑free
project and we'd like to keep it that way — lean, native, and easy to read.

## Ways to help

- 🐛 **Report bugs** — open an issue with steps to reproduce and your macOS version.
- 💡 **Suggest features** — open a feature request and tell us the problem it solves.
- 📝 **Improve docs** — the README or this guide.
- 🔧 **Send a pull request** — see below.

## Project layout

```
Sources/                  The macOS app — Swift + AppKit, no dependencies
  main.swift              Menu bar, timers, break overlay, blink nudges, GIF picker
  RestLedger.swift        Rest-history model + weekly aggregation (pure, unit-tested)
  ReflectionWindow.swift  The "This week…" reflection panel
Tests/                    RestLedger unit tests (run by ./test.sh)
build.sh                  Compiles a universal, ad‑hoc‑signed HeartEyes.app
.github/workflows/        CI (builds + tests the app) and the tagged Release
```

## Building the app

Requires **macOS 13+** and the Xcode command‑line tools (`xcode-select --install`).

```bash
./build.sh
open build/HeartEyes.app
```

There's no Xcode project — the app is a handful of Swift files compiled directly
with `swiftc`, on purpose. If you add a source file, update `build.sh` (and
`test.sh` if it's under test) to include it.

## Running the tests

```bash
./test.sh
```

## Pull request checklist

1. **Discuss first** for anything non‑trivial — open an issue so we agree on the
   approach before you invest time.
2. Keep changes **focused**; one concern per PR.
3. Match the surrounding Swift **style**. No new dependencies without discussion.
4. Make sure it **builds and tests**: `./build.sh` and `./test.sh`.
5. Update **docs** (README / CHANGELOG) when behavior changes.
6. Fill out the PR template and link the issue it closes.

## Guiding principles

HeartEyes is **local‑first, private, and offline** — no accounts, no telemetry,
no cloud. Contributions must preserve that. If a change would send data off the
user's Mac, it needs a strong justification and an explicit, opt‑in path.

## Code of Conduct

By participating you agree to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
