# Changelog

All notable changes to Hiresnix Labs are listed here. The format follows Keep a Changelog; versions follow SemVer.

## [Unreleased]

### Fixed
- Windows: `start.bat` failed with `execvpe(bash) failed` when the default WSL distribution was Docker Desktop's internal
  one, which has no bash. It now looks for a distribution with bash (the default, then Ubuntu, then any other) and, if there
  is none, explains how to install Ubuntu. The Git Bash hand-over in `start.sh` does the same.

## [0.1.0] - 2026-10-10

First Hiresnix release, forked from an MIT-licensed lab engine (see NOTICE.md).

### Added
- `start.sh`: one command to run the labs. Native on Linux and WSL (no Docker): installs missing tools with `apt`, downloads a
  checksum-verified Node.js if none is installed, builds the terminal module, starts the server and opens the browser.
  On macOS it uses Docker Desktop and starts it automatically. `--docker` forces the container anywhere.
- `start.bat`: double-click start on Windows through WSL, with setup guidance when WSL is missing and a `docker` fallback.
- Graceful shutdown: Ctrl+C / SIGTERM ends every live lab session (processes and temporary homes) before exiting.
- CI job that proves every lab natively, as a non-root user, with no Docker, and smoke-tests the launcher.

### Changed
- Hiresnix branding: name, logo, terminal banner, and an amber-on-ink palette. The header site link and the source link are
  now optional settings (`SITE_URL`, `REPO_URL`).
- The local profile now listens on `127.0.0.1` by default (`LISTEN_HOST` overrides; the compose file sets `0.0.0.0` inside
  the container and still publishes on the host's loopback only). Running natively, a lab shell is never exposed to the network.
- The brand hygiene check now guards against the upstream name and works without a git checkout.
- Dependencies: dropped the serverless sandbox SDK (7 packages instead of 30).

### Fixed
- Networking labs: the `listening` check helper failed on machines without `/proc/net/tcp6` (IPv6 disabled), so four
  tasks could never pass there.

### Removed
- The upstream project's AWS, Terraform, serverless and split-hosting deployment setup, its deploy workflow and research notes.
