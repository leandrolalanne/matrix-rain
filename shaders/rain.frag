#version 440

// Paso 1 de 4: la lluvia. Emite brillo crudo por canal; el color se aplica
// al final de la cadena (rain -> highpass/blur piramide -> combine -> palette).
//
// Lluvia Matrix, port nativo del `classic` de Rezmason/matrix (MIT).
//
// El original corre cuatro ping-pong buffers en half float (intro, raindrop,
// symbol, effect) y encadena rain -> bloom -> palette. Para la version
// `classic` ese estado no es necesario, y esto es por que:
//
//   brightnessDecay = 1.0   -> mix(previo, nuevo, 1.0) descarta el previo
//   skipIntro       = true  -> el latch `activated` queda fijo en true, y el
//                              intro devuelve 2.0 constante, con lo cual
//                              max(0, 1 - a*5) da exactamente 0
//   rippleTypeName  = null  -> multipliedEffects=1, addedEffects=0 (no-op)
//   classic         = {}    -> no override ninguno de los anteriores
//
// Queda una funcion pura de (columna, fila, tiempo), que es lo que se
// implementa aca en un solo paso.
//
// El ciclado de glifos SI es stateful en el original: `age` acumula y al
// pasar 1.0 sortea simbolo nuevo. Se resuelve en forma cerrada abajo
// (ver getSymbolIndex): no es una aproximacion, es el mismo resultado.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// std140: primero los floats, despues los vec2, despues los vec4. Meter un
// float entre los vec4 corre el offset de todos los que siguen y la paleta
// sale cambiada.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float iTime;
    float numColumns;
    float numRows;
    float fallSpeed;
    float raindropLength;
    float baseContrast;
    float baseBrightness;
    float cyclesPerSecond;
    float glyphSequenceLength;
    float msdfPxRange;

    vec2 glyphTextureGridSize;
    vec2 glyphMSDFSize;
};

layout(binding = 1) uniform sampler2D glyphMSDF;

#define PI 3.14159265359
#define SQRT_2 1.4142135623730951
#define SQRT_5 2.23606797749979

// Identicas a las de Rezmason: cambiarlas cambia el campo entero.
float randomFloat(vec2 uv) {
    const float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot(uv.xy, vec2(a, b)), sn = mod(dt, PI);
    return fract(sin(sn) * c);
}

// Las frecuencias irracionales son lo que hace que la caida no repita.
float wobble(float x) {
    return x + 0.3 * sin(SQRT_2 * x) + 0.2 * sin(SQRT_5 * x);
}

float median3(vec3 i) {
    return max(min(i.r, i.g), min(max(i.r, i.g), i.b));
}

// El concepto central de la lluvia, copiado tal cual del original: por eso los
// glifos de una misma columna se encienden juntos y brillan mas hacia abajo.
float getRainBrightness(float simTime, vec2 glyphPos) {
    float columnTimeOffset = randomFloat(vec2(glyphPos.x, 0.0)) * 1000.0;
    float columnSpeedOffset = randomFloat(vec2(glyphPos.x + 0.1, 0.0)) * 0.5 + 0.5;
    float columnTime = columnTimeOffset + simTime * fallSpeed * columnSpeedOffset;
    float rainTime = (glyphPos.y * 0.01 + columnTime) / raindropLength;
    rainTime = wobble(rainTime);
    return 1.0 - fract(rainTime);
}

// Forma cerrada del ciclado de glifos.
//
// El original arranca `age` en un valor random por celda y le suma cycleSpeed
// cada frame; cuando cruza 1.0 sortea simbolo usando el simTime de ESE
// instante. O sea que el switch numero k ocurre en un tiempo conocido:
//
//   k    = floor(age0 + cyclesPerSecond * t)
//   t_k  = (k - age0) / cyclesPerSecond
//
// y alcanza con sortear con t_k. Antes del primer switch vale el simbolo
// inicial. Nota: el original avanza por FRAME, no por segundo, asi que su
// velocidad de ciclado depende del framerate. Aca se pasa a segundos
// (cyclesPerSecond = cycleSpeed * 60) para que no dependa del refresco.
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

// Posicion del glifo dentro del atlas. La fila se cuenta desde abajo, como en
// el original (symbolY = gridSize.y - symbolY - 1).
vec2 getSymbolUV(float index) {
    float sx = mod(index, glyphTextureGridSize.x);
    float sy = floor((index - sx) / glyphTextureGridSize.x);
    sy = glyphTextureGridSize.y - sy - 1.0;
    return vec2(sx, sy);
}

void main() {
    // Qt tiene el origen arriba a la izquierda; el original usa gl_FragCoord,
    // que lo tiene abajo. Sin este flip la lluvia sube.
    vec2 uv = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);

    vec2 grid = vec2(numColumns, numRows);
    vec2 glyphPos = floor(uv * grid);
    vec2 screenPos = glyphPos / grid;

    float simTime = iTime;

    // --- brillo de la gota ---
    float r = getRainBrightness(simTime, glyphPos);
    float rBelow = getRainBrightness(simTime, glyphPos + vec2(0.0, -1.0));
    bool isCursor = r > rBelow;

    float base = r * baseContrast + baseBrightness;

    // --- glifo ---
    float index = getSymbolIndex(simTime, screenPos);
    vec2 cellUV = fract(uv * grid);
    vec2 atlasUV = (cellUV + getSymbolUV(index)) / glyphTextureGridSize;

    vec2 unitRange = vec2(msdfPxRange) / glyphMSDFSize;
    vec2 screenTexSize = vec2(1.0) / fwidth(atlasUV);
    float screenPxRange = max(0.5 * dot(unitRange, screenTexSize), 1.0);
    float signedDistance = median3(texture(glyphMSDF, atlasUV).rgb);
    float glyph = clamp(screenPxRange * (signedDistance - 0.5) + 0.5, 0.0, 1.0);

    // --- salida cruda ---
    // Mismos canales que el rainPass del original:
    //   r = brillo base del glifo,  g = brillo del cursor,  b = glint (0 en classic)
    // La paleta se aplica despues, en palette.frag, DESPUES de sumarle el bloom.
    fragColor = vec4((isCursor ? 0.0 : base) * glyph,
                     (isCursor ? base : 0.0) * glyph,
                     0.0,
                     1.0);
}
