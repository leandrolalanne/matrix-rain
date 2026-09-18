#!/bin/bash
# Vista previa del port.
#
#   tools/preview.sh              -> el port
#   tools/preview.sh --original   -> Rezmason, como referencia para comparar
#   tools/preview.sh --ambos      -> los dos, lado a lado
#
# Ctrl+C cierra todo. Super+F pone en pantalla completa la ventana enfocada.
#
# El original NO vive en este repo. Se clona a demanda a un cache ignorado por
# git, porque es una referencia de medicion y no parte del producto. Ver
# COMPARACION.md.

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$HERE/.cache/rezmason"
UPSTREAM="https://github.com/Rezmason/matrix.git"

MODE="${1:---port}"
pids=()
cleanup() { trap - EXIT INT TERM; for p in ${pids+"${pids[@]}"}; do kill "$p" 2>/dev/null; done; }
trap cleanup EXIT INT TERM

launch_port() {
  command -v qml6 >/dev/null || { echo "falta qml6 (paquete qt6-declarative)" >&2; return 1; }
  [[ -f $HERE/shaders/rain.frag.qsb ]] || { echo "faltan los .qsb; corre tools/build-shaders.sh" >&2; return 1; }
  ( cd "$HERE" && qml6 dev/main.qml ) & pids+=($!)
  echo "  port nativo levantado"
}

ensure_reference() {
  [[ -d $CACHE/.git ]] && return 0
  command -v git >/dev/null || { echo "hace falta git para traer la referencia" >&2; return 1; }
  echo "  trayendo la referencia (una sola vez, a .cache/)..."
  git clone -q --depth 1 "$UPSTREAM" "$CACHE" || { echo "no pude clonar $UPSTREAM" >&2; return 1; }
}

launch_original() {
  command -v chromium >/dev/null || { echo "falta chromium" >&2; return 1; }
  ensure_reference || return 1
  # index.html carga <script type="module">, que los navegadores bloquean sobre
  # file:// por CORS. Hace falta un origen HTTP; es lo que sugiere su propio README.
  local port=8731
  ( cd "$CACHE" && exec python3 -m http.server "$port" --bind 127.0.0.1 ) >/dev/null 2>&1 & pids+=($!)
  local n=0
  while ! curl -s -o /dev/null "http://127.0.0.1:$port/" && ((n++ < 60)); do sleep 0.1; done
  # Perfil efimero: con el perfil habitual la ventana se abre dentro de tu
  # Chromium existente y hereda sus flags.
  local prof; prof=$(mktemp -d)
  chromium --user-data-dir="$prof" \
    --app="http://127.0.0.1:$port/?version=classic&suppressWarnings=true" \
    --no-first-run --no-default-browser-check --noerrdialogs \
    --ozone-platform-hint=auto >/dev/null 2>&1 & pids+=($!)
  echo "  referencia (Rezmason en Chromium) levantada"
}

case "$MODE" in
  --port)     launch_port ;;
  --original) launch_original ;;
  --ambos)    launch_port; sleep 2; launch_original ;;
  -h|--help)  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)          echo "opcion desconocida: $MODE (proba --help)" >&2; exit 1 ;;
esac

echo "Ctrl+C para cerrar."
wait
