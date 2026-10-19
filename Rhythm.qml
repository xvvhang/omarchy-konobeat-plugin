import QtQuick

// Compact decorative playback indicators; no audio is captured.
Item {
  id: root

  property string mode: "breathing-bars"
  property color foreground: "white"
  property bool playing: false
  property bool active: false
  property real phase: 0
  property real amount: playing ? 1 : 0
  readonly property bool animating: motion.running
  readonly property real breath: (1 - Math.cos(phase)) / 2

  Behavior on amount {
    NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
  }

  NumberAnimation on phase {
    id: motion
    from: 0
    to: Math.PI * 2
    duration: root.mode === "wave" ? 1600 : 2600
    loops: Animation.Infinite
    running: root.active && root.playing && root.mode !== "none"
  }

  Rectangle {
    visible: root.mode === "breathing-dot"
    anchors.centerIn: parent
    width: root.width * (0.25 + root.amount * (0.1 + root.breath * 0.3))
    height: width
    radius: width / 2
    color: root.foreground
  }

  Row {
    anchors.centerIn: parent
    spacing: root.width / 9
    visible: root.mode === "wave" || root.mode === "breathing-bars"

    Repeater {
      model: root.mode === "wave" ? 4 : 3

      Rectangle {
        required property int index
        readonly property bool wave: root.mode === "wave"
        readonly property real envelope: wave
          ? 0.15 + 0.85 * Math.abs(Math.sin(root.phase + index * 0.8)
              * Math.cos(root.phase * 2 - index * 0.45))
          : (index === 1 ? 1 : 0.7) * (0.3 + 0.7 * root.breath)
        width: root.width / (wave ? 6 : 5)
        height: Math.max(2, root.height * (0.14 + root.amount * envelope * 0.86))
        anchors.verticalCenter: parent.verticalCenter
        radius: width / 2
        color: root.foreground
      }
    }
  }
}
