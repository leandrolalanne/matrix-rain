#version 440
// Stage 2: clip away what does not glow, so the blur only works on lit glyphs.
// Per channel, same as upstream's bloomPass.highPass.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float highPassThreshold;
};
layout(binding = 1) uniform sampler2D src;

void main() {
    vec4 c = texture(src, qt_TexCoord0);
    if (c.r < highPassThreshold) c.r = 0.0;
    if (c.g < highPassThreshold) c.g = 0.0;
    if (c.b < highPassThreshold) c.b = 0.0;
    fragColor = vec4(c.rgb, 1.0);
}
