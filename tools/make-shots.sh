#!/bin/bash
# Regenerate docs/media/versions.jpg: one frame per version, side by side.
#
# Through dev/grab.qml and Item.grabToImage, so the frames do not depend on what
# is on screen or on how the compositor tiles anything. A small window appears
# per version while it runs; that is Qt needing a GL context, not the capture.
# Do NOT set QT_QPA_PLATFORM=offscreen to avoid it: there is no GL context there
# and every frame comes back black, with no error. See tools/COMPARISON.md.
#
# The versions are read from provider.json, so adding one here needs no edit.
#
# Usage: tools/make-shots.sh
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$HERE/docs/media/versions.jpg"
TMP=$(mktemp -d -t shots-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

command -v qml6 >/dev/null || { echo "qml6 is missing (qt6-declarative)" >&2; exit 1; }
MAGICK=$(command -v magick || command -v convert) || { echo "ImageMagick is missing" >&2; exit 1; }

# operator's ripples are on screen about 7% of the time -- the band crosses
# during the first 2/30 of each ~10 second cycle. Settling to 10.45s lands on
# one, so the still actually shows what separates it from operator-plain.
settle_for() { [[ $1 == operator ]] && echo 10.45 || echo 9; }

versions=$(sed -n 's/.*"available": \[\(.*\)\].*/\1/p' "$HERE/provider.json" \
           | tr -d '"' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$')

panels=()
for v in $versions; do
  echo "rendering $v..."
  ( cd "$HERE" && qml6 dev/grab.qml -- out="$TMP/$v.png" version="$v" \
      w=480 h=720 settle="$(settle_for "$v")" ) >/dev/null 2>&1
  [[ -s $TMP/$v.png ]] || { echo "  failed" >&2; continue; }
  # A frame that came back black means the GL context was missing, not that the
  # rain was dark. Catch it here rather than shipping five black panels.
  mean=$("$MAGICK" "$TMP/$v.png" -alpha off -format '%[fx:mean]' info:)
  awk -v m="$mean" 'BEGIN { exit (m > 0.005) ? 0 : 1 }' || {
    echo "  came back black (mean $mean) -- no GL context?" >&2; exit 1; }
  "$MAGICK" "$TMP/$v.png" -alpha off \
    -gravity South -background '#000000' -splice 0x54 \
    -pointsize 30 -fill '#9ef7b0' -annotate +0+12 "$v" \
    -bordercolor '#1b1b1b' -border 3 "$TMP/L_$v.png"
  panels+=("$TMP/L_$v.png")
done

mkdir -p "$(dirname "$OUT")"
"$MAGICK" "${panels[@]}" +append -resize 1800x -quality 88 "$OUT"
echo "wrote $OUT ($("$MAGICK" "$OUT" -format '%wx%h' info:))"

# docs/media/terminal.jpg is not made here: it needs a real terminal with the
# plane 16 font in its chain, and a compositor to capture from. Open one, run
# `redpill`, and grab that window's geometry.
