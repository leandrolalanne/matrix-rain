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

FONT="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/Matrix-Code.ttf"
[[ -e $FONT ]] && { rm -f "$FONT"; command -v fc-cache >/dev/null && fc-cache -f "$(dirname "$FONT")" >/dev/null 2>&1
                    echo "removed $FONT"; removed=1; }

(( removed )) || echo "nothing to remove"
