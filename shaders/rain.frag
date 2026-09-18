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
    bool isCursor = r > rBelow;

    float base = r * baseContrast + baseBrightness;

    // --- glyph ---
    float index = getSymbolIndex(simTime, screenPos);
    vec2 cellUV = fract(uv * grid);
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
    fragColor = vec4((isCursor ? 0.0 : base) * glyph,
                     (isCursor ? base : 0.0) * glyph,
                     0.0,
                     1.0);
}
