// Banco de pruebas: `qml6 dev/main.qml` (o `tools/preview.sh`).
// Abre una ventana normal, no toca el escritorio.
//
// Redimensionala para ver el modelo terminal: cambia la cantidad de columnas,
// no el tamaño de los glifos.
//
// Teclas:
//   + / -   sube y baja el alto de celda (como el cuerpo de la fuente)
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

  // Los tres ratios que salieron de medir fuentes de verdad.
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
    cellAspect: win.ratios[win.ratioIdx].v
  }

  Item {
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) rain.cellHeight = Math.min(80, rain.cellHeight + 1)
      else if (e.key === Qt.Key_Minus) rain.cellHeight = Math.max(6, rain.cellHeight - 1)
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
        text: "celda " + rain.cellHeight.toFixed(0) + " x " + (rain.cellHeight * rain.cellAspect).toFixed(1) + " px"
            + "   grilla " + Math.floor(rain.numColumns) + " x " + Math.floor(rain.numRows)
            + "   ventana " + win.width + "x" + win.height
      }
      Text {
        color: "#4fa85f"; font.family: "monospace"; font.pixelSize: 11
        text: "ratio " + rain.cellAspect.toFixed(3) + "  " + win.ratios[win.ratioIdx].n
            + "   ·   " + rain.fps + "fps   t=" + rain.elapsed.toFixed(0) + "s"
      }
      Text {
        color: "#2f6b3a"; font.family: "monospace"; font.pixelSize: 10
        text: "+/- celda   ·   a ratio   ·   f fps   ·   h ocultar   ·   redimensiona para ver el reflujo"
      }
    }
  }
}
