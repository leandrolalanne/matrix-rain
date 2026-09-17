// Genera el PNG marcador sin depender de la pantalla.
//
// `grim` captura lo que esta compuesto en el monitor, asi que sirve solo si la
// ventana esta visible — y si estas usando la maquina, termina capturando tu
// escritorio. `Item.grabToImage()` renderiza el item a una imagen por su cuenta,
// al tamaño que le pidas y sin cursor ni ventanas encima.
//
// Uso:  qml6 dev/grab-marker.qml -- <ruta-de-salida> [ancho] [alto] [segundos]
import QtQuick
import QtQuick.Window
import "../qml"

Window {
  id: win
  // Chica y sin decoracion: solo hace falta que exista para que Qt tenga un
  // contexto de render. Lo que se captura es el item, no la ventana.
  width: 320; height: 180
  visible: true
  title: "matrix rain marker"
  color: "black"

  property string outPath: "marker.png"
  property int outW: 1920
  property int outH: 1080
  property real settle: 8.0

  Component.onCompleted: {
    var args = Qt.application.arguments
    var rest = args.slice(args.indexOf("--") + 1)
    if (args.indexOf("--") >= 0 && rest.length > 0) {
      outPath = rest[0]
      if (rest.length > 1) outW = parseInt(rest[1])
      if (rest.length > 2) outH = parseInt(rest[2])
      if (rest.length > 3) settle = parseFloat(rest[3])
    }
    console.log("marker: " + outW + "x" + outH + " -> " + outPath)
    grabTimer.interval = Math.max(500, settle * 1000)
    grabTimer.start()
  }

  // El item vive fuera de la ventana visible a proposito: se renderiza igual
  // porque grabToImage lo dibuja en su propio buffer.
  MatrixRain {
    id: rain
    width: win.outW
    height: win.outH
    fps: 60
  }

  Timer {
    id: grabTimer
    repeat: false
    // Un rato antes de capturar: recien nacida la lluvia tiene huecos y el
    // marcador saldria ralo.
    onTriggered: {
      rain.grabToImage(function(result) {
        if (result.saveToFile(win.outPath)) {
          console.log("ok")
        } else {
          console.log("ERROR: no pude escribir " + win.outPath)
        }
        Qt.quit()
      }, Qt.size(win.outW, win.outH))
    }
  }
}
