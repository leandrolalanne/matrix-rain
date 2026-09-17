// Banco de pruebas: `qml6 dev/main.qml`. Abre una ventana normal, no toca el
// escritorio. Sirve para comparar contra el original en el navegador.
import QtQuick
import QtQuick.Window
import "../qml"

Window {
  width: 1280; height: 720
  visible: true
  title: "matrix rain - classic (port nativo)"
  color: "black"

  MatrixRain {
    id: rain
    anchors.fill: parent
    fps: 60
  }

  Text {
    anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
    color: "#55ff88"
    font.family: "monospace"; font.pixelSize: 11
    text: "classic · " + rain.numColumns + " cols · " + rain.fps + "fps · t=" + rain.elapsed.toFixed(1) + "s"
  }
}
