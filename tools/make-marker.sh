#!/bin/bash
# Genera el PNG marcador capturando un cuadro de la propia lluvia.
#
# Ese archivo cumple TRES funciones a la vez, que es lo elegante del mecanismo
# (copiado del tema enter-the-matrix):
#   1. es la miniatura en el switcher de fondos de Omarchy
#   2. seleccionarlo es lo que ENCIENDE la lluvia en vivo: el plugin mira el
#      nombre del fondo actual y busca el marcador
#   3. si el plugin no esta corriendo, es lo que ves — un fondo estatico
#      decente en vez de nada
#
# Uso: tools/make-marker.sh [monitor]

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$HERE/assets/matrix-rain.live.png"
MON="${1:-}"
TRIES=6

command -v grim >/dev/null || { echo "hace falta grim" >&2; exit 1; }
command -v qml6 >/dev/null || { echo "hace falta qml6" >&2; exit 1; }

if [[ -z $MON ]]; then
  MON=$(hyprctl monitors -j | python3 -c 'import json,sys
ms=json.load(sys.stdin)
print(next((m["name"] for m in ms if m.get("focused")), ms[0]["name"]))')
fi
read -r MW MH < <(hyprctl monitors -j | python3 -c "
import json,sys
m = next(m for m in json.load(sys.stdin) if m['name']=='$MON')
print(m['width'] // (m.get('scale') or 1) if False else int(m['width']/(m.get('scale') or 1)), int(m['height']/(m.get('scale') or 1)))")

restore_cursor() { hyprctl eval 'hl.config({ cursor = { invisible = false } })' &>/dev/null || true; }
trap restore_cursor EXIT INT TERM

echo "monitor $MON, esperando ventana de ${MW}x${MH} (logico)"
for attempt in $(seq 1 $TRIES); do
  # Cursor invisible: si no, sale dibujado en el marcador.
  hyprctl eval 'hl.config({ cursor = { invisible = true } })' &>/dev/null || true
  ( cd "$HERE" && qml6 dev/fullscreen.qml ) &>/dev/null &
  pid=$!
  geo=""
  for i in $(seq 1 30); do
    sleep 0.4
    geo=$(hyprctl clients -j | python3 -c '
import json,sys
for c in json.load(sys.stdin):
    if "matrix rain fullscreen" in (c.get("title") or ""):
        print("%d,%d %dx%d" % (c["at"][0], c["at"][1], c["size"][0], c["size"][1])); break')
    [[ -n $geo ]] && break
  done
  size="${geo#* }"
  if [[ $size == "${MW}x${MH}" ]]; then
    # Dejar que la lluvia llene la pantalla antes de capturar: recien nacida
    # tiene huecos y el marcador quedaria ralo.
    sleep 6
    grim -o "$MON" "$OUT" && echo "marcador generado: $OUT ($(python3 -c "
from PIL import Image; im=Image.open('$OUT'); print('%dx%d' % im.size)" 2>/dev/null || echo '?'))"
    kill $pid 2>/dev/null
    exit 0
  fi
  echo "  intento $attempt: la ventana salio $size en vez de ${MW}x${MH}; reintento"
  kill $pid 2>/dev/null
  sleep 2
done

echo "No consegui una ventana a pantalla completa en $TRIES intentos." >&2
echo "Hyprland la tila cuando el workspace tiene otras ventanas: probá en uno vacio." >&2
exit 1
