#version 440
// Paso 2: recorta lo que no brilla, para que el blur solo trabaje sobre los
// glifos encendidos. Por canal, igual que bloomPass.highPass del original.
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
