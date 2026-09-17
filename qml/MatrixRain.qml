import QtQuick

// Lluvia Matrix `classic`, port nativo de Rezmason/matrix.
//
// Un unico ShaderEffect a pantalla completa: shaders/rain.frag hace todo el
// trabajo y aca solo se le pasan el reloj, la grilla y los colores.
//
// Los defaults de abajo son los de la version `classic` de upstream
// (js/config.js). Cambiarlos deja de ser `classic`.

Item {
  id: root

  // --- control ---
  property bool running: true
  // Cuadros por segundo a los que avanza el reloj del shader. El fondo no
  // necesita 60: a 30 la caida sigue viendose fluida y el GPU hace la mitad.
  property int fps: 30

  // --- parametros de upstream (classic) ---
  property real numColumns: 80

  // Las CELDAS son cuadradas, no la grilla: upstream mapea numColumns a lo
  // ANCHO y deja que las filas caigan con el mismo paso. Medido sobre una
  // captura del original a 1920x1080: 24 px por fila, y 24 = 1920/80, o sea
  // 45 filas. Estirar 80x80 a la pantalla achata las celdas y duplica la
  // densidad vertical.
  readonly property real numRows: width > 0 && height > 0
    ? Math.max(1, numColumns * height / width)
    : numColumns * 9 / 16
  property real fallSpeed: 0.3
  property real raindropLength: 0.75
  property real baseContrast: 1.1
  property real baseBrightness: -0.5
  // Upstream avanza el ciclado por FRAME (cycleSpeed 0.03, cycleFrameSkip 1),
  // con lo cual su velocidad depende del refresco. Aca se fija en segundos
  // tomando 60fps como referencia: 0.03 * 60 = 1.8 cambios por segundo.
  property real cyclesPerSecond: 1.8
  property real cursorIntensity: 2.0
  property real ditherMagnitude: 0.05

  // --- atlas ---
  // matrixcode: los glifos de la trilogia. 57 simbolos en una grilla 8x8.
  property url atlasSource: Qt.resolvedUrl("../assets/matrixcode_msdf.png")
  property real glyphSequenceLength: 57
  property size glyphTextureGridSize: Qt.size(8, 8)
  property size glyphMSDFSize: Qt.size(512, 512)
  property real msdfPxRange: 4.0

  // --- paleta (hsl(0.3, 0.9, l) de classic; .w es la posicion del stop) ---
  property vector4d pal0: Qt.vector4d(0.000, 0.000, 0.000, 0.0)
  property vector4d pal1: Qt.vector4d(0.092, 0.380, 0.020, 0.2)
  property vector4d pal2: Qt.vector4d(0.538, 0.970, 0.430, 0.7)
  property vector4d pal3: Qt.vector4d(0.692, 0.980, 0.620, 0.8)
  property vector4d colCursor: Qt.vector4d(0.7559, 1.0, 0.46, 1.0)
  property vector4d colBg: Qt.vector4d(0.0, 0.0, 0.0, 1.0)

  // --- reloj ---
  //
  // LIMITACION CONOCIDA: `elapsed` crece sin cota y el uniform es float32.
  // A la hora de corrido rainTime ronda 1400 y la resolucion es ~1e-4 contra
  // un paso por cuadro de ~0.0067, o sea 65 niveles: invisible. Cerca de las
  // 24h rainTime ronda 35000, la resolucion cae a ~0.002 y quedan 3 niveles
  // por paso: ahi la caida empieza a juddear.
  //
  // No se puede resolver wrappeando el reloj como hace enter-the-matrix,
  // porque `wobble` usa frecuencias irracionales (sin(sqrt(2)x), sin(sqrt(5)x))
  // justamente para que el campo no repita, y eso deja al reloj sin punto de
  // wrap limpio. Las salidas son resignar `wobble`, aceptar un salto cada
  // tantas horas, o emular doble precision en el acumulador.
  property real elapsed: 0

  function restart() { root.elapsed = 0 }

  Image {
    id: atlas
    source: root.atlasSource
    visible: false
    smooth: true
    mipmap: false
  }

  ShaderEffect {
    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl("../shaders/rain.frag.qsb")

    // Los nombres tienen que coincidir con los del uniform block del shader.
    property real iTime: root.elapsed
    property real numColumns: root.numColumns
    property real numRows: root.numRows
    property real fallSpeed: root.fallSpeed
    property real raindropLength: root.raindropLength
    property real baseContrast: root.baseContrast
    property real baseBrightness: root.baseBrightness
    property real cyclesPerSecond: root.cyclesPerSecond
    property real glyphSequenceLength: root.glyphSequenceLength
    property real msdfPxRange: root.msdfPxRange
    property real cursorIntensity: root.cursorIntensity
    property real ditherMagnitude: root.ditherMagnitude
    property size glyphTextureGridSize: root.glyphTextureGridSize
    property size glyphMSDFSize: root.glyphMSDFSize
    property vector4d colBg: root.colBg
    property vector4d colCursor: root.colCursor
    property vector4d pal0: root.pal0
    property vector4d pal1: root.pal1
    property vector4d pal2: root.pal2
    property vector4d pal3: root.pal3
    property variant glyphMSDF: atlas
  }

  // FrameAnimation y no Timer: con Timer el reloj avanza pero el ShaderEffect
  // no repinta, y la lluvia sale dibujada y congelada. FrameAnimation esta
  // cableado al render loop. (Esto lo documenta enter-the-matrix, que lo probo
  // con logs; se respeta su hallazgo.)
  //
  // Corre al refresco del monitor pero solo publica `elapsed` a `fps`, asi el
  // shader ve la cantidad de pasos pedida y no 144.
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
