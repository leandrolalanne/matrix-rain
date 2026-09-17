#!/bin/bash
# Vista previa del port, y opcionalmente del original al lado para comparar.
#
#   tools/preview.sh            -> solo el port
#   tools/preview.sh --original -> solo el original de Rezmason en Chromium
#   tools/preview.sh --ambos    -> los dos, para comparar
#
# Ctrl+C cierra todo. Super+F pone en pantalla completa la ventana enfocada.

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# El original vive en el repo del theme, al lado de este.
THEME="$(dirname -- "$HERE")/omarchy-matrix-theme"

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

launch_original() {
  [[ -d $THEME/vendor/matrix ]] || { echo "no encuentro la copia de Rezmason en $THEME/vendor/matrix" >&2; return 1; }
  command -v chromium >/dev/null || { echo "falta chromium" >&2; return 1; }
  local portfile; portfile=$(mktemp)
  "$THEME/bin/matrix-serve" --root "$THEME/vendor/matrix" > "$portfile" 2>/dev/null & pids+=($!)
  local n=0
  while [[ ! -s $portfile ]] && ((n++ < 100)); do sleep 0.05; done
  local port; port=$(cat "$portfile"); rm -f "$portfile"
  [[ $port =~ ^[0-9]+$ ]] || { echo "el servidor local no arranco" >&2; return 1; }
  # Perfil propio y efimero: si comparte el de tu Chromium habitual, la ventana
  # se abre en esa instancia y hereda sus flags.
  local prof; prof=$(mktemp -d)
  chromium --user-data-dir="$prof" \
    --app="http://127.0.0.1:$port/?version=classic&suppressWarnings=true" \
    --no-first-run --no-default-browser-check --noerrdialogs \
    --ozone-platform-hint=auto >/dev/null 2>&1 & pids+=($!)
  echo "  original (Rezmason en Chromium) levantado en el puerto $port"
}

case "$MODE" in
  --port)     launch_port ;;
  --original) launch_original ;;
  --ambos)    launch_port; sleep 2; launch_original ;;
  -h|--help)  sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)          echo "opcion desconocida: $MODE (proba --help)" >&2; exit 1 ;;
esac

echo "Ctrl+C para cerrar."
wait
