// Grab a frame of the trace to a PNG, the same way dev/grab.qml does it for the
// rain: grabToImage renders the item into a buffer of its own, so the result
// does not depend on the item being visible, on which workspace it lands, or on
// how the compositor tiles it.
//
// A small window still appears while it runs. Qt needs a real GL context, and
// under QT_QPA_PLATFORM=offscreen every frame comes back black with no error.
//
// Usage: qml6 dev/grab-trace.qml -- out=<file.png> [key=value ...]
//
//   out       output path (required)
//   w, h      size in logical pixels          (default 1280x720)
//   at        seconds into the cycle to grab  (default 8.5, mid-resolve)
//   target    what it resolves to             (default 192.168.2.68)

import QtQuick
import QtQuick.Window
import "../trace"

Window {
  id: win
  width: 320; height: 180
  visible: true
  title: "trace grab"
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
      else if (j === 0) o.out = rest[j]
    }
    opts = o
    outPath = opt("out", "out.png")
    // Wind the clock forward rather than waiting: the view is driven by `t`,
    // so a grab at any moment of the cycle costs the same.
    trace.t = num("at", 8.5)
    console.log("trace grab: " + trace.width + "x" + trace.height
                + " blocks=" + trace.blocks + " cols=" + trace.cols
                + " rows=" + trace.rows + " t=" + trace.t.toFixed(1)
                + " phase=" + trace.phase.toFixed(2) + " -> " + outPath)
    grabTimer.start()
  }

  TraceView {
    id: trace
    width: win.num("w", 1280)
    height: win.num("h", 720)
    target: win.opt("target", "192.168.2.68")
    running: false        // the grab sets `t` itself; no ticking needed
  }

  Timer {
    id: grabTimer
    interval: 600         // one beat for the text to lay out
    repeat: false
    onTriggered: trace.grabToImage(function (r) {
      console.log(r.saveToFile(win.outPath) ? "ok" : "ERROR writing file")
      Qt.quit()
    }, Qt.size(trace.width, trace.height))
  }
}
