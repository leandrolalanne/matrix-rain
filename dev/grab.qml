// Captura un cuadro de la lluvia a un PNG, sin ventana visible ni gestor de
// ventanas de por medio. `grabToImage` renderiza el item a su propio buffer,
// asi que el resultado no depende de que este tapado, ni de en que workspace
// caiga, ni de como lo tile Hyprland.
//
// Uso: qml6 dev/grab.qml -- <salida.png> [ancho] [alto] [segundos] [resolution] [cellHeight] [cellAspect]
import QtQuick
import QtQuick.Window
import "../qml"

Window {
  id: win
  width: 320; height: 180
  visible: true
  title: "matrix rain grab"
  color: "black"

  property string outPath: "out.png"
  property int outW: 1280
  property int outH: 720
  property real settle: 8.0
  property real res: 1.0
  property real cellH: 20
  property real cellA: 0.934

  Component.onCompleted: {
    var args = Qt.application.arguments
    var i = args.indexOf("--")
    var rest = i >= 0 ? args.slice(i + 1) : []
    if (rest.length > 0) outPath = rest[0]
    if (rest.length > 1) outW = parseInt(rest[1])
    if (rest.length > 2) outH = parseInt(rest[2])
    if (rest.length > 3) settle = parseFloat(rest[3])
    if (rest.length > 4) res = parseFloat(rest[4])
    if (rest.length > 5) cellH = parseFloat(rest[5])
    if (rest.length > 6) cellA = parseFloat(rest[6])
    console.log("grab: " + outW + "x" + outH + " res=" + res + " cellH=" + cellH + " aspect=" + cellA + " -> " + outPath)
    grabTimer.interval = Math.max(500, settle * 1000)
    grabTimer.start()
  }

  MatrixRain {
    id: rain
    width: win.outW
    height: win.outH
    fps: 60
    resolution: win.res
    cellHeight: win.cellH
    cellAspect: win.cellA
  }

  Timer {
    id: grabTimer
    repeat: false
    onTriggered: rain.grabToImage(function(r) {
      console.log(r.saveToFile(win.outPath) ? "ok" : "ERROR al escribir")
      Qt.quit()
    }, Qt.size(win.outW, win.outH))
  }
}
