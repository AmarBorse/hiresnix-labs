#!/usr/bin/env bash
# Start Hiresnix Labs on this machine.
#
#   ./start.sh              Linux / WSL: runs natively, no Docker.  macOS: runs in Docker Desktop (started for you).
#   ./start.sh --docker     force the Docker container on any OS
#   ./start.sh stop         stop a Docker run (a native run stops with Ctrl+C)
#
#   LABS_PORT=9090 ./start.sh     use another port (default 8080)
#   NO_BROWSER=1   ./start.sh     don't open the browser
#
# Windows: double-click start.bat (it calls this script inside WSL). From Git Bash this script hands over to WSL itself.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

PORT="${LABS_PORT:-8080}"
export LABS_PORT="$PORT"
URL="http://localhost:$PORT"
OS="$(uname -s)"
NODE_VERSION="22.12.0"                                   # used only when the machine has no Node.js 20+
RUNTIME_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hiresnix-labs"

say()  { printf '\033[1m%s\033[0m\n' "$*"; }
note() { printf '\033[2m%s\033[0m\n' "$*"; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

MODE=native
ARG="${1:-}"
case "$ARG" in
  --docker) MODE=docker ;;
  stop)     MODE=docker ;;
  ""|--native) ;;
  -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) fail "Unknown option: $ARG (try --help)" ;;
esac

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# --- Pick where the labs run --------------------------------------------------------------
case "$OS" in
  Linux) ;;                                              # native (WSL counts as Linux)
  Darwin)
    [ "$MODE" = native ] && note "macOS has no Linux kernel, so the labs run in Docker Desktop."
    MODE=docker ;;
  MINGW*|MSYS*|CYGWIN*)
    # Git Bash on Windows: the labs need Linux. Prefer WSL (no Docker), fall back to Docker Desktop.
    if [ "$MODE" = native ] && command -v wsl.exe >/dev/null 2>&1 && wsl.exe -e true >/dev/null 2>&1; then
      say "Handing over to WSL..."
      export WSLENV="${WSLENV:+$WSLENV:}LABS_PORT:NO_BROWSER"
      exec wsl.exe --cd "$(pwd -W)" -e bash ./start.sh
    fi
    MODE=docker ;;
  *) fail "Unsupported system: $OS" ;;
esac

open_browser() {
  [ -n "${NO_BROWSER:-}" ] && return 0
  if is_wsl; then
    if command -v wslview >/dev/null 2>&1; then wslview "$URL" >/dev/null 2>&1 && return 0; fi
    (cd /mnt/c 2>/dev/null; explorer.exe "$URL" >/dev/null 2>&1) && return 0
    return 0                                             # explorer.exe exits 1 even when it worked
  fi
  case "$OS" in
    Darwin) open "$URL" >/dev/null 2>&1 && return 0 ;;
    MINGW*|MSYS*|CYGWIN*) cmd.exe //c start "" "$URL" >/dev/null 2>&1 && return 0 ;;
    *) command -v xdg-open >/dev/null 2>&1 && xdg-open "$URL" >/dev/null 2>&1 && return 0 ;;
  esac
  echo "Open $URL in your browser."
}

# A tiny HTTP probe that needs no extra tools: curl, wget, or bash's own /dev/tcp.
up() {
  if command -v curl >/dev/null 2>&1; then curl -fs "$URL/healthz" >/dev/null 2>&1
  elif command -v wget >/dev/null 2>&1; then wget -q -O /dev/null "$URL/healthz" >/dev/null 2>&1
  else (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null
  fi
}
port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; }

wait_until_up() {
  printf 'Waiting for the server'
  for _ in $(seq 1 "${1:-90}"); do
    if up; then echo; return 0; fi
    printf '.'; sleep 1
  done
  echo; return 1
}

# ==========================================================================================
# Docker mode (macOS, or --docker): same as before, but Docker Desktop is started for you.
# ==========================================================================================
run_docker() {
  command -v docker >/dev/null 2>&1 || fail "Docker is not installed. Install Docker Desktop: https://www.docker.com/products/docker-desktop/"

  if ! docker info >/dev/null 2>&1; then
    if docker info 2>&1 | grep -qi 'permission denied'; then
      fail "Docker is running but your user may not use it. Run: sudo usermod -aG docker \$USER  (then log out and in)."
    fi
    say "Starting Docker..."
    case "$OS" in
      Darwin) open -ga Docker ;;
      MINGW*|MSYS*|CYGWIN*) ( "/c/Program Files/Docker/Docker/Docker Desktop.exe" >/dev/null 2>&1 & ) ;;
      *) sudo systemctl start docker 2>/dev/null || true ;;
    esac
    printf 'Waiting for Docker'
    for _ in $(seq 1 90); do docker info >/dev/null 2>&1 && break; printf '.'; sleep 2; done
    echo
    docker info >/dev/null 2>&1 || fail "Docker did not start. Open Docker Desktop yourself, wait until it says it is running, then run this again."
  fi

  if docker compose version >/dev/null 2>&1; then compose() { docker compose "$@"; }
  elif command -v docker-compose >/dev/null 2>&1; then compose() { docker-compose "$@"; }
  else fail "Docker Compose is missing. Update Docker Desktop, or install the compose plugin."
  fi

  if [ "$ARG" = stop ]; then compose down; say "Stopped."; exit 0; fi

  if port_busy && ! compose ps -q 2>/dev/null | grep -q .; then
    fail "Port $PORT is already in use by another program. Try: LABS_PORT=9090 ./start.sh"
  fi

  say "Building and starting Hiresnix Labs in Docker (the first run takes a few minutes)..."
  compose up --build -d
  trap 'echo; say "Stopping Hiresnix Labs..."; compose down >/dev/null 2>&1 || true; exit 0' INT TERM
  wait_until_up 90 || { compose logs --tail 40; fail "The server did not come up. Logs above."; }
  say "Hiresnix Labs is running at $URL   (Ctrl+C to stop)"
  open_browser
  compose logs -f --tail 0 labs
}

# ==========================================================================================
# Native mode (Linux / WSL): no Docker. Installs what is missing, then runs the server here.
# ==========================================================================================

# command -> Debian/Ubuntu package. Everything the labs and their checks use, plus a compiler for the terminal module.
TOOLS="git:git curl:curl jq:jq dig:dnsutils ss:iproute2 ip:iproute2 nc:netcat-openbsd tree:tree file:file less:less
nano:nano vim:vim ps:procps openssl:openssl man:man-db python3:python3 make:make g++:g++ tar:tar"

ensure_tools() {
  local missing=() pkgs=() pair cmd pkg
  for pair in $TOOLS; do
    cmd="${pair%%:*}"; pkg="${pair#*:}"
    command -v "$cmd" >/dev/null 2>&1 || { missing+=("$cmd"); pkgs+=("$pkg"); }
  done
  # The labs use OpenBSD netcat (nc -lk); the "traditional" one behaves differently.
  if command -v nc >/dev/null 2>&1 && ! nc -h 2>&1 | grep -qi openbsd; then missing+=("nc (OpenBSD)"); pkgs+=("netcat-openbsd"); fi
  [ ${#pkgs[@]} -eq 0 ] && return 0

  # unique package list
  mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | sort -u)
  say "These tools are missing: ${missing[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    local SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    say "Installing: ${pkgs[*]}"
    [ -n "$SUDO" ] && note "(sudo will ask for your Linux password once)"
    $SUDO apt-get update -qq
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq --no-install-recommends "${pkgs[@]}" ca-certificates
  else
    fail "Install these packages with your package manager, then run this again: ${pkgs[*]}"
  fi
}

node_ok() { command -v node >/dev/null 2>&1 && [ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -ge 20 ]; }

ensure_node() {
  node_ok && return 0
  local arch dir tarball base
  case "$(uname -m)" in
    x86_64) arch=x64 ;; aarch64|arm64) arch=arm64 ;;
    *) fail "No Node.js 20+ found and no download for $(uname -m). Install Node.js 20 or newer, then run this again." ;;
  esac
  dir="$RUNTIME_DIR/node-v$NODE_VERSION-linux-$arch"
  if [ ! -x "$dir/bin/node" ]; then
    say "Downloading Node.js $NODE_VERSION (one time, into $RUNTIME_DIR)..."
    mkdir -p "$RUNTIME_DIR"
    base="https://nodejs.org/dist/v$NODE_VERSION"
    tarball="node-v$NODE_VERSION-linux-$arch.tar.gz"
    curl -fsSL "$base/$tarball" -o "$RUNTIME_DIR/$tarball"
    # Verify the download against the official checksum list before unpacking it.
    curl -fsSL "$base/SHASUMS256.txt" | grep " $tarball\$" | (cd "$RUNTIME_DIR" && sha256sum -c --quiet -) \
      || { rm -f "$RUNTIME_DIR/$tarball"; fail "The Node.js download did not match its checksum. Try again."; }
    tar -xzf "$RUNTIME_DIR/$tarball" -C "$RUNTIME_DIR"
    rm -f "$RUNTIME_DIR/$tarball"
  fi
  export PATH="$dir/bin:$PATH"
  node_ok || fail "Could not set up Node.js."
}

ensure_modules() {
  local stamp="node_modules/.hiresnix-install"
  if [ ! -f "$stamp" ] || [ package-lock.json -nt "$stamp" ] || ! node -e "require('node-pty')" >/dev/null 2>&1; then
    say "Installing the app's packages (first run, about a minute)..."
    npm ci --omit=dev --no-audit --no-fund
    node -e "require('node-pty')" >/dev/null 2>&1 \
      || fail "The terminal module (node-pty) did not build. Check that make, g++ and python3 are installed, then run this again."
    date > "$stamp"
  fi
}

run_native() {
  [ "$ARG" = stop ] && fail "A native run stops with Ctrl+C in its window."
  case "$ROOT" in
    /mnt/*) note "Tip: this folder is on the Windows drive, which is slow from WSL. For a faster start, copy it into your Linux home (cp -r . ~/hiresnix-labs)." ;;
  esac
  ensure_tools
  ensure_node
  ensure_modules

  if up; then say "Hiresnix Labs is already running at $URL"; open_browser; exit 0; fi
  port_busy && fail "Port $PORT is already in use by another program. Try: LABS_PORT=9090 ./start.sh"

  note "Native mode: lab shells run as your own user ($(id -un)) in a temporary folder. They are real shells, so treat them like any terminal."
  [ "$(id -u)" -eq 0 ] && note "You are root, so lab shells will be root too. A normal user is safer."

  LAB_PROFILE=local PORT="$PORT" LISTEN_HOST=127.0.0.1 node src/server.js &
  local pid=$!
  trap 'echo; say "Stopping Hiresnix Labs..."; kill -TERM "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; exit 0' INT TERM
  wait_until_up 30 || { kill "$pid" 2>/dev/null; fail "The server did not come up. See the messages above."; }
  say "Hiresnix Labs is running at $URL   (Ctrl+C to stop)"
  open_browser
  wait "$pid"
}

if [ "$MODE" = docker ]; then run_docker; else run_native; fi
