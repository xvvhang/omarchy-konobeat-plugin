import QtQuick
import qs.Ui
import qs.Commons

// Identical hitboxes and a shared vector grid avoid mismatched font glyph metrics.
Button {
  id: root
  property string action: "play"
  property bool playing: false
  width: Style.space(40)
  height: Style.space(40)
  focusable: true
  background: Style.normalFillFor(foreground, Color.accent)
  tooltipText: action === "previous" ? "Previous" : action === "next" ? "Next" : playing ? "Pause" : "Play"
  onActionChanged: icon.requestPaint()
  onPlayingChanged: icon.requestPaint()
  onForegroundChanged: icon.requestPaint()

  Canvas {
    id: icon
    anchors.centerIn: parent
    width: Style.space(22)
    height: width
    onWidthChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      ctx.scale(width / 24, height / 24)
      ctx.fillStyle = root.foreground
      if (root.action === "previous") {
        ctx.fillRect(3, 3, 3, 18)
        ctx.beginPath()
        ctx.moveTo(7, 12)
        ctx.lineTo(21, 3)
        ctx.lineTo(21, 21)
        ctx.closePath()
        ctx.fill()
      } else if (root.action === "next") {
        ctx.fillRect(18, 3, 3, 18)
        ctx.beginPath()
        ctx.moveTo(17, 12)
        ctx.lineTo(3, 3)
        ctx.lineTo(3, 21)
        ctx.closePath()
        ctx.fill()
      } else if (root.playing) {
        ctx.fillRect(5, 3, 5, 18)
        ctx.fillRect(14, 3, 5, 18)
      } else {
        ctx.beginPath()
        ctx.moveTo(7, 3)
        ctx.lineTo(22, 12)
        ctx.lineTo(7, 21)
        ctx.closePath()
        ctx.fill()
      }
    }
  }
}
