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

# --- check it is reachable ---
if ! printf '%s' ":$PATH:" | grep -q ":$BIN:"; then
  echo
  echo "NOTE: $BIN is not on your PATH. Add this to your shell's rc file:"
  echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
else
  echo
  echo "Done. Type: $CMD"
fi
