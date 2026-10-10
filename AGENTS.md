# Hiresnix Labs — agent instructions

Single source of truth for coding agents (Claude Code reads it through `CLAUDE.md`, which imports this file).

## What this repo is

**Hiresnix Labs**: hands-on DevOps labs in a real Linux terminal, graded on real machine state. One lab server (`src/`), one
lab catalog (`labs/`), three ways to run it:

- **Native** — `./start.sh` on Linux or WSL (`start.bat` on Windows calls it inside WSL). No Docker. `LAB_PROFILE=local`,
  listens on `127.0.0.1` only, lab shells run as the invoking user.
- **Docker** — `./start.sh --docker` / `docker compose up` (the default on macOS). Hardened container, one unprivileged
  user per session.
- **Hosted** — the same image with `LAB_PROFILE` unset (= hosted): invite codes, per-IP limits, same-origin guard.

Roadmap: the same engine will also serve **candidate assessments** for Hiresnix. Anything that weakens grading integrity or
isolation matters more here than in a pure learning product.

## Layout

```
start.sh start.bat   one-command start (native on Linux/WSL, Docker on macOS)
src/        server.js (createApp factory) config.js (profiles) lib.js sandbox.js loader.js util.js lint.js ui.js pages.js stats.js banner.js markdown.js
public/     lab.js progress.js home.js, the stylesheets (served as /app.css), logo/hiresnix-logo.svg
labs/       all lab content (track.yaml + lab folders) + lib.sh
scripts/    validate-labs.js lab-check.js new-lab.js lint-labs.js check-hygiene.js docker-run.js
test/       unit/ integration/         deploy/smoke-test.py         docs/ authoring.md ai-authoring.md
```

## Conventions

- **Release notes:** every user-visible change gets a line in `CHANGELOG.md` under `[Unreleased]`; when releasing, rename it
  to the version and date and bump `version` in `package.json` and `package-lock.json`.
- **Brand hygiene:** this is a rebranded fork. The upstream project is credited only in `LICENSE` and `NOTICE.md`;
  `npm run check:hygiene` (CI too) fails if its name comes back anywhere else. Keep the original copyright line in `LICENSE`.
- **Both run paths must keep working.** A lab may only use tools that the `Dockerfile` installs **and** that `start.sh`'s
  `TOOLS` list installs; add a tool to both. CI proves every lab natively (non-root, no Docker) and in the image.
- `npm test` must not get worse. On Linux/WSL the full suite runs natively except the root-only isolation tests, which run in
  the image: `docker run --rm -v "$PWD/test:/app/test:ro" <image> sh -c 'node --test --test-force-exit test/unit/*.test.js test/integration/*.test.js'`.
  Don't claim terminal behaviour is verified unless a real pty ran it (CI, the image, native Linux, or `deploy/smoke-test.py`).
- No secrets, account IDs or ARNs in committed files or CI logs. Don't commit, push or deploy unless asked.

## Engine invariants (security — don't weaken without a test that says why)

- A lab page is a seatless shell. Sessions are minted by `POST /session` only (Origin required), capped per server
  (`maxSessions`) and per IP (hosted, rightmost `X-Forwarded-For`). Pending tokens expire in 15 s.
- Guards: the local profile accepts only loopback `Host`/`Origin` (DNS-rebinding/CSRF defence) and **listens on 127.0.0.1**
  unless `LISTEN_HOST` says otherwise (only the container sets `0.0.0.0`, and publishes on the host's loopback). Hosted
  requires `Origin == Host` (or a listed origin). POST and WebSocket must carry an Origin.
- In the image every session runs as its **own unprivileged user** (`LAB_UID` base + slot, `lab0..lab39`) in a `0700` home;
  the command log is private to it; `labs/**/solutions/` is root-only. Cleanup kills the session and every process of its
  uid. Natively there is no uid drop (`LAB_UID` unset): never point a native run at other people.
- Ctrl+C / SIGTERM ends every live session first (its processes and home are cleaned up), then exits.
- Checks grade state, not clicks. A task needs `checks/<id>.sh` **and** `solutions/<id>.sh`; `node scripts/validate-labs.js`
  proves each check fails before and passes after its solution. See `docs/authoring.md`.
- Brand/chrome (header, logo, optional `SITE_URL` link, tokens, the prompt-mark sprite) lives only in `src/ui.js` +
  `public/{tokens,components,lab}.css`. Don't copy it into another page.
- **Design brief: the Hiresnix logo's blues.** Deep navy ground with a soft fixed blue wash, hairlines instead of fills,
  Sora for display and Inter for the interface, and one brand gradient (the logo's cyan to royal blue to indigo) used only
  on the headline accent, the primary button and thin progress rules. Logo files: `public/logo/hiresnix-{mark,wordmark,icon}.png`
  (the wordmark is the dark-background version: white letters, blue X). No glows, offset shadows
  or filled chips. Motion budget: a short fade-in and small hover lifts; always honour `prefers-reduced-motion`.
- **Command guide:** `labs/glossary.yaml` (+ `labs/<track>/glossary.yaml`) explains commands in simple English; a step shows
  the entries for the commands its text puts in `backticks`. Examples must be generic, never a task's answer.
- **The catalog is the site:** the home page, track pages and breadcrumbs are built from `labs/<track>/track.yaml` and the
  lab folders.

## Adding a lab (the systematic path)

A lab PR touches only `labs/**`. Procedure and brief: `docs/ai-authoring.md` (human version: `CONTRIBUTING.md`).
```
npm run lab:new -- <track> <lab-id> "Title"                      # scaffolds AND registers it in track.yaml
npm run lab:lint -- <track>/<lab-id> --json                      # static, any OS; fix every finding
npm run lab:check -- <track>/<lab-id>                            # lint + fail-before/pass-after proof (native on Linux/WSL)
```
Never hand-edit `track.yaml` for a lab and never edit tests to make a lab pass (counts are derived from the catalog).
