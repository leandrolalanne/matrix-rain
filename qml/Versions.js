.pragma library

// The versions this port offers, with the parameters each one overrides.
// Values come from upstream's js/config.js; the palettes are its hsl() stops
// already converted to RGB with the same formula colorToRGB.js uses.
//
// Two upstream keys are translated rather than copied:
//
//   numColumns -> fontSize. Upstream pins a column count and stretches; this
//     port sizes by point like a terminal. The relative density is preserved:
//     classic is 80 columns at 9pt, so a version with N columns gets
//     9 * 80 / N points.
//
//   cycleSpeed -> folded into cyclesPerSecond, and animationSpeed is applied by
//     scaling the time fed to the shader, which is what upstream does
//     (simTime = time * animationSpeed).
//
// Versions that are NOT here, and why:
//   paradise             ripples plus brightnessDecay and polar space, and it
//                        is on the speculative Variants list
//   3d, trinity, morpheus, bugs, holoplay
//                        volumetric: upstream draws one quad per glyph, which a
//                        single fullscreen ShaderEffect cannot express
//   mirror               needs a webcam and click interaction
//   nightmare            brightnessDecay 0.75, the one thing that really needs
//                        per-frame state
//   the "Variants" list  speculative, not wanted

var versions = {

  classic: {
    label: "Classic",
    description: "The code everyone knows, from the sequels' opening titles.",
    atlas: "matrixcode_msdf.png",
    glyphSequenceLength: 57,
    glyphTextureGridSize: [8, 8],
    fontSize: 9
  },

  megacity: {
    label: "Megacity",
    description: "The classic code with the Megacity as a glyph, from Revolutions.",
    atlas: "megacity_msdf.png",
    glyphSequenceLength: 64,
    glyphTextureGridSize: [8, 8],
    // Upstream pins this one at 40 columns, half of classic's, which works out
    // to 18pt here. Held at classic's 9 on purpose: the Megacity glyph is a
    // city seen from above, and at 18pt the grid reads as a handful of huge
    // tiles rather than as rain.
    fontSize: 9,
    animationSpeed: 0.5
  },

  operator: {
    label: "Operator",
    description: "The code as it appears in the first film's titles and on the operators' screens: flatter, crowded, no gradient, with square ripples crossing it.",
    atlas: "matrixcode_msdf.png",
    glyphSequenceLength: 57,
    glyphTextureGridSize: [8, 8],
    // 108 columns upstream: 9 * 80 / 108.
    fontSize: 6.7,
    // upstream's glyphHeightToWidth 1.35 makes the cell that much narrower
    // than the font's own advance would.
    advance: 0.692,
    fallSpeed: 0.6,
    raindropLength: 1.5,
    // cycleSpeed 0.01 * 60.
    cyclesPerSecond: 0.6,
    glyphEdgeCrop: 0.15,
    bloomSize: 0.6,
    bloomStrength: 0.75,
    highPassThreshold: 0.0,
    cursorIntensity: 3.0,
    cursor: [0.32, 1.0, 0.49],
    // What flattens the gradient: every visible glyph is pinned to one
    // brightness instead of fading with the raindrop.
    brightnessOverride: 0.22,
    brightnessThreshold: 0.0,
    ripple: "box",
    palette: [
      [0.0, 0.0, 0.00, 0.0],
      [0.1, 0.9, 0.42, 0.5],
      [1.0, 1.0, 1.00, 1.0],
      [1.0, 1.0, 1.00, 1.0]
    ]
  },

  resurrections: {
    label: "Resurrections",
    description: "The updated code from Matrix Resurrections.",
    atlas: "resurrections_msdf.png",
    glyphSequenceLength: 135,
    glyphTextureGridSize: [13, 12],
    // 70 columns upstream: 9 * 80 / 70.
    fontSize: 10.3,
    glyphEdgeCrop: 0.1,
    baseBrightness: -0.7,
    baseContrast: 1.17,
    highPassThreshold: 0.0,
    cursorIntensity: 2.0,
    cursor: [0.6992, 1.0, 0.6],
    // Only three stops upstream; the fourth repeats the last so the shader's
    // four-stop ramp behaves identically.
    palette: [
      [0.0, 0.0, 0.0, 0.00],
      [0.2, 1.0, 0.4, 0.92],
      [1.0, 1.0, 1.0, 1.00],
      [1.0, 1.0, 1.0, 1.00]
    ]
  }
}

// The same operator with the ripples switched off. Derived from it rather than
// copied so the two cannot drift apart: change operator and this follows.
versions["operator-plain"] = Object.assign({}, versions.operator, {
  label: "Operator (plain)",
  description: "The operators' screens without the ripples sweeping across them.",
  ripple: ""
})

// The order the `v` key cycles through, and the order `--list` prints. Explicit
// rather than Object.keys(), which follows insertion order and would put
// operator-plain last simply because it is derived after the literal.
// provider.json's versions.available mirrors this; change one, change both.
var order = ["classic", "resurrections", "operator-plain", "operator", "megacity"]

function names() {
  return order
}

function get(name) {
  return versions[name] !== undefined ? versions[name] : versions.classic
}

// Returns the version's value for `key`, or `fallback` when it does not
// override it. Keeps every parameter individually overridable from outside.
function pick(name, key, fallback) {
  var v = get(name)
  return v[key] !== undefined ? v[key] : fallback
}
