#!/bin/bash
# Generate the marker PNG by rendering a frame of the rain OFFSCREEN.
#
# That file does three jobs at once, which is the elegant part of the mechanism
# (borrowed from the enter-the-matrix theme):
#   1. it is the thumbnail in Omarchy's background switcher
#   2. selecting it is what TURNS ON the live rain: the consumer watches the
#      current background's name for the `.live.` marker
#   3. if nothing is running, it is what you see: a decent static background
#
# It uses Item.grabToImage and does NOT capture the screen: it does not depend on
# the window being visible, on which workspace it lands, or on how the compositor
# tiles it. The previous version used grim and ended up photographing the user's
# desktop instead of the rain.
#
# Usage: tools/make-marker.sh [width] [height] [font-size]

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$HERE/assets/matrix-rain.live.webp"
W="${1:-1920}"; H="${2:-1080}"; FS="${3:-9}"

command -v qml6 >/dev/null || { echo "qml6 is missing (package qt6-declarative)" >&2; exit 1; }
[[ -f $HERE/shaders/rain.frag.qsb ]] || { echo "the .qsb files are missing; run tools/build-shaders.sh" >&2; exit 1; }

TMP=$(mktemp -t marker-XXXXXX.png)
trap 'rm -f "$TMP"' EXIT

# grabToImage multiplies by the screen's devicePixelRatio, so ask for the
# logical size that lands the result on the pixel count we want.
DPR=$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json,sys
try:
    ms = json.load(sys.stdin)
    m = next((m for m in ms if m.get("focused")), ms[0])
    print(m.get("scale") or 1)
except Exception:
    print(1)' 2>/dev/null || echo 1)
LW=$(python3 -c "print(int($W/$DPR))"); LH=$(python3 -c "print(int($H/$DPR))")

echo "requesting ${LW}x${LH} logical (dpr $DPR) to get ${W}x${H} at ${FS}pt"
( cd "$HERE" && qml6 dev/grab.qml -- out="$TMP" w="$LW" h="$LH" settle=8 fontSize="$FS" ) 2>&1 | grep -E "^ok|ERROR" || true

[[ -s $TMP ]] || { echo "no image was produced" >&2; exit 1; }

# Normalize to the exact size and drop alpha: this is a background, not a layer.
python3 - "$TMP" "$OUT" "$W" "$H" <<'PY'
import sys
from PIL import Image
src, dst, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = Image.open(src).convert("RGB")
if im.size != (w, h):
    im = im.resize((w, h), Image.LANCZOS)
# WebP q92: 76% lighter than PNG and visually indistinguishable over green
# noise. It matters because `omarchy plugin add` clones the whole repo onto
# every user's machine.
im.save(dst, format="WEBP", quality=92)
print(f"  marker: {dst}  {im.size[0]}x{im.size[1]}")
PY
