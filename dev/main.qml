// Test bench: `qml6 dev/main.qml` (or `tools/preview.sh`).
// Opens a normal window; it does not touch the desktop.
//
// Resize it to see the terminal model: the column count changes, the glyph size
// does not.
//
// Keys:
//   v       cycle the version (classic, megacity, resurrections)
//   i       replay the intro, from a blank screen
//   + / -   raise and lower the font size, in points
//   a       cycle the cell advance between the three real options
//   f       toggle 30/60 fps
//   h       show or hide this overlay
import QtQuick
import QtQuick.Window
import "../qml"
import "../qml/Versions.js" as Versions

Window {
  id: win
  width: 1280; height: 720
  visible: true
  title: "matrix rain - classic (native port)"
  color: "black"

  // Font advance in em. All three come from parsing real TTFs.
  readonly property var ratios: [
    { v: 0.934, n: "Matrix-Code.ttf" },
    { v: 0.909, n: "2 JetBrainsMono cells (fullwidth)" },
    { v: 0.455, n: "1 JetBrainsMono cell (squashes 51%)" }
  ]
  property int ratioIdx: 0
  readonly property var versionNames: Versions.names()
  property int versionIdx: 0

  MatrixRain {
    id: rain
    anchors.fill: parent
    fps: 60
    fontAdvanceEm: win.ratios[win.ratioIdx].v
    version: win.versionNames[win.versionIdx]
  }

  Item {
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_V) {
        win.versionIdx = (win.versionIdx + 1) % win.versionNames.length
        rain.fontSize = Qt.binding(function() { return Versions.pick(rain.version, "fontSize", 9) })
      }
      else if (e.key === Qt.Key_I) { rain.skipIntro = false; rain.restart(); rain.skipIntro = false }
      else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) rain.fontSize = Math.min(60, rain.fontSize + 1)
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
        text: rain._v.label + "   font-size " + rain.fontSize.toFixed(0) + "pt   cell " + rain.cellHeight.toFixed(1) + " x " + rain.cellWidth.toFixed(1) + " px"
            + "   grid " + Math.floor(rain.numColumns) + " x " + Math.floor(rain.numRows)
            + "   window " + win.width + "x" + win.height
      }
      Text {
        color: "#4fa85f"; font.family: "monospace"; font.pixelSize: 11
        text: "advance " + rain.fontAdvanceEm.toFixed(3) + "em  " + win.ratios[win.ratioIdx].n
            + "   ·   " + rain.fps + "fps   t=" + rain.elapsed.toFixed(0) + "s"
      }
      Text {
        color: "#2f6b3a"; font.family: "monospace"; font.pixelSize: 10
        text: "v version   ·   i intro   ·   +/- points   ·   a advance   ·   f fps   ·   h hide   ·   resize to reflow"
      }
    }
  }
}
