#version 440
// Stage 4: flatten the pyramid by summing the five blurred levels.
// Smaller levels weigh slightly less; the weights are upstream's.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float bloomStrength;
};
layout(binding = 1) uniform sampler2D pyr0;
layout(binding = 2) uniform sampler2D pyr1;
layout(binding = 3) uniform sampler2D pyr2;
layout(binding = 4) uniform sampler2D pyr3;
layout(binding = 5) uniform sampler2D pyr4;

void main() {
    vec4 total = texture(pyr0, qt_TexCoord0) * 0.96549
               + texture(pyr1, qt_TexCoord0) * 0.92832
               + texture(pyr2, qt_TexCoord0) * 0.88790
               + texture(pyr3, qt_TexCoord0) * 0.84343
               + texture(pyr4, qt_TexCoord0) * 0.79370;
    fragColor = vec4((total * bloomStrength).rgb, 1.0);
}
