#version 440

// Stage 1 of 4: the rain. Emits raw per-channel brightness; color is applied at
// the end of the chain (rain -> high-pass/blur pyramid -> combine -> palette).
//
// The Matrix digital rain, a native port of Rezmason/matrix `classic` (MIT).
//
// Upstream runs four ping-pong buffers in half float (intro, raindrop, symbol,
// effect) and chains rain -> bloom -> palette. For the `classic` version that
// state is unnecessary, and here is why:
//
//   brightnessDecay = 1.0   -> mix(previous, new, 1.0) discards the previous
//   skipIntro       = true  -> the `activated` latch is pinned true, and the
//                              intro returns a constant 2.0, which makes
//                              max(0, 1 - a*5) exactly 0
//   rippleTypeName  = null  -> multipliedEffects=1, addedEffects=0 (a no-op)
//   classic         = {}    -> overrides none of the above
//
// What remains is a pure function of (column, row, time), which is what this
// implements in a single pass.
//
// Glyph cycling IS stateful upstream: `age` accumulates and picks a new symbol
// when it passes 1.0. It is solved in closed form below (see getSymbolIndex):
// not an approximation, the same result.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// std140: floats first, then vec2, then vec4. Slipping a float in among the
// vec4s shifts the offset of every one that follows and the palette comes out
// wrong.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float iTime;
    // Terminal model: the cell size drives the grid, not a column count.
    // Growing the window adds columns instead of enlarging the glyphs.
    float cellHeight;
    float cellAspect;
    float fallSpeed;
    float raindropLength;
    float baseContrast;
    float baseBrightness;
    float cyclesPerSecond;
    float glyphSequenceLength;
    float msdfPxRange;
    // Border of the atlas cell to crop away. `resurrections` uses 0.1.
    float glyphEdgeCrop;
    // 0 = play the intro (the rain arrives from a blank screen), 1 = skip it.
    // Upstream's default is 1.
    float skipIntro;
    // A global override of glyph brightness, used by `operator` to flatten the
    // gradient. Only applies when > 0.
    float brightnessOverride;
    float brightnessThreshold;
    // Ripples. -1 none, 0 box, 1 circle. Upstream keeps these in a fourth
    // ping-pong buffer, but its shader never reads the previous state: the
    // ripple is a pure function of (time, position), so it lives here instead.
    float rippleType;
    float rippleScale;
    float rippleSpeed;
    float rippleThickness;

    // Shadertoy names (iTime above, iResolution here): these are what hyprglaze,
    // shaderbg, neowall and wallrs pass, so the same shader runs on those
    // wallpaper daemons and on Shadertoy, not just in Quickshell.
    vec2 iResolution;
    vec2 glyphTextureGridSize;
    vec2 glyphMSDFSize;
};

layout(binding = 1) uniform sampler2D glyphMSDF;

#define PI 3.14159265359
#define SQRT_2 1.4142135623730951
#define SQRT_5 2.23606797749979

// Identical to Rezmason's: changing them changes the whole field.
float randomFloat(vec2 uv) {
    const float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot(uv.xy, vec2(a, b)), sn = mod(dt, PI);
    return fract(sin(sn) * c);
}

// The irrational frequencies are what keep the fall from repeating.
float wobble(float x) {
    return x + 0.3 * sin(SQRT_2 * x) + 0.2 * sin(SQRT_5 * x);
}

vec2 randomVec2(vec2 uv) {
    return fract(vec2(sin(uv.x * 591.32 + uv.y * 154.077),
                      cos(uv.x * 391.32 + uv.y * 49.077)));
}

// The square ripples that cross the grid in `operator`. Straight from upstream,
// including the wobble on rippleTime.
float getRipple(float simTime, vec2 screenPos, float glyphHeightToWidth) {
    if (rippleType < 0.0) return 0.0;

    float rippleTime = (simTime * 0.5 + sin(simTime) * 0.2) * rippleSpeed + 1.0;
    vec2 offset = randomVec2(vec2(floor(rippleTime), 0.0)) - 0.5;
    vec2 ripplePos = screenPos * 2.0 - 1.0 + offset;

    float rippleDistance;
    if (rippleType < 0.5) {
        vec2 boxDistance = abs(ripplePos) * vec2(1.0, glyphHeightToWidth);
        rippleDistance = max(boxDistance.x, boxDistance.y);
    } else {
        rippleDistance = length(ripplePos);
    }

    float rippleValue = fract(rippleTime) * rippleScale - rippleDistance;
    return (rippleValue > 0.0 && rippleValue < rippleThickness) ? 0.75 : 0.0;
}

float median3(vec3 i) {
    return max(min(i.r, i.g), min(max(i.r, i.g), i.b));
}

// The core idea of the rain, copied verbatim from upstream: this is why glyphs
// sharing a column light up together and glow brighter toward the bottom.
float getRainBrightness(float simTime, vec2 glyphPos) {
    float columnTimeOffset = randomFloat(vec2(glyphPos.x, 0.0)) * 1000.0;
    float columnSpeedOffset = randomFloat(vec2(glyphPos.x + 0.1, 0.0)) * 0.5 + 0.5;
    float columnTime = columnTimeOffset + simTime * fallSpeed * columnSpeedOffset;
    float rainTime = (glyphPos.y * 0.01 + columnTime) / raindropLength;
    rainTime = wobble(rainTime);
    return 1.0 - fract(rainTime);
}

// Closed form of the glyph cycling.
//
// Upstream starts `age` at a random per-cell value and adds cycleSpeed every
// frame; when it crosses 1.0 it draws a new symbol using the simTime of THAT
// instant. So switch number k happens at a knowable time:
//
//   k    = floor(age0 + cyclesPerSecond * t)
//   t_k  = (k - age0) / cyclesPerSecond
//
// and drawing with t_k is enough. Before the first switch the initial symbol
// holds. Note upstream advances per FRAME, not per second, so its cycling speed
// depends on the refresh rate. Here it is converted to seconds
// (cyclesPerSecond = cycleSpeed * 60) so it does not.
float getSymbolIndex(float simTime, vec2 screenPos) {
    float age0 = randomFloat(screenPos + 0.5);
    float cycles = age0 + cyclesPerSecond * simTime;
    float k = floor(cycles);
    if (k < 1.0) {
        return floor(glyphSequenceLength * randomFloat(screenPos));
    }
    float tk = (k - age0) / cyclesPerSecond;
    return floor(glyphSequenceLength * randomFloat(screenPos + tk));
}

// The intro: the first stream of rain onto a blank screen.
//
// Upstream keeps this in a ping-pong buffer with a latch: once a cell is
// `activated` it stays activated. The latch is redundant, because introTime is
// strictly increasing in simTime -- once it crosses, it never comes back. So it
// resolves in closed form and needs no state.
//
// The two special columns are upstream's: the middle one and the one at 75%
// start early, which is what makes the first drops land where the eye is.
float introTimeAt(float simTime, float column, vec2 grid) {
    float columnTimeOffset;
    int col = int(column);
    if (col == int(grid.x * 0.5)) {
        columnTimeOffset = -1.0;
    } else if (col == int(grid.x * 0.75)) {
        columnTimeOffset = -2.0;
    } else {
        columnTimeOffset = randomFloat(vec2(column, 0.0)) * -4.0;
        columnTimeOffset += (sin(column / grid.x * PI) - 1.0) * 2.0 - 2.5;
    }
    return (simTime + columnTimeOffset) * fallSpeed / grid.y * 100.0;
}

// Where the glyph sits in the atlas. Rows count from the bottom, as upstream
// does (symbolY = gridSize.y - symbolY - 1).
vec2 getSymbolUV(float index) {
    float sx = mod(index, glyphTextureGridSize.x);
    float sy = floor((index - sx) / glyphTextureGridSize.x);
    sy = glyphTextureGridSize.y - sy - 1.0;
    return vec2(sx, sy);
}

void main() {
    // Qt's origin is top-left; upstream uses gl_FragCoord, whose origin is at
    // the bottom. Without this flip the rain falls upward.
    vec2 uv = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);

    // The grid comes from the cell size, like a terminal: columns and rows are
    // however many fit. A partial cell may be left at the edges, just like a
    // terminal whose height is not an exact multiple of the line.
    vec2 cellPx = vec2(cellHeight * cellAspect, cellHeight);
    vec2 grid = max(vec2(1.0), iResolution / cellPx);

    vec2 glyphPos = floor(uv * grid);
    vec2 screenPos = glyphPos / grid;

    float simTime = iTime;

    // --- raindrop brightness ---
    float r = getRainBrightness(simTime, glyphPos);
    float rBelow = getRainBrightness(simTime, glyphPos + vec2(0.0, -1.0));

    // With skipIntro the intro returns a constant 2.0, which makes introProgress
    // land in [1,2] and the flash term max(0, 1 - p*5) exactly 0.
    float introBase = skipIntro > 0.5 ? 2.0 : introTimeAt(simTime, glyphPos.x, grid);
    float introProgress      = introBase - (1.0 - glyphPos.y / grid.y);
    float introProgressBelow = introBase - (1.0 - (glyphPos.y - 1.0) / grid.y);
    bool activated      = skipIntro > 0.5 || introProgress > 0.0;
    bool activatedBelow = skipIntro > 0.5 || introProgressBelow > 0.0;

    // The cursor also lights along the activation frontier, which is what draws
    // the bright line leading the intro.
    bool isCursor = r > rBelow || (activated && !activatedBelow);

    // The flash as a column switches on, and nothing once the intro is past.
    float base = (r + max(0.0, 1.0 - introProgress * 5.0)) * baseContrast + baseBrightness;

    // Modes that do not fade their glyphs pin the brightness here instead.
    if (brightnessOverride > 0.0 && base > brightnessThreshold && !isCursor) {
        base = brightnessOverride;
    }

    // Ripples are added on top, after the override, as upstream does.
    base += getRipple(simTime, screenPos, 1.0 / max(1e-5, cellAspect));

    float gate = activated ? 1.0 : 0.0;

    // --- glyph ---
    float index = getSymbolIndex(simTime, screenPos);
    vec2 cellUV = fract(uv * grid);
    // Crop the atlas cell's border, as upstream does before the symbol lookup.
    cellUV = (cellUV - 0.5) * clamp(1.0 - glyphEdgeCrop, 0.0, 1.0) + 0.5;
    vec2 atlasUV = (cellUV + getSymbolUV(index)) / glyphTextureGridSize;

    vec2 unitRange = vec2(msdfPxRange) / glyphMSDFSize;
    vec2 screenTexSize = vec2(1.0) / fwidth(atlasUV);
    float screenPxRange = max(0.5 * dot(unitRange, screenTexSize), 1.0);
    float signedDistance = median3(texture(glyphMSDF, atlasUV).rgb);
    float glyph = clamp(screenPxRange * (signedDistance - 0.5) + 0.5, 0.0, 1.0);

    // --- raw output ---
    // Same channels as upstream's rainPass:
    //   r = base glyph brightness,  g = cursor brightness,  b = glint (0 in classic)
    // The palette is applied later, in palette.frag, AFTER bloom is added.
    fragColor = vec4((isCursor ? 0.0 : base) * glyph * gate,
                     (isCursor ? base : 0.0) * glyph * gate,
                     0.0,
                     1.0);
}
