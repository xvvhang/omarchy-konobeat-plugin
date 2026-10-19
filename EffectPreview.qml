import QtQuick

// Static thumbnails: distinct illustrations without extra live audio renderers.
Canvas {
  id: root
  property string mode: "peak"
  property color foreground: "white"
  onModeChanged: requestPaint()
  onForegroundChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.fillStyle = foreground
    ctx.strokeStyle = foreground
    ctx.lineWidth = 1.3
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    var values = [0.25, 0.5, 0.85, 0.6, 0.35, 0.7, 0.95, 0.4]
    var base = height - 1
    var span = height - 4

    if (mode === "breathing-dots") {
      var dotStep = Math.min((width - 3) / 8, height / 5)
      for (var dotY = -1; dotY <= 1; dotY++) {
        for (var dotX = -4; dotX <= 4; dotX++) {
          // Show a partially lit fixed grid, with the outer corners off.
          if (dotX * dotX / 16 + dotY * dotY > 1.4) continue
          ctx.beginPath()
          ctx.arc(width / 2 + dotX * dotStep,
            height / 2 + dotY * dotStep, dotStep * 0.23, 0, Math.PI * 2)
          ctx.fill()
        }
      }
    } else if (mode === "scope" || mode === "outline") {
      ctx.beginPath()
      for (var x = 1; x < width; x++) {
        var signal = mode === "scope"
          ? Math.sin(x / width * Math.PI * 5) * 0.65 + Math.sin(x / width * Math.PI * 11) * 0.2 : 0
        var y = mode === "scope" ? height / 2 - signal * span / 2
          : base - values[Math.min(7, Math.floor(x / width * 8))] * span
        if (x === 1) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }
      ctx.stroke()
    } else if (mode === "center-pulse") {
      ctx.fillRect(width * 0.2, height / 2 - 2, width * 0.6, 4)
      ctx.fillRect(width * 0.1, height / 2 - 4, 1, 8)
      ctx.fillRect(width * 0.9 - 1, height / 2 - 4, 1, 8)
    } else if (mode === "stereo") {
      for (var channel = 0; channel < 2; channel++) {
        for (var cell = 0; cell < (channel === 0 ? 7 : 5); cell++)
          ctx.fillRect(cell * width / 8, channel === 0 ? 3 : 11, width / 8 - 1, 4)
      }
    } else {
      for (var i = 0; i < values.length; i++) {
        var left = i * width / values.length
        var barWidth = width / values.length - 2
        var size = values[i] * span
        if (mode === "led") {
          for (var row = 0; row < Math.round(values[i] * 5); row++)
            ctx.fillRect(left, base - (row + 1) * 3, barWidth, 2)
        } else if (mode === "wave") {
          ctx.fillRect(left, (height - size) / 2, barWidth, size)
        } else {
          ctx.fillRect(left, base - size, barWidth, size)
          ctx.fillRect(left, Math.max(0, base - size - 3), barWidth, 1)
        }
      }
    }
  }
}
