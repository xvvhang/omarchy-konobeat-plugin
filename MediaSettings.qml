import QtQuick
import qs.Ui
import qs.Commons

Column {
  id: root
  required property var host
  spacing: Style.space(12)

  Text {
    text: "BAR LABEL"
    color: root.host.bar.foreground
    font.family: root.host.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
    font.letterSpacing: 1.2
    opacity: 0.65
  }

  BorderSurface {
    id: formatGroup
    width: parent.width
    height: Style.space(36)
    radius: Style.cornerRadius
    color: Style.normalFillFor(root.host.bar.foreground, Color.accent)
    borderSpec: Border.none()

    Row {
      anchors.fill: parent
      anchors.margins: Style.space(3)
      spacing: Style.space(3)
      Repeater {
        model: [
          { value: "song-artist", label: "Title + Artist" },
          { value: "title", label: "Title Only" },
          { value: "none", label: "Hidden" }
        ]
        Button {
          required property var modelData
          width: (formatGroup.width - Style.space(12)) / 3
          height: formatGroup.height - Style.space(6)
          text: modelData.label
          fontFamily: root.host.bar.fontFamily
          fontSize: Style.font.bodySmall
          foreground: root.host.bar.foreground
          bordered: false
          focusable: true
          selected: root.host.labelFormat === modelData.value
          horizontalPadding: Style.space(4)
          onClicked: root.host.setLabelFormat(modelData.value)
        }
      }
    }
  }

  Text {
    text: "VISUALIZER"
    color: root.host.bar.foreground
    font.family: root.host.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
    font.letterSpacing: 1.2
    opacity: 0.65
  }

  Grid {
    width: parent.width
    columns: 2
    columnSpacing: Style.space(8)
    rowSpacing: Style.space(8)

    Repeater {
      model: [
        { value: "peak", label: "Peak Bars" },
        { value: "led", label: "Retro LED" },
        { value: "wave", label: "Mirror" },
        { value: "scope", label: "Scope" },
        { value: "stereo", label: "Stereo" },
        { value: "breathing-dots", label: "Breathing Dots" },
        { value: "outline", label: "Outline" },
        { value: "center-pulse", label: "Center Pulse" }
      ]

      Button {
        id: option
        required property var modelData
        width: (root.width - Style.space(8)) / 2
        height: Style.space(64)
        foreground: root.host.bar.foreground
        selected: root.host.displayMode === modelData.value
        bordered: false
        background: Style.normalFillFor(root.host.bar.foreground, Color.accent)
        focusable: true
        onClicked: root.host.setMode(modelData.value)

        EffectPreview {
          anchors.horizontalCenter: parent.horizontalCenter
          y: Style.space(10)
          width: Style.space(44)
          height: Style.space(20)
          mode: option.modelData.value
          foreground: option.selected ? Color.accent : root.host.bar.foreground
          opacity: option.selected ? 1 : 0.8
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          y: Style.space(39)
          text: option.modelData.label
          color: root.host.bar.foreground
          font.family: root.host.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: option.selected
        }

        Rectangle {
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: Style.space(8)
          width: Style.space(5)
          height: width
          radius: width / 2
          color: Color.accent
          visible: option.selected
        }
      }
    }
  }
}
