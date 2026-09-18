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
//   operator, paradise   ripple effects, excluded by choice
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
    // 40 columns upstream, half of classic's, so twice the point size.
    fontSize: 18,
    animationSpeed: 0.5
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

function names() {
  return Object.keys(versions)
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
