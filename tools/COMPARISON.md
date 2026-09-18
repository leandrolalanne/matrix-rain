# How to compare against the reference (and how not to)

This port's fidelity was measured by comparing captures against Rezmason running
in Chromium. Documenting the protocol matters because the obvious method gives
false results, and several were swallowed before that became clear.

## Metrics

Over the capture's green channel:

| Metric | What it tells you |
|---|---|
| `rg`, `bg` | sum(R)/sum(G) and sum(B)/sum(G). **The best signal**: it is the palette, and it is nearly immune to which frame you catch. |
| `p99` | peak brightness: the cursors. |
| `p50`, `mean` | how much faint glow is spread around. Sensitive to bloom. |
| `black` | fraction of near-black pixels. |
| grid pitch | autocorrelation of the per-row brightness profile -> px per cell. |

## The method that works

Take the window manager out of the loop. Both sides are captured offscreen and
the result reproduces:

```bash
# the port
qml6 dev/grab.qml -- out.png 1280 720 8 1.0     # width height settle resolution

# the reference (tools/preview.sh clones it into .cache/ the first time)
cd .cache/rezmason && python3 -m http.server 8731 --bind 127.0.0.1 &
chromium --headless=new --window-size=1600,900 --virtual-time-budget=10000 \
  --screenshot=ref.png "http://127.0.0.1:8731/?version=classic"
```

The reference does not live in this repo: it is a measurement tool, not part of
the product. `tools/preview.sh` clones it on demand into `.cache/`, which is
ignored.

Two warnings:

**The size the QML asks for is not the size you get.** `grabToImage` multiplies
by the screen's devicePixelRatio, and neither `QT_SCALE_FACTOR` nor
`QT_ENABLE_HIGHDPI_SCALING=0` nor `QT_SCREEN_SCALE_FACTORS=1` prevents it (all
three tested). At dpr 1.25, asking for 1280x720 yields 1600x900. That is not a
problem: just ask Chromium for whatever size actually came out, because
`numColumns` spreads over the width in both and the internal canvas matches.

**Chromium headless falls back to software WebGL** (SwiftShader). The output
looks correct and the shader math is the same, but it is worth keeping in mind
as a possible source of small differences.

## The four traps

**1. Capturing the monitor instead of the window.** `visibility:
Window.FullScreen` does not always win: Hyprland tiles the window anyway, and
then `grim -o <monitor>` captures Nautilus and a terminal. One such measurement
reported -55% brightness that was pure desktop. Always capture with `grim -g
"$(window geometry)"`, and check the geometry *after* the sleep, not before.
Better yet, avoid the screen entirely with `grabToImage`.

**2. Comparing captures from different runs.** The tile size Hyprland hands out
depends on what else is in the workspace, and size changes the metrics (the
glyph scales with the width). Two runs of the SAME configuration produced 0.1197
and 0.0911 mean. The port and the reference must be captured **back to back in
the same run**, and the geometry has to match before you compare.

**3. Forgetting the field is animated.** Between frames of a single run the
metrics move by ~5%. Any difference smaller than that is noise.

**4. Taking the autocorrelation maximum as the grid pitch.** A grid's
autocorrelation has harmonics, and the global maximum is often 2x or 3x the real
period. Look for the *smallest* lag above a threshold instead. This one caused a
working reflow implementation to be reported as broken.
