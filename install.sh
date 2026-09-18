#!/bin/bash
# Install the rain so `enterthematrix` works from any shell.
#
#   ./install.sh            copy into ~/.local/share and link the command
#   ./install.sh --link     symlink instead, so edits in this tree are live
#   ./uninstall.sh          undo it
#
# Follows the XDG layout: the app lives in ~/.local/share/<name> and the command
# in ~/.local/bin, which is the convention already used by everything else there.

set -uo pipefail

NAME="matrix-rain"
CMD="enterthematrix"
SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}/$NAME"
BIN="$HOME/.local/bin"
MODE="${1:-}"

die() { echo "install: $*" >&2; exit 1; }

# --- what it needs ---
command -v qml6 >/dev/null || die "qml6 is missing. On Arch: sudo pacman -S qt6-declarative"

if [[ ! -f $SRC/shaders/rain.frag.qsb ]]; then
  echo "compiling shaders..."
  [[ -x $SRC/tools/build-shaders.sh ]] || die "no compiled shaders and no tools/build-shaders.sh"
  "$SRC/tools/build-shaders.sh" || die "could not compile the shaders"
fi

# --- install ---
mkdir -p "$BIN"

if [[ $MODE == "--link" ]]; then
  rm -rf "$SHARE"
  mkdir -p "$(dirname "$SHARE")"
  ln -s "$SRC" "$SHARE"
  echo "linked  $SHARE -> $SRC"
else
  [[ $MODE == "" ]] || die "unknown option: $MODE (try --link)"
  rm -rf "$SHARE"
  mkdir -p "$SHARE"
  # Everything but the working directory's own clutter. The dev harnesses come
  # along on purpose: they are a few KB and they are how you preview changes.
  tar -C "$SRC" --exclude=.git --exclude=.cache -cf - . | tar -C "$SHARE" -xf -
  echo "copied  $SHARE"
fi

ln -sf "$SHARE/bin/$CMD" "$BIN/$CMD"
echo "linked  $BIN/$CMD"

# Two fonts, so --font has something to render with. User-level, and
# uninstall.sh takes them back out.
#
#   Matrix-Code.ttf        the film's font as published, for the window --font
#                          opens when it has to.
#   MatrixCodeTerminal.ttf the same outlines moved to plane 16, for running in
#                          the window you typed in. See tools/make-terminal-font.py.
FONTS="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
installed_font=0
for f in Matrix-Code.ttf MatrixCodeTerminal.ttf; do
  [[ -f $SRC/assets/$f ]] || continue
  mkdir -p "$FONTS"
  cp "$SRC/assets/$f" "$FONTS/"
  echo "installed  $FONTS/$f"
  installed_font=1
done
(( installed_font )) && command -v fc-cache >/dev/null && fc-cache -f "$FONTS" >/dev/null 2>&1

# Running in place is opt-in and stays that way: this never edits a terminal
# config. The derived font maps nothing a person can type, so the line below is
# safe to leave in forever, but it is the user's file and the user's call.
if (( installed_font )); then
  echo
  echo "To run the rain in the window you type in, add to your terminal config:"
  echo "      font-family = \"Matrix Code Terminal\"      # ghostty"
  echo "  Without it, 'enterthematrix --tty --font' opens a window of its own."
fi

# --- check it is reachable ---
if ! printf '%s' ":$PATH:" | grep -q ":$BIN:"; then
  echo
  echo "NOTE: $BIN is not on your PATH. Add this to your shell's rc file:"
  echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
else
  echo
  echo "Done. Type: $CMD"
fi
