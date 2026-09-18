// Banco de pruebas: `qml6 dev/main.qml` (o `tools/preview.sh`).
// Abre una ventana normal, no toca el escritorio.
//
// Redimensionala para ver el modelo terminal: cambia la cantidad de columnas,
// no el tamaño de los glifos.
//
// Teclas:
//   + / -   sube y baja el cuerpo de la fuente, en puntos
//   a       alterna el ratio de celda entre las tres opciones reales
//   f       alterna 30/60 fps
//   h       muestra u oculta este cartel
import QtQuick
import QtQuick.Window
import "../qml"

Window {
  id: win
  width: 1280; height: 720
  visible: true
  title: "matrix rain - classic (port nativo)"
  color: "black"

  // Avance de la fuente en em. Los tres salen de parsear TTFs de verdad.
  readonly property var ratios: [
    { v: 0.934, n: "Matrix-Code.ttf" },
    { v: 0.909, n: "2 celdas JetBrainsMono (fullwidth)" },
    { v: 0.455, n: "1 celda JetBrainsMono (achata 51%)" }
  ]
  property int ratioIdx: 0

  MatrixRain {
    id: rain
    anchors.fill: parent
    fps: 60
    fontAdvanceEm: win.ratios[win.ratioIdx].v
  }

  Item {
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) rain.fontSize = Math.min(60, rain.fontSize + 1)
      else if (e.key === Qt.Key_Minus) rain.fontSize = Math.max(4, rain.fontSize - 1)
      else if (e.key === Qt.Key_A) win.ratioIdx = (win.ratioIdx + 1) % win.ratios.length
      else if (e.key === Qt.Key_F) rain.fps = rain.fps === 60 ? 30 : 60
      else if (e.key === Qt.Key_H) hud.visible = !hud.visible
    }
  }

  Rectangle {
    id: hud
    anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
    width: col.width + 16; height: col.height + 12
    color: "#c0000000"; radius: 3
    Column {
      id: col
      anchors.centerIn: parent
      spacing: 2
      Text {
        color: "#9dffaa"; font.family: "monospace"; font.pixelSize: 12
        text: "font-size " + rain.fontSize.toFixed(0) + "pt   celda " + rain.cellHeight.toFixed(1) + " x " + rain.cellWidth.toFixed(1) + " px"
            + "   grilla " + Math.floor(rain.numColumns) + " x " + Math.floor(rain.numRows)
            + "   ventana " + win.width + "x" + win.height
      }
      Text {
        color: "#4fa85f"; font.family: "monospace"; font.pixelSize: 11
        text: "avance " + rain.fontAdvanceEm.toFixed(3) + "em  " + win.ratios[win.ratioIdx].n
            + "   ·   " + rain.fps + "fps   t=" + rain.elapsed.toFixed(0) + "s"
      }
      Text {
        color: "#2f6b3a"; font.family: "monospace"; font.pixelSize: 10
        text: "+/- puntos   ·   a avance   ·   f fps   ·   h ocultar   ·   redimensiona para ver el reflujo"
      }
    }
  }
}
