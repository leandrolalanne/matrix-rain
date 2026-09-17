import QtQuick

// Lluvia Matrix `classic`, port nativo de Rezmason/matrix.
//
// Cadena de cuatro etapas, la misma que el original:
//
//   rain  ->  piramide de 5 niveles (high-pass + blur H + blur V)  ->  combine  ->  palette
//
// El paso de lluvia no necesita estado: en `classic`, brightnessDecay=1.0
// descarta el frame anterior, skipIntro anula el latch del intro y
// rippleTypeName=null deja el buffer de efectos en no-op. Ver README.
//
// Los defaults son los de `classic` en js/config.js de upstream.

Item {
  id: root

  // --- control ---
  property bool running: true
  // El fondo no necesita 60: a 30 la caida sigue fluida y el GPU hace la mitad.
  property int fps: 30

  // --- lluvia ---
  property real numColumns: 80

  // Las CELDAS son cuadradas, no la grilla: upstream mapea numColumns a lo
  // ANCHO y deja que las filas caigan con el mismo paso. Medido sobre una
  // captura del original a 1920x1080: 24 px por fila, y 24 = 1920/80.
  readonly property real numRows: width > 0 && height > 0
    ? Math.max(1, numColumns * height / width)
    : numColumns * 9 / 16

  property real fallSpeed: 0.3
  property real raindropLength: 0.75
  property real baseContrast: 1.1
  property real baseBrightness: -0.5
  // Upstream avanza el ciclado por CUADRO (cycleSpeed 0.03, cycleFrameSkip 1),
  // con lo cual su velocidad depende del refresco. Aca se fija en segundos
  // tomando 60fps como referencia: 0.03 * 60 = 1.8 cambios por segundo.
  property real cyclesPerSecond: 1.8

  // Upstream renderiza el canvas a esta fraccion del tamaño de la ventana y
  // deja que el navegador lo escale (`resolution: 0.75` en sus defaults). No es
  // solo rendimiento: suaviza los glifos, y sin esto el port sale mas filoso
  // que el original (picos mas altos, mas negro puro, menos medios tonos).
  property real resolution: 0.75

  // --- bloom ---
  property real bloomSize: 0.4          // la piramide arranca a esta fraccion de la pantalla
  property real bloomStrength: 0.7
  property real highPassThreshold: 0.1
  property bool bloomEnabled: bloomSize > 0 && bloomStrength > 0

  // --- color ---
  property real cursorIntensity: 2.0
  property real glintIntensity: 1.0
  property real ditherMagnitude: 0.05
  property vector4d pal0: Qt.vector4d(0.000, 0.000, 0.000, 0.0)
  property vector4d pal1: Qt.vector4d(0.092, 0.380, 0.020, 0.2)
  property vector4d pal2: Qt.vector4d(0.538, 0.970, 0.430, 0.7)
  property vector4d pal3: Qt.vector4d(0.692, 0.980, 0.620, 0.8)
  property vector4d colCursor: Qt.vector4d(0.7559, 1.0, 0.46, 1.0)
  property vector4d colGlint: Qt.vector4d(1.0, 1.0, 1.0, 1.0)
  property vector4d colBg: Qt.vector4d(0.0, 0.0, 0.0, 1.0)

  // --- atlas ---
  property url atlasSource: Qt.resolvedUrl("../assets/matrixcode_msdf.png")
  property real glyphSequenceLength: 57
  property size glyphTextureGridSize: Qt.size(8, 8)
  property size glyphMSDFSize: Qt.size(512, 512)
  property real msdfPxRange: 4.0

  readonly property url shaderDir: Qt.resolvedUrl("../shaders/")

  // --- reloj ---
  //
  // LIMITACION CONOCIDA: `elapsed` crece sin cota y el uniform es float32. A la
  // hora la resolucion es ~1e-4 contra un paso por cuadro de ~0.0067, o sea 65
  // niveles: invisible. Cerca de las 24h quedan ~3 niveles por paso y la caida
  // empieza a juddear. No se arregla wrappeando el reloj, porque `wobble` usa
  // frecuencias irracionales para que el campo no repita y eso deja al reloj
  // sin punto de wrap limpio. Ver README.
  property real elapsed: 0

  function restart() { root.elapsed = 0 }

  // El canvas efectivo sobre el que trabaja toda la cadena.
  readonly property size canvasSize: Qt.size(Math.max(1, Math.floor(width * resolution)),
                                             Math.max(1, Math.floor(height * resolution)))

  function levelSize(i) {
    var d = Math.pow(2, i)
    return Qt.size(Math.max(1, Math.floor(canvasSize.width * root.bloomSize / d)),
                   Math.max(1, Math.floor(canvasSize.height * root.bloomSize / d)))
  }

  Image {
    id: atlas
    source: root.atlasSource
    visible: false
    smooth: true
    mipmap: false
  }

  // --- etapa 1: la lluvia, a brillo crudo ---
  ShaderEffect {
    id: rain
    anchors.fill: parent
    fragmentShader: root.shaderDir + "rain.frag.qsb"

    property real iTime: root.elapsed
    property real numColumns: root.numColumns
    property size iResolution: Qt.size(width, height)
    property real fallSpeed: root.fallSpeed
    property real raindropLength: root.raindropLength
    property real baseContrast: root.baseContrast
    property real baseBrightness: root.baseBrightness
    property real cyclesPerSecond: root.cyclesPerSecond
    property real glyphSequenceLength: root.glyphSequenceLength
    property real msdfPxRange: root.msdfPxRange
    property size glyphTextureGridSize: root.glyphTextureGridSize
    property size glyphMSDFSize: root.glyphMSDFSize
    property variant glyphMSDF: atlas
  }
  ShaderEffectSource {
    id: rainSource
    sourceItem: rain
    textureSize: root.canvasSize
    hideSource: true
    live: true
    smooth: true
    visible: false
  }

  // --- etapa 2: la piramide ---
  // Cada nivel arranca del high-pass del anterior; el downsample lo hace el
  // ShaderEffectSource al renderizar a una textura mas chica.
  BloomLevel {
    id: lvl0
    anchors.fill: parent
    inputTexture: rainSource
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(0)
  }
  BloomLevel {
    id: lvl1
    anchors.fill: parent
    inputTexture: lvl0.highPassTexture
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(1)
  }
  BloomLevel {
    id: lvl2
    anchors.fill: parent
    inputTexture: lvl1.highPassTexture
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(2)
  }
  BloomLevel {
    id: lvl3
    anchors.fill: parent
    inputTexture: lvl2.highPassTexture
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(3)
  }
  BloomLevel {
    id: lvl4
    anchors.fill: parent
    inputTexture: lvl3.highPassTexture
    highPassThreshold: root.highPassThreshold
    levelSize: root.levelSize(4)
  }

  // --- etapa 3: aplanar la piramide ---
  ShaderEffect {
    id: combine
    anchors.fill: parent
    fragmentShader: root.shaderDir + "combine.frag.qsb"
    property real bloomStrength: root.bloomEnabled ? root.bloomStrength : 0.0
    property variant pyr0: lvl0.output
    property variant pyr1: lvl1.output
    property variant pyr2: lvl2.output
    property variant pyr3: lvl3.output
    property variant pyr4: lvl4.output
  }
  ShaderEffectSource {
    id: bloomSource
    sourceItem: combine
    hideSource: true
    live: true
    smooth: true
    visible: false
  }

  // --- etapa 4: color. Es la unica etapa que se ve. ---
  ShaderEffect {
    id: palette
    anchors.fill: parent
    fragmentShader: root.shaderDir + "palette.frag.qsb"
    property real iTime: root.elapsed
    property real ditherMagnitude: root.ditherMagnitude
    property real cursorIntensity: root.cursorIntensity
    property real glintIntensity: root.glintIntensity
    property vector4d colBg: root.colBg
    property vector4d colCursor: root.colCursor
    property vector4d colGlint: root.colGlint
    property vector4d pal0: root.pal0
    property vector4d pal1: root.pal1
    property vector4d pal2: root.pal2
    property vector4d pal3: root.pal3
    property variant rainTex: rainSource
    property variant bloomTex: bloomSource
  }

  // FrameAnimation y no Timer: con Timer el reloj avanza pero el ShaderEffect
  // no repinta, y la lluvia sale dibujada y congelada. FrameAnimation esta
  // cableado al render loop. (Hallazgo del tema enter-the-matrix, que lo probo
  // con logs; se respeta.)
  //
  // Corre al refresco del monitor pero solo publica `elapsed` a `fps`.
  FrameAnimation {
    running: root.running
    property real accumulated: 0
    onTriggered: {
      accumulated += frameTime
      var step = 1 / Math.max(1, root.fps)
      if (accumulated >= step) {
        root.elapsed += accumulated
        accumulated = 0
      }
    }
  }
}
