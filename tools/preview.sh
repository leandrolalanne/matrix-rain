#!/bin/bash
# Preview the port.
#
#   tools/preview.sh              -> the port
#   tools/preview.sh --reference  -> Rezmason, as a comparison reference
#   tools/preview.sh --both       -> both, side by side
#
# Ctrl+C closes everything. Super+F fullscreens the focused window.
#
# The reference does NOT live in this repo. It is cloned on demand into a
# git-ignored cache, because it is a measurement tool and not part of the
# product. See COMPARISON.md.

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$HERE/.cache/rezmason"
UPSTREAM="https://github.com/Rezmason/matrix.git"

MODE="${1:---port}"
pids=()
cleanup() { trap - EXIT INT TERM; for p in ${pids+"${pids[@]}"}; do kill "$p" 2>/dev/null; done; }
trap cleanup EXIT INT TERM

launch_port() {
  command -v qml6 >/dev/null || { echo "qml6 is missing (package qt6-declarative)" >&2; return 1; }
  [[ -f $HERE/shaders/rain.frag.qsb ]] || { echo "the .qsb files are missing; run tools/build-shaders.sh" >&2; return 1; }
  ( cd "$HERE" && qml6 dev/main.qml ) & pids+=($!)
  echo "  native port up"
}

ensure_reference() {
  [[ -d $CACHE/.git ]] && return 0
  command -v git >/dev/null || { echo "git is needed to fetch the reference" >&2; return 1; }
  echo "  fetching the reference (once, into .cache/)..."
  git clone -q --depth 1 "$UPSTREAM" "$CACHE" || { echo "could not clone $UPSTREAM" >&2; return 1; }
}

launch_reference() {
  command -v chromium >/dev/null || { echo "chromium is missing" >&2; return 1; }
  ensure_reference || return 1
  # index.html loads <script type="module">, which browsers block over file://
  # because of CORS. It needs an HTTP origin; this is what its own README suggests.
  local port=8731
  ( cd "$CACHE" && exec python3 -m http.server "$port" --bind 127.0.0.1 ) >/dev/null 2>&1 & pids+=($!)
  local n=0
  while ! curl -s -o /dev/null "http://127.0.0.1:$port/" && ((n++ < 60)); do sleep 0.1; done
  # Throwaway profile: with the usual one the window opens inside your existing
  # Chromium and inherits its flags.
  local prof; prof=$(mktemp -d)
  chromium --user-data-dir="$prof" \
    --app="http://127.0.0.1:$port/?version=classic&suppressWarnings=true" \
    --no-first-run --no-default-browser-check --noerrdialogs \
    --ozone-platform-hint=auto >/dev/null 2>&1 & pids+=($!)
  echo "  reference (Rezmason in Chromium) up"
}

case "$MODE" in
  --port)      launch_port ;;
  --reference) launch_reference ;;
  --both)      launch_port; sleep 2; launch_reference ;;
  -h|--help)   sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)           echo "unknown option: $MODE (try --help)" >&2; exit 1 ;;
esac

echo "Ctrl+C to close."
wait
