import QtQuick
import qs.Ui
import qs.Commons

Column {
  id: root
  required property var player
  required property var bar
  property bool active: false
  property real position: 0
  property var dragPlayer: null
  property int dragTrack: -1
  readonly property real duration: player && player.lengthSupported ? Number(player.length) : 0
  // Reject unknown/live-stream lengths, including Chromium's INT64_MAX sentinel.
  readonly property bool available: !!(player && player.positionSupported
    && player.lengthSupported && isFinite(duration) && duration > 0 && duration < 31536000)
  readonly property bool seekable: available && player.canSeek
  visible: available
  spacing: Style.space(2)

  function formatTime(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0))
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor(total / 60) % 60
    var secs = String(total % 60).padStart(2, "0")
    return hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") + ":" + secs
      : Math.floor(total / 60) + ":" + secs
  }

  function refresh() {
    var current = available ? Number(player.position) : 0
    position = isFinite(current) ? Math.max(0, Math.min(duration, current)) : 0
  }

  function cancelDrag() {
    slider.dragging = false
    dragPlayer = null
    refresh()
    slider.liveValue = position
  }

  function commit(seconds) {
    // Do not seek a new source or a new track if it changed during a drag.
    if (seekable && dragPlayer === player && dragTrack === player.uniqueId) {
      player.position = Math.max(0, Math.min(duration, seconds))
      refresh()
    }
    dragPlayer = null
  }

  onPlayerChanged: cancelDrag()
  onActiveChanged: {
    if (active) refresh()
    else cancelDrag()
  }
  onAvailableChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: root.player
    function onPositionChanged() { root.refresh() }
    function onLengthChanged() { root.refresh() }
    function onUniqueIdChanged() { root.cancelDrag() }
  }

  Timer {
    interval: 500
    repeat: true
    running: root.active && root.available && root.player.isPlaying
    // MPRIS position advances on read rather than emitting updates every frame.
    onTriggered: root.refresh()
  }

  PanelSlider {
    id: slider
    width: parent.width
    bar: root.bar
    minimum: 0
    maximum: Math.max(1, root.duration)
    step: 5
    value: root.position
    enabled: root.seekable
    trackHeight: Style.space(3)
    knobSize: root.seekable ? Style.space(10) : 0
    onDraggingChanged: if (dragging) {
      root.dragPlayer = root.player
      root.dragTrack = root.player.uniqueId
    }
    onReleased: function(value) { root.commit(value) }
    // PanelSlider also supports wheel seeking without a drag-start signal.
    onMoved: if (!dragging) {
      root.dragPlayer = root.player
      root.dragTrack = root.player.uniqueId
    }
  }

  Item {
    width: parent.width
    height: elapsed.implicitHeight

    Text {
      id: elapsed
      anchors.left: parent.left
      text: root.formatTime(slider.dragging ? slider.liveValue : root.position)
      color: root.bar.foreground
      opacity: 0.65
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
    Text {
      anchors.right: parent.right
      text: root.formatTime(root.duration)
      color: root.bar.foreground
      opacity: 0.65
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
