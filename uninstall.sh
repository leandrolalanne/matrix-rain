#!/bin/bash
# Remove what install.sh put in place. Leaves this source tree alone.
set -uo pipefail
NAME="matrix-rain"
# enterthematrix is the name both commands had before the split; an install from
# then would have left it behind.
CMDS=(matrix redpill trace enterthematrix)
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}/$NAME"
BIN="$HOME/.local/bin"

removed=0
for c in "${CMDS[@]}"; do
  [[ -e $BIN/$c ]] || continue
  rm -f "$BIN/$c"; echo "removed $BIN/$c"; removed=1
done
# -L first: in --link mode SHARE is a symlink to the source tree, and rm -rf on
# the link removes the link, not the tree. Never follow it.
if [[ -L $SHARE ]]; then rm -f "$SHARE"; echo "removed $SHARE (was a link)"; removed=1
elif [[ -d $SHARE ]]; then rm -rf "$SHARE"; echo "removed $SHARE"; removed=1; fi

FONTS="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
for f in Matrix-Code.ttf MatrixCodeTerminal.ttf; do
  [[ -e $FONTS/$f ]] || continue
  rm -f "$FONTS/$f"; echo "removed $FONTS/$f"; removed=1; dropped_font=1
done
if [[ -n ${dropped_font:-} ]]; then
  command -v fc-cache >/dev/null && fc-cache -f "$FONTS" >/dev/null 2>&1
  # The install never wrote this line, so the uninstall does not delete it.
  echo "NOTE: if you added  font-family = \"Matrix Code Terminal\"  to a terminal"
  echo "      config, remove it by hand; the font it names is gone now."
fi

APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
for f in "$APPS/matrix-rain.desktop" "$ICONS/matrix-rain.png"; do
  [[ -e $f ]] || continue
  rm -f "$f"; echo "removed $f"; removed=1
done
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" >/dev/null 2>&1

(( removed )) || echo "nothing to remove"
