<p align="center"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/hiresnix-logo-dark.png">
  <img src="docs/hiresnix-logo.png" alt="Hiresnix" width="420">
</picture></p>

# Hiresnix Labs

**Learn DevOps by doing: a real Linux terminal, real files, and every task graded on what actually happened.**

19 labs · 105 graded tasks · every task proven solvable by a script.

Not a simulator and not a quiz. Each task runs a check script against the real state of a real Linux shell: are the files
there, is the git history right, is the process running, is the port listening. Labs are plain YAML and shell scripts, so
anyone on the team can write one.

## Run it on your machine

| Your machine | What to do | Docker? |
|---|---|---|
| **Windows** | Double-click **`start.bat`** | No — runs in WSL, which is built into Windows |
| **Linux** | `./start.sh` | No |
| **macOS** | `./start.sh` | Yes — Docker Desktop, started for you |

Your browser opens at **http://localhost:8080**. Press `Ctrl+C` (or close the window) to stop; everything done in a lab is
thrown away with its temporary folder.

**First run** takes a minute or two: the script installs what is missing and remembers it.

- **Windows:** if WSL is not set up yet, `start.bat` tells you how: run `wsl --install` in an Administrator terminal,
  restart, create your Ubuntu user, then double-click `start.bat` again.
- **Linux / WSL:** missing command-line tools (git, jq, dig, netcat, a compiler for the terminal module, ...) are installed
  with `apt`, so `sudo` asks for your password once. If Node.js 20+ is not installed, the script downloads Node.js into
  `~/.cache/hiresnix-labs` (checksum-verified). Other package managers: the script prints the package list to install.
- **macOS:** labs need a Linux kernel, so they run in Docker Desktop. Install it once; the script opens it and waits.

Options:

```bash
LABS_PORT=9090 ./start.sh     # another port, then open http://localhost:9090
NO_BROWSER=1 ./start.sh       # don't open the browser
./start.sh --docker           # use Docker on Linux too (stronger isolation, see below)
./start.sh stop               # stop a Docker run from another terminal
```

On Windows, `start.bat docker` uses Docker Desktop instead of WSL.

### Native mode vs Docker mode

| | Native (Linux, WSL) | Docker (macOS, or `--docker`) |
|---|---|---|
| Install | Nothing besides what the script sets up | Docker Desktop |
| Lab shells run as | **your own user**, in a temporary folder | a separate unprivileged user per session, in a locked-down container |
| Listens on | `127.0.0.1` only | `127.0.0.1` only |

Native mode is the easy path for learning on your own machine. The lab shell is a real shell running as you, so it can see
your files like any terminal can. For anything where people other than you get a shell — a hosted deployment, candidate
assessments — use the container with its per-session users (see *Hosting* below).

**Troubleshooting**
- *Windows: `execvpe(bash) failed`:* WSL has no real Linux distribution (Docker Desktop's internal one does not count). Run `wsl --install -d Ubuntu` in an Administrator terminal, create your user, and start again.
- *Windows: `WSL_E_DISTRO_NOT_FOUND` or labs start in the wrong Linux:* make Ubuntu the default with `wsl --set-default Ubuntu`, or pick one for the labs only: `set HIRESNIX_DISTRO=Ubuntu` then `start.bat`.
- *Port in use:* `LABS_PORT=9090 ./start.sh`.
- *The terminal module did not build:* the script needs `make`, `g++` and `python3`; it installs them with `apt`. Run it again after installing them yourself.
- *Slow first start on Windows:* the folder is on the Windows drive (`/mnt/c/...`), which WSL reads slowly. Copy it into your Linux home: in WSL, `cp -r . ~/hiresnix-labs && cd ~/hiresnix-labs && ./start.sh`.
- *`bad interpreter` or `\r` errors:* Windows line endings got into the scripts. `.gitattributes` prevents this on a fresh clone; if you cloned earlier, run `git rm --cached -r . && git reset --hard`.

## What's in it

| Track | Labs | Time | What you do |
|---|---|---|---|
| **Linux Fundamentals** | 6 | 70 min | Find your way around a shell, manage files, understand permissions, chain commands, write scripts. |
| **Git Basics** | 3 | 34 min | Record history, work on branches, merge, and undo mistakes with the real git CLI. |
| **AWS** | 1 | 15 min | A hands-on tour of AWS Elastic Beanstalk Cluster Mode, in a terminal on the kind of container it runs. |
| **Docker** | 3 | 45 min | See what a container really is, write a clean Dockerfile, understand image layers and Compose. |
| **Networking** | 3 | 50 min | Addresses, ports, names and TLS: what sits between a browser and your app. |
| **CI/CD with GitHub Actions** | 3 | 45 min | Write real workflow files, check them like a runner would, deploy to AWS safely from CI. |

## How it works

```
 browser ── lesson pane + xterm.js terminal
    │  HTTP + WebSocket (same origin, localhost only in local mode)
 node server ──▶ a real bash (node-pty) per session
                  └─ "Check" runs the step's checks/<id>.sh against that shell's state     exit 0 = pass
```

- **Track → Lab → Steps.** A step is a *lesson* (read) or a *task* (do something, press Check).
- **Profiles.** `LAB_PROFILE=local` (what `start.sh` and compose use): loopback only, relaxed limits, fully offline. The
  default `hosted` profile adds invite codes, per-IP seat limits, tight timeouts and a same-origin guard.
- **Request guards.** Only the lab page itself can open or drive a shell: a website you visit cannot reach your terminal,
  and in local mode the server refuses any non-localhost `Host` (DNS rebinding).
- **Command guide.** Under every step, "Commands in this step" explains each command the step mentions in simple English:
  what it does, how it works, and an example to try. The explanations live in `labs/glossary.yaml` (plus
  `labs/<track>/glossary.yaml` for track words like Dockerfile instructions), so anyone can improve them.
- **Progress** (which labs you finished) lives in your browser's localStorage. No accounts yet.

## Add a lab

No JavaScript needed — see [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/authoring.md](docs/authoring.md).

```bash
npm run lab:new -- linux-fundamentals my-lab "My lab title"   # scaffold and register it
# edit labs/linux-fundamentals/my-lab/{lab.yaml,checks,solutions}; refresh the browser to try it
npm run lab:check -- linux-fundamentals/my-lab                 # proves every task fails before and passes after its solution
```

## Hosting

The `Dockerfile` builds the hardened image: one unprivileged user per session (`lab0`–`lab39`), lab answers readable only
by root, and — via `docker-compose.yml` — all capabilities dropped except the few needed, a read-only root filesystem, and
CPU, memory and PID limits. Use that image for any deployment where other people get a shell, and apply the same
container settings on the host you deploy to. Before a public launch, also block the cloud metadata endpoint
(`169.254.169.254`) from the container and restrict its outbound network.

Optional settings for a deployment: `SITE_URL` (adds a link to your main site in the header), `REPO_URL` (shows a source
link and the clone step), `LAB_ACCESS_TOKENS` (comma-separated invite codes, hosted profile).

## Tests

```bash
npm ci && npm test                           # on Linux/WSL: unit + integration, with real shells
npm run lab:validate                         # every task of every lab: fails before its solution, passes after
docker compose run --rm -v "$PWD/test:/app/test:ro" labs sh -c 'node --test --test-force-exit test/unit/*.test.js test/integration/*.test.js'
                                             # as root in the image: adds the per-session-user isolation tests
```

## Repo map

| Path | What |
|---|---|
| `start.sh`, `start.bat` | One-command start: native on Linux/WSL, Docker on macOS |
| `labs/` | All lab content (`<track>/<lab>/{lab.yaml,setup.sh,checks/,solutions/}`), `track.yaml` per track, `lib.sh` (check helpers) |
| `src/` | The server: sessions, sandbox, loader, profiles, pages |
| `public/` | Browser code, stylesheets, logo |
| `scripts/` | `validate-labs.js`, `lab-check.js`, `new-lab.js`, `lint-labs.js`, `check-hygiene.js` |
| `test/` | Unit and integration tests |
| `deploy/smoke-test.py` | Drives a real terminal session against a running server |
| `docs/` | Lab authoring guides |

## License

MIT — see [LICENSE](LICENSE). Hiresnix Labs is based on an MIT-licensed open-source project; see [NOTICE.md](NOTICE.md).
