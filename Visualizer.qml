import QtQuick

// Real monitor samples are supplied by the shared media service.
Item {
  id: root

  property string mode: "peak"
  property color foreground: "white"
  property bool playing: false
  property bool active: false
  property var spectrum: []
  property var waveform: []
  property var channels: []
  property var channelPeaks: []
  property real bass: 0
  property real rawBassAmplitude: 0
  property real bassLevel: 0
  property real bassReference: 0
  property var meterLevels: [0, 0]
  property var meterPeaks: [0, 0]
  property var meterHolds: [0, 0]
  property double lastTick: 0
  property int decayFrames: 0
  property var levels: []
  property var peaks: []
  property var holds: []
  readonly property int bands: Math.max(4, Math.min(16, Math.round(width / Math.max(1, height) * 4.5)))

  function reset() {
    levels = []
    peaks = []
    holds = []
    bassLevel = 0
    bassReference = 0
    meterLevels = [0, 0]
    meterPeaks = [0, 0]
    meterHolds = [0, 0]
    lastTick = 0
    canvas.requestPaint()
  }

  onModeChanged: reset()
  onBandsChanged: reset()
  onForegroundChanged: canvas.requestPaint()
  onPlayingChanged: {
    lastTick = 0
    decayFrames = playing ? 0 : 45
    canvas.requestPaint()
  }
  onActiveChanged: {
    lastTick = 0
    if (active) canvas.requestPaint()
  }

  function advance() {
    var now = Date.now()
    var dt = lastTick ? Math.max(0.001, Math.min(0.08, (now - lastTick) / 1000)) : 1 / 30
    lastTick = now
    var next = [], caps = [], waits = []
    for (var i = 0; i < bands; i++) {
      // Merge neighboring frequency bins instead of skipping bins at narrow widths.
      var target = 0
      if (playing) {
        var start = Math.floor(i * spectrum.length / bands)
        var end = Math.ceil((i + 1) * spectrum.length / bands)
        for (var bin = start; bin < end; bin++) target = Math.max(target, spectrum[bin] || 0)
        target = Math.max(0, Math.min(1, target))
      }
      var previous = levels[i] || 0
      var value = previous + (target - previous) * (1 - Math.exp(-dt * (target > previous ? 25 : 9)))
      if (value < 0.003) value = 0
      var peak = peaks[i] || 0
      var hold = Math.max(0, (holds[i] || 0) - dt)
      if (value >= peak) {
        peak = value
        hold = 0.22
      } else if (hold === 0) {
        peak = Math.max(value, peak - dt * 0.85)
      }
      next.push(value)
      caps.push(peak)
      waits.push(hold)
    }
    levels = next
    peaks = caps
    holds = waits
    var meters = [], meterCaps = [], meterWaits = []
    for (var channel = 0; channel < 2; channel++) {
      var meterTarget = playing ? (channels[channel] || 0) : 0
      var oldMeter = meterLevels[channel] || 0
      var meterValue = oldMeter + (meterTarget - oldMeter)
        * (1 - Math.exp(-dt * (meterTarget > oldMeter ? 30 : (mode === "stereo" ? 18 : 10))))
      var meterPeakTarget = playing ? (channelPeaks[channel] || 0) : 0
      var meterPeak = meterPeaks[channel] || 0
      var meterHold = Math.max(0, (meterHolds[channel] || 0) - dt)
      if (meterPeakTarget > meterPeak) {
        meterPeak = meterPeakTarget
        meterHold = mode === "stereo" ? 0.12 : 0.3
      } else if (meterHold === 0) {
        meterPeak = Math.max(meterValue, meterPeak - dt * (mode === "stereo" ? 1.4 : 0.8))
      }
      meters.push(meterValue < 0.003 ? 0 : meterValue)
      meterCaps.push(meterPeak)
      meterWaits.push(meterHold)
    }
    meterLevels = meters
    meterPeaks = meterCaps
    meterHolds = meterWaits
    // Use unclipped FFT amplitude, not the compressed display bands, and compare
    // against a slow local average so steady bass does not pin the dots.
    var bassAmplitude = playing ? Math.max(0, rawBassAmplitude) : 0
    if (bassAmplitude > 0) {
      if (bassReference <= 0) bassReference = bassAmplitude
      else bassReference += (bassAmplitude - bassReference) * (1 - Math.exp(-dt * 0.6))
    } else if (!playing) bassReference = 0
    var relativeBass = bassAmplitude / Math.max(0.008, bassReference)
    var bassTarget = Math.max(0, Math.min(1, (relativeBass - 0.55) / 1.6))
    bassLevel += (bassTarget - bassLevel) * (1 - Math.exp(-dt * (bassTarget > bassLevel ? 28 : 14)))
    if (!playing && decayFrames > 0) decayFrames--
    canvas.requestPaint()
  }

  Timer {
    interval: 33
    repeat: true
    running: root.active && (root.playing || root.decayFrames > 0)
    onTriggered: root.advance()
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = root.foreground
      ctx.strokeStyle = root.foreground
      ctx.lineWidth = 1
      ctx.lineCap = "round"
      var n = root.bands
      var step = width / n
      var base = height - 1
      var usable = Math.max(1, height - 3)

      if (root.mode === "center-pulse") {
        // Symmetric expansion from measured L/R volume, with falling peak caps.
        var volume = Math.max(root.meterLevels[0], root.meterLevels[1])
        var heldPeak = Math.max(root.meterPeaks[0], root.meterPeaks[1])
        var halfSpan = Math.max(1, width / 2 - 2)
        var reach = Math.max(3, volume * halfSpan)
        var thickness = Math.max(2, Math.round(height * 0.22))
        ctx.fillRect(width / 2 - reach, (height - thickness) / 2, reach * 2, thickness)
        if (heldPeak > volume + 0.07) {
          var capReach = Math.max(reach + 1, heldPeak * halfSpan)
          ctx.fillRect(width / 2 - capReach - 1, (height - thickness) / 2 - 1, 1, thickness + 2)
          ctx.fillRect(width / 2 + capReach, (height - thickness) / 2 - 1, 1, thickness + 2)
        }
        return
      }

      if (root.mode === "stereo") {
        // Upper strip is left, lower strip is right. Both retain peak caps.
        var cells = 8
        var cellStep = width / cells
        var thickness = Math.max(2, Math.floor(height * 0.28))
        for (var channel = 0; channel < 2; channel++) {
          var top = Math.round(height * (channel === 0 ? 0.13 : 0.59))
          var lit = Math.floor(root.meterLevels[channel] * cells)
          var cap = root.meterPeaks[channel] > 0.01
            ? Math.min(cells - 1, Math.floor(root.meterPeaks[channel] * cells)) : -1
          for (var cell = 0; cell < cells; cell++) {
            // Keep a centered three-segment strip visible after the peaks decay.
            // This is a static resting mark, not fabricated audio activity.
            var resting = !root.playing && cell >= 2 && cell <= 4
            ctx.globalAlpha = cell < lit || cell === cap || resting ? 1 : 0.12
            ctx.fillRect(Math.floor(cell * cellStep), top, Math.max(1, Math.floor(cellStep) - 1), thickness)
          }
        }
        ctx.globalAlpha = 1
        return
      }

      if (root.mode === "breathing-dots") {
        // Fixed 9x3 grid: bass lights more dots from the center outward.
        // Neither spacing nor dot size changes; pause leaves three centered dots.
        var extent = 0.035 + root.bassLevel * 1.05
        var stepX = Math.min((width - 3) / 8, (height - 3) / 2)
        var stepY = stepX
        var radius = Math.max(0.5, stepX * 0.23)
        for (var dotY = -1; dotY <= 1; dotY++) {
          for (var dotX = -4; dotX <= 4; dotX++) {
            var distance = Math.sqrt(dotX * dotX / 16 + dotY * dotY) / Math.sqrt(2)
            if (!root.playing) {
              if (dotY !== 0 || Math.abs(dotX) > 1) continue
            } else if (distance > extent) continue
            ctx.beginPath()
            ctx.arc(width / 2 + dotX * stepX, height / 2 + dotY * stepY, radius, 0, Math.PI * 2)
            ctx.fill()
          }
        }
        return
      }

      if (root.mode === "outline") {
        ctx.lineWidth = 1.3
        ctx.lineJoin = "round"
        ctx.beginPath()
        for (var point = 0; point < n; point++) {
          var pointX = 1 + point / Math.max(1, n - 1) * (width - 2)
          var pointY = base - (root.levels[point] || 0) * usable
          if (point === 0) ctx.moveTo(pointX, pointY)
          else ctx.lineTo(pointX, pointY)
        }
        ctx.stroke()
        return
      }

      if (root.mode === "scope") {
        // Draw actual PCM samples, not a curve synthesized from spectrum bins.
        ctx.lineWidth = 1.4
        ctx.beginPath()
        for (var x = 0; x <= width; x++) {
          var sampleIndex = Math.min(root.waveform.length - 1,
            Math.floor(x / Math.max(1, width) * root.waveform.length))
          var signal = root.playing && sampleIndex >= 0 ? root.waveform[sampleIndex] : 0
          var y = height / 2 - signal * usable / 2
          if (x === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
        ctx.stroke()
        return
      }

      for (var i = 0; i < n; i++) {
        var level = root.levels[i] || 0
        var peak = root.peaks[i] || 0
        var left = Math.floor(i * step)
        var barWidth = Math.max(1, Math.floor(step) - 2)
        if (root.mode === "led") {
          var rows = 5
          var cell = Math.max(1, Math.floor(usable / rows))
          // A low LED baseline remains visible in the paused, dimmed bar.
          var lit = Math.max(root.playing ? 0 : 1, Math.round(level * rows))
          var capRow = Math.min(rows - 1, Math.floor(peak * rows))
          for (var r = 0; r < rows; r++) {
            var isPeak = peak > level + 0.08 && r === capRow
            ctx.globalAlpha = r < lit || isPeak ? 1 : 0.12
            ctx.fillRect(left, base - (r + 1) * cell, barWidth, Math.max(1, cell - 1))
          }
          ctx.globalAlpha = 1
        } else if (root.mode === "wave") {
          var size = Math.max(2, level * usable)
          ctx.fillRect(left, Math.round((height - size) / 2), barWidth, Math.round(size))
        } else {
          var body = Math.max(1, Math.round(level * usable))
          ctx.fillRect(left, base - body, barWidth, body)
          if (peak > level + 0.04) {
            ctx.fillRect(left, Math.max(0, Math.round(base - peak * usable) - 1), barWidth, 1)
          }
        }
      }
    }
  }
}
