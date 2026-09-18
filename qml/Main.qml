// The application entry point: the rain, fullscreen, arriving from a blank
// screen. This is what the installed command runs.
//
// Keys:
//   q / Esc   quit
//   v         next version
//   i         replay the intro
//   f         toggle 30/60 fps
//   h         show or hide the hint
import QtQuick
import QtQuick.Window
import "Versions.js" as Versions

Window {
  id: app
  visible: true
  visibility: Window.FullScreen
  title: "Enter the Matrix"
  color: "black"

  // Set by the launcher as `-- version=<name>`; empty means the default.
  property string startVersion: ""

  readonly property var names: Versions.names()
  property int idx: 0

  Component.onCompleted: {
    var args = Qt.application.arguments
    var i = args.indexOf("--")
    if (i >= 0) {
      for (var j = i + 1; j < args.length; j++) {
        if (args[j].indexOf("version=") === 0) startVersion = args[j].substring(8)
      }
    }
    var at = names.indexOf(startVersion !== "" ? startVersion : "classic")
    idx = at >= 0 ? at : 0
  }

  MatrixRain {
    id: rain
    anchors.fill: parent
    fps: 60
    version: app.names[app.idx]
    // Every launch should feel like entering.
    skipIntro: false
  }

  MouseArea {
    anchors.fill: parent
    // A fullscreen toy has no business showing a pointer.
    cursorShape: Qt.BlankCursor
    acceptedButtons: Qt.NoButton
  }

  Item {
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Q || e.key === Qt.Key_Escape) Qt.quit()
      else if (e.key === Qt.Key_V) { app.idx = (app.idx + 1) % app.names.length; rain.restart() }
      else if (e.key === Qt.Key_I) rain.restart()
      else if (e.key === Qt.Key_F) rain.fps = rain.fps === 60 ? 30 : 60
      else if (e.key === Qt.Key_H) hint.shown = !hint.shown
    }
  }

  // Fades out on its own: it is a reminder, not a UI.
  Text {
    id: hint
    property bool shown: true
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 28 }
    color: "#4fa85f"
    font.family: "monospace"; font.pixelSize: 13
    text: rain._v.label + "   ·   v next version   ·   i intro   ·   q quit"
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 600 } }
    Timer { running: true; interval: 6000; onTriggered: hint.shown = false }
  }
}
