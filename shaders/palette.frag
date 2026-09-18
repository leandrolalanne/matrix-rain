#version 440
// Stage 5: brightness -> color.
//
// The key point: bloom is ADDED to brightness BEFORE the ramp is sampled, not
// composited over the color. That is why a bright glyph does not just gain a
// halo, it climbs the palette. Without this stage everything falls lower on the
// ramp and reads washed out.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    float ditherMagnitude;
    float cursorIntensity;
    float glintIntensity;
    vec4 colBg;
    vec4 colCursor;
    vec4 colGlint;
    // rgb = the stop's color, a = its position along the ramp
    vec4 pal0;
    vec4 pal1;
    vec4 pal2;
    vec4 pal3;
};
layout(binding = 1) uniform sampler2D rainTex;
layout(binding = 2) uniform sampler2D bloomTex;

#define PI 3.14159265359

float randomFloat(vec2 uv, float t) {
    const float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot(uv.xy, vec2(a, b)), sn = mod(dt, PI);
    return fract(sin(sn) * c + t);
}

// Upstream builds a 2048-sample 1D texture interpolating LINEARLY between stops,
// with the ends held. With smoothstep the mid greens come out shifted.
vec3 samplePalette(float t) {
    t = clamp(t, 0.0, 1.0);
    if (t <= pal0.a) return pal0.rgb;
    if (t <= pal1.a) return mix(pal0.rgb, pal1.rgb, (t - pal0.a) / max(1e-5, pal1.a - pal0.a));
    if (t <= pal2.a) return mix(pal1.rgb, pal2.rgb, (t - pal1.a) / max(1e-5, pal2.a - pal1.a));
    if (t <= pal3.a) return mix(pal2.rgb, pal3.rgb, (t - pal2.a) / max(1e-5, pal3.a - pal2.a));
    return pal3.rgb;
}

void main() {
    vec4 brightness = texture(rainTex, qt_TexCoord0) + texture(bloomTex, qt_TexCoord0);

    // Noise to hide the ramp's banding.
    brightness -= randomFloat(gl_FragCoord.xy, iTime) * ditherMagnitude / 3.0;

    vec3 color = samplePalette(brightness.r)
               + min(colCursor.rgb * cursorIntensity * brightness.g, vec3(1.0))
               + min(colGlint.rgb * glintIntensity * brightness.b, vec3(1.0))
               + colBg.rgb;

    fragColor = vec4(color, 1.0) * qt_Opacity;
}
