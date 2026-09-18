# omarchy-matrix-rain

The Matrix digital rain from [Rezmason/matrix](https://github.com/Rezmason/matrix),
ported to a native Qt Quick shader so it can run as a desktop background without
paying for a browser.

**Status: four versions, ripples and the intro working. Not yet packaged as a plugin.**

## Install

```bash
git clone https://github.com/<you>/omarchy-matrix-rain
cd omarchy-matrix-rain
./install.sh
```

Then, from any shell:

```bash
enterthematrix                 # classic, arriving from a blank screen
enterthematrix operator        # start on a specific version
enterthematrix --list          # what is available
```

It opens as a normal window where you are, not as a fullscreen takeover. Super+F
fullscreens it if you want that.

The intro plays **once, on launch**, into `classic`. While it runs: `v` next
version (no intro — switching is not a fresh entry), `i` replay the intro, `f`
fps, `h` hint, `q` quit.

It needs **qt6-declarative** (for `qml6`) and a GPU that does OpenGL. Nothing else.

`install.sh` copies the app to `~/.local/share/matrix-rain` and links the command
into `~/.local/bin`, the XDG layout. `./install.sh --link` symlinks the source
tree instead, so edits are live — useful while developing. `./uninstall.sh`
undoes either, and never follows the link when removing.

This works outside Omarchy: it is a plain Qt Quick application with no Omarchy
dependency.

> The command is named after the film's line, run together because a shell
> command cannot have spaces. There is also an Omarchy theme
> called [Enter the Matrix](https://github.com/tymurbogach/omarchy-enterthematrix-theme),
> unrelated to this project, whose own command is `omarchy-matrix`. This one
> credits that theme below for a finding it published first.


## Developing

```bash
tools/build-shaders.sh      # compile shaders/*.frag to .qsb (only if you edit a .frag)
tools/preview.sh            # preview in a window
tools/preview.sh --both     # the port and Rezmason side by side
qml6 dev/main.qml           # same as preview.sh, directly
```

In the preview: `v` cycles the version, `i` replays the intro, `+`/`-` change the
point size, `a` cycles the cell advance, `f` toggles 30/60 fps, `h` hides the
overlay. Resize the window to watch it reflow. Super+F fullscreens.

## Why this exists

Running the real Rezmason in a WebKit layer-shell surface works, but it costs
**~880 MB of RAM and ~35% of one core** with two monitors: a full WebKit process
per screen. A native `ShaderEffect` runs inside the Quickshell process that is
already there and adds none.

## What makes the port possible

Upstream runs four ping-pong buffers in half float (intro, raindrop, symbol,
effect) and chains `rain -> bloom -> palette -> quilt`. That looks impossible to
reproduce in a single pass, but **for the `classic` version none of that state is
needed**, and you can prove it from the defaults:

| Default | Value | Consequence |
|---|---|---|
| `brightnessDecay` | `1.0` | `mix(previous, new, 1.0)` discards the previous frame |
| `skipIntro` | `true` | the intro returns a constant `2.0`, so `max(0, 1 - a*5)` is 0 |
| `rippleTypeName` | `null` | `multipliedEffects=1`, `addedEffects=0`: a no-op |
| `classic` | `{}` | overrides none of the above |

What remains is a pure function of (column, row, time).

### Glyph cycling, in closed form

This is the only genuinely stateful part: `age` accumulates per frame and picks a
new symbol when it crosses 1.0. But the switch times are knowable:

```
k      = floor(age0 + cyclesPerSecond * t)
t_k    = (k - age0) / cyclesPerSecond
symbol = floor(glyphSequenceLength * randomFloat(screenPos + t_k))
```

This is not an approximation — it yields the same result. The one deliberate
difference is that upstream advances per **frame** (so its cycling speed depends
on the refresh rate); here it is fixed in seconds.

## Versions

```qml
MatrixRain { version: "classic" }       // or "operator", "megacity", "resurrections"
MatrixRain { skipIntro: false }         // the rain arrives onto a blank screen
```

| Version | What it is |
|---|---|
| `classic` | The code everyone knows, from the sequels' opening titles. |
| `operator` | The first film's titles and the operators' screens: flatter, crowded, no gradient, with square ripples crossing it. |
| `operator-plain` | The same, with the ripples switched off. |
| `megacity` | The classic code with the Megacity as a glyph, from *Revolutions*. |
| `resurrections` | The updated code from *Matrix Resurrections*. |

Each version is an atlas plus a parameter bundle; `qml/Versions.js` holds them
and every value stays individually overridable from outside. `operator-plain` is
derived from `operator` rather than copied, so the two cannot drift apart.

Two upstream keys are translated rather than copied. `numColumns` becomes
`fontSize`, because this port sizes by point like a terminal instead of pinning
a column count — the relative density is preserved, so upstream's 40-column
megacity becomes 18pt against classic's 9pt. `animationSpeed` is applied by
scaling the time fed to the shader, which is what upstream does.

### The intro

`skipIntro: false` plays the opening: the rain arrives onto a blank screen one
column at a time, with two columns deliberately starting early.

Upstream keeps this in a ping-pong buffer with a latch — once a cell is
`activated` it stays activated. **The latch is redundant**: `introTime` is
strictly increasing in `simTime`, so once it crosses it never comes back. It
resolves in closed form and needs no state, like the rest of the rain.

### Ripples

`operator` has the square ripples that sweep across the grid. Upstream keeps
them in a fourth ping-pong buffer, but **its effect shader never reads the
previous state** — `getRipple` is a pure function of `(time, position)` — so
they live in the rain shader here and need no buffer.

`operator-plain` exists for when you want that look without them.

They are on screen about **7% of the time**: the band crosses the visible area
during the first 2/30 of each ~10 second cycle. Worth knowing before concluding
they are broken, which is exactly the mistake four random captures produced here
before the visible windows were computed rather than guessed.

`operator` also uses `brightnessOverride`, which pins every visible glyph to one
brightness instead of letting it fade with the raindrop. That is what flattens
it: measured against classic, mean green goes 0.111 -> 0.259 and the near-black
fraction goes 0.582 -> 0.080.

It is also the only version so far with a cell narrower than the font's own
advance: upstream's `glyphHeightToWidth: 1.35` becomes `advance: 0.692` here
(0.934 / 1.35), which is what crowds it.


### What is not here, and why

| | |
|---|---|
| `paradise` | ripples plus `brightnessDecay` and polar space, and it sits on the speculative *Variants* list. |
| `3d`, `trinity`, `morpheus`, `bugs`, `holoplay` | **volumetric.** Upstream draws one quad per glyph (trinity is 3600 of them, each placed in perspective). A single fullscreen `ShaderEffect` cannot express that: `GridMesh` gives a *connected* grid, so neighbouring quads share vertices and cannot move independently in depth. It would need custom C++ geometry — which kills the install-with-one-command story — or a raymarched reimplementation, which is no longer a port. |
| `mirror` | needs a webcam and click interaction. |
| `nightmare` | `brightnessDecay: 0.75` is the one parameter that genuinely needs per-frame state. Approximable with a short FIR, not attempted. |
| the *Variants* list | speculative, not wanted. |


## What each file is for

`omarchy plugin add` clones the **whole** repo onto every user's machine, so
everything here gets installed. Nothing is redundant, but it helps to know what
is what:

| | | |
|---|---|---|
| `qml/` | **product** | `MatrixRain.qml` and `BloomLevel.qml`, plus `Versions.js` |
| `shaders/*.frag.qsb` | **product** | compiled; these are what load at runtime |
| `assets/*_msdf.png` | **product** | one MSDF atlas per version, untouched from upstream |
| `assets/matrix-rain.live.webp` | **product** | thumbnail + marker + static fallback |
| `provider.json` | **product** | what consumers read |
| `LICENSE`, `LICENSE.rezmason` | **product** | ours and upstream's, both MIT |
| `shaders/*.frag` | source | the GLSL the `.qsb` are built from |
| `tools/build-shaders.sh` | source | compiles them; only needed if you edit a `.frag` |
| `tools/make-marker.sh` | source | regenerates the marker offscreen |
| `qml/Main.qml` | **product** | the fullscreen app the command runs |
| `install.sh`, `uninstall.sh`, `bin/` | **product** | the install |
| `dev/` | development | `main.qml` is the preview, `grab.qml` captures without a screen |
| `tools/preview.sh` | development | opens the preview, and the reference beside it |
| `tools/COMPARISON.md` | development | how to measure against the reference without measuring wrong |

The `.qsb` files are committed on purpose even though they are build artifacts:
whoever installs the plugin is not going to run `qsb`.

The marker is WebP rather than PNG because over green noise it is 76% smaller
while being visually indistinguishable, and it used to be 94% of the repo.

## Layout model: terminal, not zoom

Size is configured **in points**, like a terminal. The cell comes from the font
metrics and the column count is however many fit.

```qml
fontSize: 9               // the only size knob
fontLineHeightEm: 1.000   // Matrix-Code.ttf: ascent 960 - descent(-64) + lineGap 0, over upm 1024
fontAdvanceEm:    0.934   // dominant advance 956 over upm 1024
```

A terminal **does not scale with the window, it scales with DPI**:

- Resize the window -> the cell count changes, the glyph does not move.
- Move it to another monitor -> same apparent size, different column count.

Qt's logical pixels are already the DPI-independent unit, so converting points to
logical pixels at 96 DPI is enough. Verified:

```
window 1280x720  ->  25px pitch,  36 rows x 69 columns
window  640x360  ->  25px pitch,  18 rows x 34 columns
```

Same pitch, different grid. That is terminal reflow.

| font-size | cell | grid at 1536x864 logical |
|---|---|---|
| **9 pt** | 12.0 x 11.2 px | **137 x 72** |
| 12 pt | 16.0 x 14.9 px | 103 x 54 |
| 15 pt | 20.0 x 18.7 px | 82 x 43 |

**This is a deliberate divergence from upstream.** Rezmason pins
`numColumns: 80` and stretches: resizing zooms and never reflows. The point of
this port is for the rain to behave like real text, which is where its
authenticity comes from — in the film the code is on terminals.

As a consequence, **fidelity metrics against Rezmason stop being the target** for
anything grid-dependent: at a given window size we have a different column count
than upstream, by design. Color, brightness and glyph shape remain comparable.

### The font advance

`fontAdvanceEm` is 0.934, parsed out of the TTF. The resulting cell is what a
terminal running that font would use.

Two alternatives look reasonable and are not:

- **0.47**, which enterthematrix uses, is correct for *its* atlas of halfwidth
  katakana taken from `ttfx`. Applied to this atlas it squashes glyphs by half.
- **Your terminal's metrics** (JetBrainsMono and friends, ~0.6) describe the
  terminal's font, not the film's.

The atlas glyphs are drawn square (41x43 px average inside 64x64 cells), so 0.934
compresses them horizontally by 6.6%, which is imperceptible. Setting
`fontAdvanceEm` equal to `fontLineHeightEm` removes it at the cost of a slightly
wider grid than the font would give.

## The chain

```
rain -> 5-level pyramid (high-pass -> blur H -> blur V) -> combine -> palette
```

Bloom is not composited over the color: it is **added to brightness before the
ramp is sampled** (`brightness = primary + bloom`), so a bright glyph does not
just gain a halo, it climbs the palette.

Each pyramid level high-passes the previous level's high-pass output, and the
downsampling is done by the `ShaderEffectSource` rendering into a smaller
texture. One upstream detail that reads like a bug and is not: `bloomPass.js`
passes `height: viewportWidth` and `width: viewportHeight`, swapped. With the
swap the offset works out to exactly one texel, which is what gets passed
directly here.

## Fidelity

Measured against the reference at equal size (1600x900), **both offscreen**: the
port via `Item.grabToImage()` and Rezmason via `chromium --headless=new
--screenshot`. No windows and no window manager involved, so it reproduces. See
`tools/COMPARISON.md`.

| metric | reference | port | delta |
|---|---|---|---|
| color balance R/G | 0.3825 | 0.3843 | **+0.5%** |
| color balance B/G | 0.2422 | 0.2404 | **-0.7%** |
| peak brightness (p99) | 0.9333 | 0.9569 | +2.5% |
| mean brightness | 0.1213 | 0.1126 | **-7.2%** |
| near-black fraction | 0.5634 | 0.6082 | +8.0% |

Color and geometry are essentially nailed. What remains is ~7% less mean
brightness and 8% more pure black: the reference has a faint glow spread
everywhere that the port lacks. With ~5% frame-to-frame variance, that sits just
above the noise.

### What it was not

For a while the gap looked like -28%, and it was attributed to upstream's
`resolution: 0.75` default — it renders the canvas at 75% and lets the browser
scale it up, softening the glyphs.

**Measured, that hypothesis is false.** Applying 0.75 makes everything worse:

| | mean | color R/G | color B/G |
|---|---|---|---|
| `resolution 1.00` | -7.2% | +0.5% | -0.7% |
| `resolution 0.75` | -15.3% | -6.2% | -13.4% |

The reasoning was sound; what was wrong is **where** the scaling lands. Upstream
runs the entire chain at that fraction and the browser scales the **final image**
(`canvas.width = clientWidth * dpr * resolution`, with the canvas stretched by
CSS). Here only the rain texture is reduced and the palette still runs at full
resolution, so the scaling falls *before* the color mapping instead of after: it
loses glyph coverage ahead of the ramp rather than softening the final color.

That is why `resolution` sits at `1.0` and is a performance knob, not a fidelity
one. For 0.75 to be faithful you would have to wrap the whole chain (palette
included) in a `ShaderEffectSource` and scale only the output.

Much of the original -28% was not real either: it came from comparing window
captures of differing sizes, before there was a deterministic measurement.

## Provider and machinery

This repo is **only the provider**: shaders, atlas, palette and marker. Whatever
mounts them somewhere — a Quickshell plugin, a wallpaper daemon, a theme
installer — lives outside and reads `provider.json`.

The split is deliberate, borrowed from the
[enterthematrix](https://github.com/tymurbogach/omarchy-enterthematrix-theme)
theme: a second provider (another rain, another effect) should not force a single
line of the machinery to change.

```
omarchy-matrix-rain     <- this repo: the effect
  provider.json           declares shaders, atlas, palette, marker, defaults
  shaders/  assets/  qml/

omarchy-matrix-theme    <- consumer: a structure assembled LATER, out of
                           whatever comes from here (screensaver, background, art)
```

### Possible hosts

| Host | Multipass | What runs |
|---|---|---|
| Quickshell (`ShaderEffect`) | yes | the full chain, with bloom |
| hyprglaze, shaderbg, neowall, wallrs | no | `rain` only (no bloom) |
| Shadertoy | yes (buffers) | the full chain |

That is why the uniforms use Shadertoy's names (`iTime`, `iResolution`): the same
shader runs everywhere, and a host without multipass uses the `rain` stage alone.
You lose the bloom, not the rain.

### How it gets selected as a background in Omarchy

`assets/matrix-rain.live.webp` does three jobs at once:

1. it is the **thumbnail** in the background switcher,
2. selecting it is what **turns on** the live rain — the consumer watches the
   current background's name for the `.live.` marker,
3. if nothing is running, it is what you see: a decent **static background**.

It goes in `~/.config/omarchy/backgrounds/<slug>/`, which Omarchy lists before
the theme's own (`omarchy-theme-bg-next` sorts by path, and `.config` < `.local`).

The marker is `.live.` rather than `-live-` on purpose: enterthematrix watches
for that other one, and with both installed it would turn its rain on alongside
ours.

## Known limitation: the clock

`elapsed` grows without bound and the uniform is float32. After an hour
`rainTime` is around 1400 and the resolution is ~1e-4 against a per-frame step of
~0.0067, or 65 levels: invisible. Near 24 hours `rainTime` is around 35000, the
resolution drops to ~0.002 and about 3 levels per step remain: that is where the
fall starts to judder.

This cannot be fixed by wrapping the clock the way the enterthematrix theme
does, because `wobble` uses irrational frequencies (`sin(sqrt(2)x)`,
`sin(sqrt(5)x)`) precisely so the field never repeats, which leaves the clock no
clean wrap point. The ways out are giving up `wobble`, accepting a jump every so
many hours, or emulating double precision in the accumulator.

## Still to do

- Package it as a Quickshell plugin (`manifest.json` + `Service.qml` on a
  layer-shell surface).
- Steal the two things enterthematrix does better: `WlrLayer.Bottom` instead of
  `Background`, and freezing the render when a window covers the desktop on
  battery — which matters more here, at 18 passes per frame.
- Measure the actual GPU cost, which is still unmeasured.

## Credits and license

The rain algorithm, the MSDF atlas (`assets/matrixcode_msdf.png`) and the palette
come from [Rezmason/matrix](https://github.com/Rezmason/matrix), MIT. See
`LICENSE.rezmason`. This port is MIT as well, see `LICENSE`.

The finding that `FrameAnimation` is required (with a `Timer` the clock advances
but the `ShaderEffect` never repaints) comes from tymurbogach's
[enterthematrix](https://github.com/tymurbogach/omarchy-enterthematrix-theme)
theme, which solved the same problem first.
