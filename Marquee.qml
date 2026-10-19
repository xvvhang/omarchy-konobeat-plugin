import QtQuick

// Two copies keep long metadata readable without a blank traversal interval.
Item {
  id: root
  property string text: ""
  property color color: "white"
  property alias font: first.font
  property bool active: true
  property real speed: 28
  property real gap: 28
  readonly property bool overflowing: first.implicitWidth > width + 0.5
  readonly property bool scrolling: motion.running
  readonly property real textWidth: first.implicitWidth
  property real offset: 0
  implicitHeight: first.implicitHeight
  implicitWidth: first.implicitWidth
  clip: true

  function reset() {
    motion.stop()
    offset = 0
    if (active && overflowing) motion.start()
  }
  onTextChanged: Qt.callLater(reset)
  onWidthChanged: Qt.callLater(reset)
  onActiveChanged: Qt.callLater(reset)
  onTextWidthChanged: Qt.callLater(reset)
  Component.onCompleted: Qt.callLater(reset)

  SequentialAnimation {
    id: motion
    loops: Animation.Infinite
    PauseAnimation { duration: 1000 }
    NumberAnimation {
      target: root
      property: "offset"
      from: 0
      to: -(first.implicitWidth + root.gap)
      duration: Math.max(1500, (first.implicitWidth + root.gap) / root.speed * 1000)
      easing.type: Easing.Linear
    }
  }

  Text {
    id: first
    textFormat: Text.PlainText
    text: root.text
    color: root.color
    x: root.offset
    anchors.verticalCenter: parent.verticalCenter
  }
  Text {
    visible: root.overflowing
    textFormat: Text.PlainText
    text: root.text
    font: first.font
    color: root.color
    x: root.offset + first.implicitWidth + root.gap
    anchors.verticalCenter: parent.verticalCenter
  }
}
