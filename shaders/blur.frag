#version 440
// Paso 3: blur separable de 3 taps. Se corre dos veces por nivel, horizontal
// y despues vertical, que es como se arma un gaussiano 2D barato.
//
// Los pesos son los del original (0.442 centro, 0.279 cada lado). El offset
// alla sale de dividir por max(width,height) con los uniformes width/height
// CRUZADOS respecto del viewport; el efecto neto es un texel en la direccion
// del blur, que es lo que se pasa aca directo y se lee mejor.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 direction;   // (1,0) horizontal, (0,1) vertical
    vec2 texelSize;   // 1 / tamaño de ESTE nivel de la piramide
};
layout(binding = 1) uniform sampler2D src;

void main() {
    vec2 step = direction * texelSize;
    fragColor = texture(src, qt_TexCoord0) * 0.442
              + (texture(src, qt_TexCoord0 + step)
               + texture(src, qt_TexCoord0 - step)) * 0.279;
    fragColor.a = 1.0;
}
