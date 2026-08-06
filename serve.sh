#!/usr/bin/env bash
# Serve this folder over HTTP and open the lab page in a browser.
#
# The page loads its content with fetch('data/*.json') at runtime. Browsers
# block those requests on file:// URLs, so opening the .html directly shows an
# empty shell. Any static HTTP server fixes it.
#
# Needs internet on first load: support.js pulls React, ReactDOM and Babel from
# unpkg, and the page pulls webfonts from Google Fonts. Everything else --
# markup, data, images, video -- is served locally.
#
# Binds to every interface, so anyone who can reach this machine on the port can
# read the site -- no SSH forward needed. There is no auth and no TLS; use
# --local to go back to 127.0.0.1 only.
#
# Usage:
#   ./serve.sh                 # http://<this-machine>:8080/..., opens a browser
#   ./serve.sh -p 3000         # different port
#   ./serve.sh --local         # 127.0.0.1 only, not reachable from the network
#   ./serve.sh --no-browser    # server only

set -euo pipefail

PORT=8080
OPEN_BROWSER=1
BIND=0.0.0.0
PAGE='index.html'
BROWSER_PID=''

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        -p | --port)
            PORT="${2:-}"
            shift 2
            ;;
        -n | --no-browser)
            OPEN_BROWSER=0
            shift
            ;;
        -l | --local)
            BIND=127.0.0.1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "$PORT" in
    '' | *[!0-9]*)
        echo "Port must be a number, got '$PORT'." >&2
        exit 1
        ;;
esac
if [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
    echo "Port must be between 1024 and 65535, got $PORT." >&2
    exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ ! -f "$PAGE" ]; then
    echo "Cannot find '$PAGE' in $ROOT." >&2
    exit 1
fi

# Nothing listening on the port means it is free. Uses bash's /dev/tcp rather
# than ss/lsof so there is no dependency beyond bash itself.
port_free() {
    ! (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

CHOSEN=''
for ((p = PORT; p <= PORT + 20 && p <= 65535; p++)); do
    if port_free "$p"; then
        CHOSEN="$p"
        break
    fi
done
if [ -z "$CHOSEN" ]; then
    echo "No free port between $PORT and $((PORT + 20))." >&2
    exit 1
fi
if [ "$CHOSEN" != "$PORT" ]; then
    echo "Port $PORT is busy - using $CHOSEN instead."
fi

# python3 is on every Ubuntu install; the others are fallbacks.
if command -v python3 > /dev/null 2>&1; then
    SERVER=(python3 -m http.server "$CHOSEN" --bind "$BIND")
elif command -v python > /dev/null 2>&1; then
    SERVER=(python -m http.server "$CHOSEN" --bind "$BIND")
elif command -v npx > /dev/null 2>&1; then
    SERVER=(npx --yes http-server -p "$CHOSEN" -a "$BIND" -c-1)
else
    echo 'Need python3 or Node.js (npx) on PATH to serve the folder.' >&2
    exit 1
fi

# Only spaces need escaping in this filename.
PATH_PART="${PAGE// /%20}"
URL="http://localhost:$CHOSEN/$PATH_PART"

# The host other machines should use: the FQDN if this box has one, else the
# short hostname, else the IP of whichever interface carries default traffic.
remote_host() {
    local h=''
    if command -v hostname > /dev/null 2>&1; then
        h="$(hostname -f 2> /dev/null || true)"
        [ -z "$h" ] && h="$(hostname 2> /dev/null || true)"
    fi
    case "$h" in
        '' | localhost | localhost.*) h='' ;;
    esac
    if [ -z "$h" ] && command -v ip > /dev/null 2>&1; then
        h="$(ip -4 route get 1.1.1.1 2> /dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
    fi
    if [ -z "$h" ] && command -v hostname > /dev/null 2>&1; then
        h="$(hostname -I 2> /dev/null | awk '{print $1}')"
    fi
    printf '%s' "$h"
}

open_browser() {
    if command -v xdg-open > /dev/null 2>&1; then
        xdg-open "$URL" > /dev/null 2>&1 &
    elif command -v wslview > /dev/null 2>&1; then # Ubuntu under WSL
        wslview "$URL" > /dev/null 2>&1 &
    elif command -v sensible-browser > /dev/null 2>&1; then
        sensible-browser "$URL" > /dev/null 2>&1 &
    elif command -v open > /dev/null 2>&1; then # macOS
        open "$URL" > /dev/null 2>&1 &
    else
        echo "  No browser opener found - visit the URL above manually."
    fi
}

# The server blocks this shell, so wait for the port to answer in the
# background before handing the URL to a browser.
if [ "$OPEN_BROWSER" -eq 1 ]; then
    (
        for _ in $(seq 1 40); do
            if ! port_free "$CHOSEN"; then
                open_browser
                exit 0
            fi
            sleep 0.25
        done
    ) &
    BROWSER_PID=$!
fi

cleanup() {
    if [ -n "$BROWSER_PID" ]; then
        kill "$BROWSER_PID" > /dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

printf '\n  Serving %s\n  %s\n' "$ROOT" "$URL"
if [ "$BIND" != '127.0.0.1' ]; then
    REMOTE_HOST="$(remote_host)"
    if [ -n "$REMOTE_HOST" ]; then
        printf '  http://%s:%s/%s   <- from other machines\n' "$REMOTE_HOST" "$CHOSEN" "$PATH_PART"
    fi
    printf '  Reachable on every interface, with no auth. Use --local to keep it private.\n'
fi
printf '  Edit data/*.json and refresh the browser to see changes.\n'
printf '  Press Ctrl+C to stop.\n\n'

"${SERVER[@]}"
