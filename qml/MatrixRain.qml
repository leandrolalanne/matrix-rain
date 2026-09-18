import QtQuick
import "Versions.js" as Versions

// The Matrix `classic` digital rain, ported from Rezmason/matrix.
//
// Four stages, the same chain as upstream:
//
//   rain  ->  5-level pyramid (high-pass + blur H + blur V)  ->  combine  ->  palette
//
// The rain stage needs no state: in `classic`, brightnessDecay=1.0 discards the
// previous frame, skipIntro defeats the intro latch, and rippleTypeName=null
// leaves the effect buffer a no-op. See README.
//
// Defaults are upstream's `classic` values from js/config.js.

Item {
  id: root

  // --- version ---
  //
  // Which of upstream's versions to draw. See Versions.js, which also documents
  // the ones this port deliberately leaves out. Every parameter a version sets
  // can still be overridden individually from outside.
  property string version: "classic"
  readonly property var _v: Versions.get(version)

  function _pick(key, fallback) {
    return _v[key] !== undefined ? _v[key] : fallback
  }
  function _palStop(i, dr, dg, db, da) {
    var pal = _v.palette
    return pal !== undefined ? Qt.vector4d(pal[i][0], pal[i][1], pal[i][2], pal[i][3])
                             : Qt.vector4d(dr, dg, db, da)
  }

  // --- control ---
  property bool running: true
  // A background does not need 60: at 30 the fall still reads as fluid and the
  // GPU does half the work.
  property int fps: 30

  // --- size: configured in POINTS, like a terminal ---
  //
  // A terminal does not scale with the window, it scales with DPI: the point
  // size converts to pixels through the display scale, the cell comes from the
  // font metrics, and the columns are however many fit. Moving the window to
  // another monitor keeps the apparent size and changes the column count.
  //
  // Qt's logical pixels are already the DPI-independent unit, so converting
  // points to logical pixels at 96 DPI is enough.
  property real fontSize: _pick("fontSize", 9)
  readonly property real pxPerPoint: 96 / 72

  // Real metrics parsed out of Matrix-Code.ttf (unitsPerEm 1024):
  //   line height      ascent 960 - descent(-64) + lineGap 0 = 1024  -> 1.000 em
  //   dominant advance 956                                          -> 0.934 em
  //
  // All sizing derives from these two. Changing font means changing these.
  // (JetBrainsMono, for comparison: 1.320 em line and 0.600 advance. Its cell
  // ratio is 0.455, correct for halfwidth glyphs like ttfx's katakana, not for
  // these, which are square.)
  property real fontLineHeightEm: 1.000
  property real fontAdvanceEm: _pick("advance", 0.934)

  readonly property real cellHeight: fontSize * pxPerPoint * fontLineHeightEm
  readonly property real cellWidth:  fontSize * pxPerPoint * fontAdvanceEm
  readonly property real cellAspect: fontAdvanceEm / fontLineHeightEm

  readonly property real numColumns: width  > 0 ? Math.max(1, width  / (cellHeight * cellAspect)) : 1
  readonly property real numRows:    height > 0 ? Math.max(1, height / cellHeight) : 1

  property real fallSpeed: _pick("fallSpeed", 0.3)
  property real raindropLength: _pick("raindropLength", 0.75)
  property real baseContrast: _pick("baseContrast", 1.1)
  property real baseBrightness: _pick("baseBrightness", -0.5)

  // Scales the time fed to the shader, which is what upstream does
  // (simTime = time * animationSpeed). Fall and glyph cycling scale together.
  property real animationSpeed: _pick("animationSpeed", 1.0)

  // Border of the atlas cell to crop away before the symbol lookup.
  property real glyphEdgeCrop: _pick("glyphEdgeCrop", 0.0)

  // Pins every visible glyph to one brightness instead of letting it fade with
  // the raindrop, which is what flattens `operator`. Off when 0.
  property real brightnessOverride: _pick("brightnessOverride", 0.0)
  property real brightnessThreshold: _pick("brightnessThreshold", 0.0)

  // "box", "circle" or "" for none. Upstream keeps ripples in a ping-pong
  // buffer, but its shader never reads the previous state, so they are a pure
  // function of (time, position) and need no state here either.
  property string ripple: _pick("ripple", "")
  property real rippleScale: _pick("rippleScale", 30.0)
  property real rippleSpeed: _pick("rippleSpeed", 0.2)
  property real rippleThickness: _pick("rippleThickness", 0.2)
  readonly property real _rippleType: ripple === "box" ? 0.0 : (ripple === "circle" ? 1.0 : -1.0)

  // false plays the intro: the rain arrives onto a blank screen, one column at
  // a time. Upstream keeps this in a stateful buffer with a latch; here it is
  // closed form, because introTime only ever increases. See rain.frag.
  property bool skipIntro: true
  // Upstream advances cycling per FRAME (cycleSpeed 0.03, cycleFrameSkip 1), so
  // its speed depends on the refresh rate. Here it is fixed in seconds, taking
  // 60fps as the reference: 0.03 * 60 = 1.8 changes per second.
  property real cyclesPerSecond: _pick("cyclesPerSecond", 1.8)

  // Fraction of the size the rain renders at. Upstream uses 0.75, but CAREFUL:
  // there the entire chain runs at that fraction and the browser scales the
  // FINAL image (canvas.width = clientWidth * dpr * resolution, with the canvas
  // stretched by CSS). Here only the rain texture is reduced and the palette
  // still runs at full resolution, so the scaling lands BEFORE the color
  // mapping instead of after.
  //
  // Measured against the reference at equal size (1600x900, both offscreen):
  //
  //             mean     color R/G   color B/G
  //   res 1.00  -7.2%      +0.5%       -0.7%
  //   res 0.75  -15.3%     -6.2%      -13.4%
  //
  // So 0.75 in this implementation makes everything worse, including the color
  // balance that is essentially nailed at 1.00. It stays as a performance knob,
  // not a fidelity one. For 0.75 to be faithful you would have to wrap the whole
  // chain (palette included) and scale only the output.
  property real resolution: 1.0

  // --- bloom ---
  property real bloomSize: _pick("bloomSize", 0.4)   // pyramid starts at this fraction of the screen
  property real bloomStrength: _pick("bloomStrength", 0.7)
  property real highPassThreshold: _pick("highPassThreshold", 0.1)
  property bool bloomEnabled: bloomSize > 0 && bloomStrength > 0

  // --- color ---
  property real cursorIntensity: _pick("cursorIntensity", 2.0)
  property real glintIntensity: 1.0
  property real ditherMagnitude: 0.05
  property vector4d pal0: _palStop(0, 0.000, 0.000, 0.000, 0.0)
  property vector4d pal1: _palStop(1, 0.092, 0.380, 0.020, 0.2)
  property vector4d pal2: _palStop(2, 0.538, 0.970, 0.430, 0.7)
  property vector4d pal3: _palStop(3, 0.692, 0.980, 0.620, 0.8)
  property vector4d colCursor: _v.cursor !== undefined
    ? Qt.vector4d(_v.cursor[0], _v.cursor[1], _v.cursor[2], 1.0)
    : Qt.vector4d(0.7559, 1.0, 0.46, 1.0)
  property vector4d colGlint: Qt.vector4d(1.0, 1.0, 1.0, 1.0)
  property vector4d colBg: Qt.vector4d(0.0, 0.0, 0.0, 1.0)

  // --- atlas ---
  property url atlasSource: Qt.resolvedUrl("../assets/" + _pick("atlas", "matrixcode_msdf.png"))
  property real glyphSequenceLength: _pick("glyphSequenceLength", 57)
  property size glyphTextureGridSize: {
    var g = _pick("glyphTextureGridSize", [8, 8])
    return Qt.size(g[0], g[1])
  }
  property size glyphMSDFSize: Qt.size(512, 512)
  property real msdfPxRange: 4.0

  readonly property url shaderDir: Qt.resolvedUrl("../shaders/")

  // --- clock ---
  //
  // KNOWN LIMITATION: `elapsed` grows without bound and the uniform is float32.
  // After an hour the resolution is ~1e-4 against a per-frame step of ~0.0067,
  // or 65 levels: invisible. Near 24 hours about 3 levels per step remain and
  // the fall starts to judder. This cannot be fixed by wrapping the clock,
  // because `wobble` uses irrational frequencies so the field never repeats,
  // which leaves no clean wrap point. See README.
  property real elapsed: 0

  function restart() { root.elapsed = 0 }

  // The effective canvas the whole chain works on.
  readonly property size canvasSize: Qt.size(Math.max(1, Math.floor(width * resolution)),
                                             Math.max(1, Math.floor(height * resolution)))

  function levelSize(i) {
    var d = Math.pow(2, i)
    return Qt.size(Math.max(1, Math.floor(canvasSize.width * root.bloomSize / d)),
                   Math.max(1, Math.floor(canvasSize.height * root.bloomSize / d)))
  }

  Image {
    id: atlas
    source: root.atlasSource
    visible: false
    smooth: true
    mipmap: false
  }

  // --- stage 1: the rain, as raw brightness ---
  ShaderEffect {
    id: rain
    anchors.fill: parent
    fragmentShader: root.shaderDir + "rain.frag.qsb"

    property real iTime: root.elapsed * root.animationSpeed
    property real cellHeight: root.cellHeight
    property real cellAspect: root.cellAspect
    property size iResolution: Qt.size(width, height)
    property real fallSpeed: root.fallSpeed
    property real raindropLength: root.raindropLength
    property real baseContrast: root.baseContrast
    property real baseBrightness: root.baseBrightness
    property real cyclesPerSecond: root.cyclesPerSecond
    property real glyphSequenceLength: root.glyphSequenceLength
    property real msdfPxRange: root.msdfPxRange
    property real glyphEdgeCrop: root.glyphEdgeCrop
    property real skipIntro: root.skipIntro ? 1.0 : 0.0
    property real brightnessOverride: root.brightnessOverride
    property real brightnessThreshold: root.brightnessThreshold
    property real rippleType: root._rippleType
    property real rippleScale: root.rippleScale
    property real rippleSpeed: root.rippleSpeed
    property real rippleThickness: root.rippleThickness
    property size glyphTextureGridSize: root.glyphTextureGridSize
    property size glyphMSDFSize: root.glyphMSDFSize
    property variant glyphMSDF: atlas
  }
  ShaderEffectSource {
    id: rainSource
    sourceItem: rain
    textureSize: root.canvasSize
    hideSource: true
    live: true
    smooth: true
    visible: false
  }

  // --- stage 2: the pyramid ---
  // Each level starts from the previous level's high-pass; the downsampling is
  // done by the ShaderEffectSource rendering into a smaller texture.
  BloomLevel {
    id: lvl0
    anchors.fill: parent
    inputTexture: rainSource
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(0)
  }
  BloomLevel {
    id: lvl1
    anchors.fill: parent
    inputTexture: lvl0.highPassTexture
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(1)
  }
  BloomLevel {
    id: lvl2
    anchors.fill: parent
    inputTexture: lvl1.highPassTexture
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(2)
  }
  BloomLevel {
    id: lvl3
    anchors.fill: parent
    inputTexture: lvl2.highPassTexture
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(3)
  }
  BloomLevel {
    id: lvl4
    anchors.fill: parent
    inputTexture: lvl3.highPassTexture
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(4)
  }

  // --- stage 3: flatten the pyramid ---
  ShaderEffect {
    id: combine
    anchors.fill: parent
    fragmentShader: root.shaderDir + "combine.frag.qsb"
    property real bloomStrength: root.bloomEnabled ? root.bloomStrength : 0.0
    property variant pyr0: lvl0.output
    property variant pyr1: lvl1.output
    property variant pyr2: lvl2.output
    property variant pyr3: lvl3.output
    property variant pyr4: lvl4.output
  }
  ShaderEffectSource {
    id: bloomSource
    sourceItem: combine
    hideSource: true
    live: true
    smooth: true
    visible: false
  }

  // --- stage 4: color. The only stage that is visible. ---
  ShaderEffect {
    id: palette
    anchors.fill: parent
    fragmentShader: root.shaderDir + "palette.frag.qsb"
    property real iTime: root.elapsed
    property real ditherMagnitude: root.ditherMagnitude
    property real cursorIntensity: root.cursorIntensity
    property real glintIntensity: root.glintIntensity
    property vector4d colBg: root.colBg
    property vector4d colCursor: root.colCursor
    property vector4d colGlint: root.colGlint
    property vector4d pal0: root.pal0
    property vector4d pal1: root.pal1
    property vector4d pal2: root.pal2
    property vector4d pal3: root.pal3
    property variant rainTex: rainSource
    property variant bloomTex: bloomSource
  }

  // FrameAnimation and not Timer: with a Timer the clock advances but the
  // ShaderEffect never repaints, so the rain comes out drawn and frozen.
  // FrameAnimation is wired into the render loop. (This finding comes from the
  // enter-the-matrix theme, which proved it with logs.)
  //
  // It runs at the monitor's refresh rate but only publishes `elapsed` at `fps`.
  FrameAnimation {
    running: root.running
    property real accumulated: 0
    onTriggered: {
      accumulated += frameTime
      var step = 1 / Math.max(1, root.fps)
      if (accumulated >= step) {
        root.elapsed += accumulated
        accumulated = 0
      }
    }
  }
}
