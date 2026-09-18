#version 440
// Stage 3: separable 3-tap blur. Run twice per level, horizontal then vertical,
// which is how you build a cheap 2D gaussian.
//
// The weights are upstream's (0.442 center, 0.279 each side). There the offset
// comes from dividing by max(width,height) with the width/height uniforms
// SWAPPED relative to the viewport; the net effect is one texel along the blur
// direction, which is what gets passed directly here and reads better.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 direction;   // (1,0) horizontal, (0,1) vertical
    vec2 texelSize;   // 1 / size of THIS pyramid level
};
layout(binding = 1) uniform sampler2D src;

void main() {
    vec2 step = direction * texelSize;
    fragColor = texture(src, qt_TexCoord0) * 0.442
              + (texture(src, qt_TexCoord0 + step)
               + texture(src, qt_TexCoord0 - step)) * 0.279;
    fragColor.a = 1.0;
}
