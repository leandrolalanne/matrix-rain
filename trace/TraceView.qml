// The trace program, as a QML item: the field of digits from the film's
// opening, cycling in place until the trace closes and they lock onto an
// address. Built to sit behind something else -- a lock screen, a login -- so
// it draws only the field and takes no input.
//
// The numbers are the ones measured off a frame; trace/README.md carries the
// method and the caveats. In short: 9 columns to a block, a gap of about 1.7
// column widths, cells very nearly square, ~9% of the field bright, and a hue
// of 159-161 that is fifty degrees off the rain's 108.
//
// Text items rather than a shader, deliberately. The rain needs a shader
// because every cell changes every frame; this holds each digit for a tenth of
// a second by design, so the scene graph has almost nothing to do between
// ticks. It is also readable, which a shader is not.

// Bound, so the delegate below reaches `root` explicitly instead of relying on
// the implicit lookup Qt now warns about.
pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: root

  // Stop when the view is not really on screen. The lock passes its own
  // `loadBackground` in, which already means exactly that.
  property bool running: true

  // What the trace resolves to. Empty means it never resolves: the field just
  // cycles, which is what you want behind a login that may sit for hours.
  property string target: ""

  property real cycleFor: 4.0     // seconds of free cycling
  property real lockFor: 3.0      // seconds of the lock sweeping across
  property real holdFor: 3.0      // seconds holding the answer, then round again

  // --- measured off the frame ----------------------------------------------

  readonly property int colsPerBlock: 9
  readonly property real gapInCells: 1.7
  readonly property real cellAspect: 38 / 40      // very nearly square
  readonly property real brightShare: 0.09

  readonly property color dim: "#1a3a30"
  readonly property color mid: "#295b4b"
  readonly property color bright: "#74c0a5"
  readonly property color peak: "#c4ffe8"

  // Five blocks across, which is what the frame has, so the field reads the
  // same on any screen. The cell follows the WIDTH -- fix the height instead
  // and a 16:9 screen gives three blocks and the structure is lost. Rows then
  // fall out of whatever height is left, which on 16:9 is denser than the
  // film's ~20 because its frame is much wider than a monitor.
  readonly property int blocks: 5
  readonly property real cellW: width / (blocks * colsPerBlock + (blocks - 1) * gapInCells)
  readonly property real cellH: cellW / cellAspect
  readonly property real blockW: colsPerBlock * cellW
  readonly property real gapW: gapInCells * cellW
  readonly property int cols: blocks * colsPerBlock
  readonly property int rows: Math.max(1, Math.round(height / cellH))
  readonly property real marginX: (width - (blocks * blockW + (blocks - 1) * gapW)) / 2

  readonly property var digits: String(target).replace(/[^0-9]/g, "")

  // --- the clock -----------------------------------------------------------

  property real t: 0
  property int tick: 0

  readonly property real period: cycleFor + lockFor + holdFor
  // 0 while cycling, 0..1 as the lock sweeps, 1 once it has landed.
  readonly property real phase: {
    if (digits.length === 0) return 0
    var loop = t % period
    if (loop < cycleFor) return 0
    if (loop < cycleFor + lockFor) return (loop - cycleFor) / lockFor
    return 1
  }
  readonly property bool resolved: phase >= 0.55

  Timer {
    // Ten a second: the film holds each digit about that long, and it keeps
    // the lock screen cheap.
    interval: 100
    running: root.running && root.visible
    repeat: true
    onTriggered: { root.t += 0.1; root.tick++ }
  }

  // --- per-cell values ------------------------------------------------------

  // Deterministic hash, the same one the terminal renderer uses, so a cell does
  // not flicker when something else repaints.
  // Math.imul, not `*`. A 32-bit multiply overflows past 2^53 as a double and
  // JavaScript silently drops the low bits -- which came out as a field of
  // nothing but even digits, since the last bit was always the same.
  function hash(a, b, c) {
    var h = (Math.imul(a, 73856093) ^ Math.imul(b, 19349663) ^ Math.imul(c, 83492791)) >>> 0
    h = (h ^ (h >>> 13)) >>> 0
    h = Math.imul(h, 1274126177) >>> 0
    return h
  }

  function digitAt(x, y, step) { return (hash(x, y, step) >>> 7) % 10 }

  // Locking sweeps left to right with enough jitter that the edge is ragged
  // rather than a wipe.
  function lockAt(x, y) {
    var across = cols > 1 ? x / (cols - 1) : 0
    return across * 0.75 + ((hash(x, y, 7717) % 1000) / 1000) * 0.35
  }

  function tierOf(x, y) {
    var r = (hash(x, y, 4242) % 1000) / 1000
    if (r < brightShare) return bright
    return r < brightShare + 0.62 ? mid : dim
  }

  // Where the address sits once it resolves: centred, one digit to a cell.
  function addressDigit(x, y) {
    if (!resolved || digits.length === 0 || digits.length > cols) return -1
    if (y !== Math.floor(rows / 2)) return -1
    var x0 = Math.floor((cols - digits.length) / 2)
    return (x >= x0 && x < x0 + digits.length) ? parseInt(digits[x - x0]) : -1
  }

  // --- the field ------------------------------------------------------------

  // Its own background. Behind a lock screen there is nothing underneath to
  // show through, and a transparent item grabs as white.
  Rectangle {
    anchors.fill: parent
    color: "#02060a"
  }

  Repeater {
    model: root.cols * root.rows

    Text {
      // Declared rather than implicitly injected, which Qt 6 warns about.
      required property int index

      readonly property int cx: index % root.cols
      readonly property int cy: Math.floor(index / root.cols)
      readonly property int block: Math.floor(cx / root.colsPerBlock)
      readonly property int addr: root.addressDigit(cx, cy)
      readonly property bool locked: root.phase >= root.lockAt(cx, cy)

      x: root.marginX + block * (root.blockW + root.gapW)
         + (cx % root.colsPerBlock) * root.cellW
      y: cy * root.cellH
      width: root.cellW
      height: root.cellH
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter

      font.family: "Courier Prime"
      font.pixelSize: root.cellH * 0.62
      font.bold: true

      text: locked
        ? (addr >= 0 ? addr : root.digitAt(cx, cy, 99991))
        : root.digitAt(cx, cy, root.tick + ((cx * 7 + cy * 13) % 5))

      // The field keeps its tiers once the trace lands. Dimming everything to
      // make the answer stand out sounded right and looked wrong: the frame
      // this is measured from has the grid plainly lit all around the box, and
      // behind a lock screen a field that goes black is just a black screen.
      color: addr >= 0 ? root.peak : root.tierOf(cx, cy)

      Behavior on color { ColorAnimation { duration: 180 } }
    }
  }
}
