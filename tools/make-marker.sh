#!/bin/bash
# Generate the background markers by rendering a frame of each version.
#
# Each file does three jobs at once, which is the elegant part of the mechanism
# (borrowed from the enter-the-matrix theme):
#   1. it is the thumbnail in Omarchy's background switcher
#   2. selecting it is what TURNS ON the live rain: the consumer watches the
#      current background's name for the `.live.` marker
#   3. if nothing is running, it is what you see: a decent static background
#
# One per version in provider.json's background.versions, named
# <NN>-<version>.live.webp. The numeric prefix fixes the cycling order, because
# omarchy-theme-bg-next sorts by path; the consumer reads the version straight
# out of the filename.
#
# It uses Item.grabToImage and does NOT capture the screen, so the result does
# not depend on which workspace it lands on or how the compositor tiles it. A
# small window does appear per version: Qt needs a real GL context, and under
# QT_QPA_PLATFORM=offscreen every frame comes back black with no error.
#
# Usage: tools/make-marker.sh [width] [height] [font-size] [version ...]

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUTDIR="$HERE/assets/backgrounds"
W="${1:-1920}"; H="${2:-1080}"; FS="${3:-9}"
(($# >= 3)) && shift 3 || shift $#

command -v qml6 >/dev/null || { echo "qml6 is missing (package qt6-declarative)" >&2; exit 1; }
[[ -f $HERE/shaders/rain.frag.qsb ]] || { echo "the .qsb files are missing; run tools/build-shaders.sh" >&2; exit 1; }

# The versions come from the provider, so adding one there needs no edit here.
if (($# > 0)); then
  VERSIONS=("$@")
else
  mapfile -t VERSIONS < <(python3 -c "
import json, pathlib
p = json.loads(pathlib.Path('$HERE/provider.json').read_text())
print('\n'.join(p['background']['versions']))")
fi
mkdir -p "$OUTDIR"

TMP=$(mktemp -t marker-XXXXXX.png)
trap 'rm -f "$TMP"' EXIT
FAILED=0

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

n=0
for V in "${VERSIONS[@]}"; do
  n=$((n + 1))
  OUT=$(printf '%s/%02d-%s.live.webp' "$OUTDIR" "$n" "$V")
  rm -f "$TMP"
  ( cd "$HERE" && qml6 dev/grab.qml -- out="$TMP" w="$LW" h="$LH" settle=9 \
      fontSize="$FS" version="$V" ) 2>&1 | grep -E "^ok|ERROR" || true

  if [[ ! -s $TMP ]]; then
    echo "  $V: no image was produced" >&2; FAILED=1; continue
  fi

  # Normalize to the exact size and drop alpha: this is a background, not a
  # layer. A frame that came back black means no GL context rather than a dark
  # version, so it is caught here instead of shipping a black wallpaper.
  python3 - "$TMP" "$OUT" "$W" "$H" <<'PYEOF' || FAILED=1
import sys
from PIL import Image, ImageStat
src, dst, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = Image.open(src).convert("RGB")
mean = ImageStat.Stat(im).mean[1] / 255
if mean <= 0.005:
    sys.exit(f"  came back black (mean {mean:.4f}) -- no GL context?")
if im.size != (w, h):
    im = im.resize((w, h), Image.LANCZOS)
# WebP q92: 76% lighter than PNG and visually indistinguishable over green
# noise. It matters because a consumer clones the whole repo onto every
# user's machine.
im.save(dst, format="WEBP", quality=92)
print(f"  {dst.rsplit('/', 1)[-1]}  {im.size[0]}x{im.size[1]}  mean {mean:.3f}")
PYEOF
done

exit $FAILED
