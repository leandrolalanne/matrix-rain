#!/bin/bash
# Genera el PNG marcador renderizando OFFSCREEN un cuadro de la propia lluvia.
#
# Ese archivo cumple TRES funciones a la vez, que es lo elegante del mecanismo
# (copiado del tema enter-the-matrix):
#   1. es la miniatura en el switcher de fondos de Omarchy
#   2. seleccionarlo es lo que ENCIENDE la lluvia en vivo: el consumidor mira
#      el nombre del fondo actual y busca el marcador `.live.`
#   3. si nada corre, es lo que ves: un fondo estatico decente
#
# Usa Item.grabToImage y NO captura la pantalla: no depende de que la ventana
# este visible, ni de en que workspace caiga, ni de como la tile el compositor.
# La version anterior usaba grim y termino fotografiando el escritorio del
# usuario en vez de la lluvia.
#
# Uso: tools/make-marker.sh [ancho] [alto] [font-size]

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$HERE/assets/matrix-rain.live.png"
W="${1:-1920}"; H="${2:-1080}"; FS="${3:-9}"

command -v qml6 >/dev/null || { echo "hace falta qml6 (paquete qt6-declarative)" >&2; exit 1; }
[[ -f $HERE/shaders/rain.frag.qsb ]] || { echo "faltan los .qsb; corre tools/build-shaders.sh" >&2; exit 1; }

TMP=$(mktemp -t marker-XXXXXX.png)
trap 'rm -f "$TMP"' EXIT

# grabToImage multiplica por el devicePixelRatio de la pantalla, asi que se pide
# el tamaño logico que deja el resultado en los pixeles buscados.
DPR=$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json,sys
try:
    ms = json.load(sys.stdin)
    m = next((m for m in ms if m.get("focused")), ms[0])
    print(m.get("scale") or 1)
except Exception:
    print(1)' 2>/dev/null || echo 1)
LW=$(python3 -c "print(int($W/$DPR))"); LH=$(python3 -c "print(int($H/$DPR))")

echo "pidiendo ${LW}x${LH} logicos (dpr $DPR) para obtener ${W}x${H} a ${FS}pt"
( cd "$HERE" && qml6 dev/grab.qml -- "$TMP" "$LW" "$LH" 8 1.0 "$FS" ) 2>&1 | grep -E "^ok|ERROR" || true

[[ -s $TMP ]] || { echo "no se genero la imagen" >&2; exit 1; }

# Normalizar al tamaño exacto y sin canal alfa: es un fondo, no una capa.
python3 - "$TMP" "$OUT" "$W" "$H" <<'PY'
import sys
from PIL import Image
src, dst, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = Image.open(src).convert("RGB")
if im.size != (w, h):
    im = im.resize((w, h), Image.LANCZOS)
im.save(dst, optimize=True)
print(f"  marcador: {dst}  {im.size[0]}x{im.size[1]}")
PY
