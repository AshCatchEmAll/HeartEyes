# Security Policy

## Supported versions

HeartEyes ships as a single app; the **latest release** is the only supported
version. Please update before reporting.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Instead, report privately via one of:

- GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
  (**Security → Report a vulnerability** on the repo), or
- Email **security@hearteyes.app** with details and steps to reproduce.

We aim to acknowledge reports within **72 hours** and to ship a fix or mitigation
as quickly as the severity warrants. We're happy to credit you in the release
notes unless you'd prefer to remain anonymous.

## Scope & threat model

HeartEyes is **local‑first**: no accounts, no telemetry, no servers. Its only
network activity is downloading a GIF the user explicitly provides (e.g. a
pasted Giphy link). Reports we're especially interested in:

- Ways the app could be made to execute untrusted code or write outside its
  sandbox from a crafted GIF/URL.
- Local privilege or data‑exposure issues arising from how settings/caches are
  stored.
