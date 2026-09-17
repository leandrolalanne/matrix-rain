// Igual que main.qml pero a pantalla completa, para comparar contra el
// original a la misma resolucion. `qml6 dev/fullscreen.qml`
import QtQuick
import QtQuick.Window
import "../qml"

Window {
  visible: true
  visibility: Window.FullScreen
  title: "matrix rain fullscreen"
  color: "black"
  MatrixRain { anchors.fill: parent; fps: 60 }
}
