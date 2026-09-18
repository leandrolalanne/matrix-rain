#!/bin/bash
# Remove what install.sh put in place. Leaves this source tree alone.
set -uo pipefail
NAME="matrix-rain"
CMD="enterthematrix"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}/$NAME"
BIN="$HOME/.local/bin/$CMD"

removed=0
[[ -e $BIN   ]] && { rm -f "$BIN";    echo "removed $BIN";   removed=1; }
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

(( removed )) || echo "nothing to remove"
