#!/bin/bash
# Compile the .frag files to .qsb, the format Qt Quick's ShaderEffect consumes.
set -euo pipefail
QSB=${QSB:-/usr/lib/qt6/bin/qsb}
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for src in "$HERE"/shaders/*.frag; do
  out="${src}.qsb"
  "$QSB" --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$out" "$src"
  echo "  $(basename "$src") -> $(basename "$out")"
done
