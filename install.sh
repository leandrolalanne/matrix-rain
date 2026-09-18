#!/bin/bash
# Install the rain so `matrix` and `redpill` work from any shell.
#
#   ./install.sh            copy into ~/.local/share and link the command
#   ./install.sh --link     symlink instead, so edits in this tree are live
#   ./uninstall.sh          undo it
#
# Follows the XDG layout: the app lives in ~/.local/share/<name> and the command
# in ~/.local/bin, which is the convention already used by everything else there.

set -uo pipefail

NAME="matrix-rain"
CMDS=(matrix redpill)
# Linked as `enterthematrix` before the commands were split in two. Left behind
# it would dangle, so the install clears it.
OLD_CMDS=(enterthematrix)
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

for c in "${CMDS[@]}"; do
  ln -sf "$SHARE/bin/$c" "$BIN/$c"
  echo "linked  $BIN/$c"
done
for c in "${OLD_CMDS[@]}"; do
  [[ -L $BIN/$c ]] || continue
  rm -f "$BIN/$c"; echo "removed $BIN/$c (renamed)"
done

# Two fonts, so redpill has something to render with. User-level, and
# uninstall.sh takes them back out.
#
#   Matrix-Code.ttf        the film's font as published, for the window redpill
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
  echo "  Without it, 'redpill' opens a window of its own."
fi

# A desktop entry, so it can be started from an application launcher with no
# terminal in the picture at all. Exec is absolute because a launcher does not
# necessarily inherit the PATH a login shell builds.
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
if [[ -f $SRC/assets/matrix-rain.png ]]; then
  mkdir -p "$APPS" "$ICONS"
  cp "$SRC/assets/matrix-rain.png" "$ICONS/matrix-rain.png"
  cat > "$APPS/matrix-rain.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Matrix Rain
GenericName=Digital rain
Comment=The digital rain from The Matrix
Exec=$BIN/matrix
Icon=matrix-rain
Terminal=false
Categories=Graphics;Amusement;
Keywords=matrix;rain;screensaver;
DESKTOP
  command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" >/dev/null 2>&1
  echo "installed  $APPS/matrix-rain.desktop"
fi

# --- check it is reachable ---
if ! printf '%s' ":$PATH:" | grep -q ":$BIN:"; then
  echo
  echo "NOTE: $BIN is not on your PATH. Add this to your shell's rc file:"
  echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
else
  echo
  echo "Done. Type: ${CMDS[0]} for the GPU rain, ${CMDS[1]} for it in this terminal."
fi
