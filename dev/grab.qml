// Grab a frame of the rain to a PNG, with no visible window and no window
// manager in the way. `grabToImage` renders the item into its own buffer, so
// the result does not depend on the item being visible, on which workspace it
// lands, or on how the compositor tiles it.
//
// Usage: qml6 dev/grab.qml -- <out.png> [width] [height] [seconds] [resolution] [fontSize] [fontAdvanceEm]
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
  property real fsize: 9
  property real advEm: 0.934

  Component.onCompleted: {
    var args = Qt.application.arguments
    var i = args.indexOf("--")
    var rest = i >= 0 ? args.slice(i + 1) : []
    if (rest.length > 0) outPath = rest[0]
    if (rest.length > 1) outW = parseInt(rest[1])
    if (rest.length > 2) outH = parseInt(rest[2])
    if (rest.length > 3) settle = parseFloat(rest[3])
    if (rest.length > 4) res = parseFloat(rest[4])
    if (rest.length > 5) fsize = parseFloat(rest[5])
    if (rest.length > 6) advEm = parseFloat(rest[6])
    console.log("grab: " + outW + "x" + outH + " res=" + res + " fontSize=" + fsize + "pt advance=" + advEm + "em -> " + outPath)
    grabTimer.interval = Math.max(500, settle * 1000)
    grabTimer.start()
  }

  // The item deliberately lives outside the visible window: it still renders
  // because grabToImage draws it into a buffer of its own.
  MatrixRain {
    id: rain
    width: win.outW
    height: win.outH
    fps: 60
    resolution: win.res
    fontSize: win.fsize
    fontAdvanceEm: win.advEm
  }

  Timer {
    id: grabTimer
    repeat: false
    // Give the rain a moment first: freshly born it has gaps and the grab would
    // come out sparse.
    onTriggered: rain.grabToImage(function(r) {
      console.log(r.saveToFile(win.outPath) ? "ok" : "ERROR writing file")
      Qt.quit()
    }, Qt.size(win.outW, win.outH))
  }
}
