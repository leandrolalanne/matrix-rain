// Grab a frame of the rain to a PNG, with no visible window and no window
// manager in the way. `grabToImage` renders the item into its own buffer, so
// the result does not depend on the item being visible, on which workspace it
// lands, or on how the compositor tiles it.
//
// Usage: qml6 dev/grab.qml -- out=<file.png> [key=value ...]
//
//   out         output path (required)
//   w, h        size in logical pixels        (default 1280x720)
//   settle      seconds to let the rain fill  (default 8)
//   version     classic | megacity | resurrections
//   fontSize    overrides the version's
//   advance     font advance in em
//   resolution  render fraction
//   intro       true plays the intro from a blank screen
import QtQuick
import QtQuick.Window
import "../qml"
import "../qml/Versions.js" as Versions

Window {
  id: win
  width: 320; height: 180
  visible: true
  title: "matrix rain grab"
  color: "black"

  property var opts: ({})
  property string outPath: "out.png"

  function opt(k, d) { return opts[k] !== undefined ? opts[k] : d }
  function num(k, d) { return opts[k] !== undefined ? parseFloat(opts[k]) : d }

  Component.onCompleted: {
    var args = Qt.application.arguments
    var i = args.indexOf("--")
    var rest = i >= 0 ? args.slice(i + 1) : []
    var o = {}
    for (var j = 0; j < rest.length; j++) {
      var eq = rest[j].indexOf("=")
      if (eq > 0) o[rest[j].substring(0, eq)] = rest[j].substring(eq + 1)
      else if (j === 0) o.out = rest[j]   // tolerate a bare path as the first arg
    }
    opts = o
    outPath = opt("out", "out.png")
    console.log("grab: " + rain.width + "x" + rain.height
                + " version=" + rain.version + " fontSize=" + rain.fontSize.toFixed(1)
                + " intro=" + !rain.skipIntro + " -> " + outPath)
    grabTimer.interval = Math.max(500, num("settle", 8) * 1000)
    grabTimer.start()
  }

  // The item deliberately lives outside the visible window: it still renders
  // because grabToImage draws it into a buffer of its own.
  MatrixRain {
    id: rain
    width: win.num("w", 1280)
    height: win.num("h", 720)
    fps: 60
    version: win.opt("version", "classic")
    resolution: win.num("resolution", 1.0)
    fontAdvanceEm: win.num("advance", 0.934)
    skipIntro: win.opt("intro", "false") !== "true"
    // 0 means "leave the version's value alone".
    fontSize: win.num("fontSize", 0) > 0 ? win.num("fontSize", 0) : Versions.pick(version, "fontSize", 9)
  }

  Timer {
    id: grabTimer
    repeat: false
    // Give the rain a moment first: freshly born it has gaps and the grab would
    // come out sparse.
    onTriggered: rain.grabToImage(function(r) {
      console.log(r.saveToFile(win.outPath) ? "ok" : "ERROR writing file")
      Qt.quit()
    }, Qt.size(rain.width, rain.height))
  }
}
