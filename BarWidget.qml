import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "konochi.konobeat"

  readonly property var mediaService: bar?.shell?.serviceFor(moduleName)
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  property bool popupOpen: false

  readonly property bool playing: activePlayer !== null && activePlayer.isPlaying
  readonly property var modes: ["peak", "led", "wave", "scope", "stereo", "breathing-dots", "outline", "center-pulse"]
  readonly property string displayMode: {
    var mode = String(setting("rhythmStyle", "peak"))
    if (mode === "bass-ring") return "breathing-dots"
    return modes.indexOf(mode) >= 0 ? mode : "peak"
  }
  readonly property var labelFormats: ["song-artist", "title", "none"]
  readonly property string labelFormat: {
    var format = String(setting("labelFormat", "song-artist"))
    return labelFormats.indexOf(format) >= 0 ? format : "song-artist"
  }
  readonly property string displayText: labelFormat === "none" ? ""
    : (title || "Media") + (labelFormat === "song-artist" && artist ? " - " + artist : "")
  readonly property real maxWidth: Style.space(Math.max(120, Number(setting("maxWidth", 220)) || 220))
  readonly property real visualizerWidth: Style.space(Math.max(24, Math.min(80, Number(setting("visualizerWidth", 32)) || 32)))

  readonly property bool opened: popupOpen
  // Override the bar's 55%-of-slot fallback with the unpadded content extent.
  readonly property real openPanelIndicatorWidth: row.implicitWidth
  readonly property real openPanelIndicatorHeight: row.implicitHeight
  function open() { if (hasMedia) popupOpen = true }
  function close() { popupOpen = false }
  function togglePanel() { if (hasMedia) popupOpen = !popupOpen }

  function updateSetting(name, value) {
    var entry = { id: moduleName }
    for (var key in settings) if (key !== "id" && key !== "displayMode") entry[key] = settings[key]
    entry[name] = value
    settings = entry
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, entry)
  }

  function setMode(mode) {
    if (modes.indexOf(mode) >= 0) updateSetting("rhythmStyle", mode)
  }
  function setLabelFormat(format) {
    if (labelFormats.indexOf(format) >= 0) updateSetting("labelFormat", format)
  }

  onHasMediaChanged: if (!hasMedia) close()

  IpcHandler {
    target: "konochi.konobeat"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function setMode(mode: string): void { root.setMode(mode) }
    function setLabelFormat(format: string): void { root.setLabelFormat(format) }
    function status(): string {
      return JSON.stringify({
        mode: root.displayMode,
        labelFormat: root.labelFormat,
        playing: root.playing,
        hasMedia: root.hasMedia,
        popupOpen: root.popupOpen,
        barOpacity: row.opacity,
        label: labelText.text,
        labelVisible: labelText.visible,
        scrolling: labelText.scrolling,
        width: root.implicitWidth,
        indicatorWidth: root.openPanelIndicatorWidth,
        maxWidth: root.maxWidth,
        visualizerWidth: visualizer.width,
        visualizerBands: visualizer.bands,
        visualizerVisible: visualizer.visible,
        pausedIconVisible: pausedPlay.visible,
        sampling: root.mediaService ? root.mediaService.sampling : false,
        sampleAgeMs: root.mediaService && root.mediaService.audioUpdatedAt ? Date.now() - root.mediaService.audioUpdatedAt : -1,
        sampleError: root.mediaService ? root.mediaService.audioError : "No media service",
        rms: root.mediaService ? root.mediaService.audioRms : 0,
        bands: root.mediaService ? root.mediaService.audioBands : [],
        waveformPoints: root.mediaService ? root.mediaService.audioWaveform.length : 0,
        channels: root.mediaService ? root.mediaService.audioChannels : [],
        bass: root.mediaService ? root.mediaService.audioBass : 0,
        panelTitleScrolling: panelTitle.scrolling,
        panelArtistScrolling: panelArtist.scrolling,
        progressAvailable: progress.available,
        duration: progress.duration,
        position: progress.position,
        seekable: progress.seekable,
        transportSizes: [previousButton.width, playButton.width, nextButton.width],
        title: root.title,
        artist: root.artist
      })
    }
  }

  visible: hasMedia
  implicitWidth: hasMedia ? row.implicitWidth + Style.space(10) : 0
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(4)
    opacity: root.playing ? 1.0 : 0.5
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Item {
      id: visualSlot
      anchors.verticalCenter: parent.verticalCenter
      width: root.playing ? (root.vertical ? Style.space(18) : root.visualizerWidth) : Style.space(16)
      height: Style.space(18)

      Visualizer {
        id: visualizer
        anchors.centerIn: parent
        width: parent.width
        height: Style.space(root.displayMode === "breathing-dots" ? 12 : 18)
        visible: root.playing
        mode: root.displayMode
        foreground: root.bar.barForeground
        playing: root.playing
        active: root.hasMedia && root.playing
        spectrum: root.mediaService ? root.mediaService.audioBands : []
        waveform: root.mediaService ? root.mediaService.audioWaveform : []
        channels: root.mediaService ? root.mediaService.audioChannels : []
        channelPeaks: root.mediaService ? root.mediaService.audioChannelPeaks : []
        bass: root.mediaService ? root.mediaService.audioBass : 0
        rawBassAmplitude: root.mediaService ? root.mediaService.audioBassAmplitude : 0
      }

      Canvas {
        id: pausedPlay
        anchors.centerIn: parent
        width: Style.space(16)
        height: width
        visible: !root.playing
        property color foreground: root.bar.barForeground
        onVisibleChanged: if (visible) requestPaint()
        onForegroundChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.clearRect(0, 0, width, height)
          ctx.scale(width / 16, height / 16)
          ctx.fillStyle = foreground
          ctx.beginPath()
          ctx.moveTo(4.5, 4)
          ctx.quadraticCurveTo(4.5, 2.5, 5.9, 3.3)
          ctx.lineTo(12.4, 7)
          ctx.quadraticCurveTo(14, 8, 12.4, 9)
          ctx.lineTo(5.9, 12.7)
          ctx.quadraticCurveTo(4.5, 13.5, 4.5, 12)
          ctx.closePath()
          ctx.fill()
        }
      }
    }

    Marquee {
      id: labelText
      visible: !root.vertical && root.labelFormat !== "none"
      text: root.displayText
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, Math.max(0, root.maxWidth - Style.space(10)
        - visualSlot.width - row.spacing))
      active: root.hasMedia && !root.vertical && root.labelFormat !== "none"
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("next", false)
      } else {
        root.togglePanel()
      }
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false)
      else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false)
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    triggerMode: "click"
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Controls.ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
      Controls.ScrollBar.vertical.policy: column.implicitHeight > height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
      Binding {
        target: scrollArea.contentItem
        property: "interactive"
        value: column.implicitHeight > scrollArea.height
      }

    Column {
      id: column
      width: scrollArea.availableWidth
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Marquee {
            id: panelTitle
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            width: parent.width
            active: root.popupOpen
          }

          Marquee {
            id: panelArtist
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            width: parent.width
            visible: text !== ""
            active: root.popupOpen && visible
          }

          Text {
            textFormat: Text.PlainText
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      MediaProgress {
        id: progress
        width: parent.width
        player: root.activePlayer
        bar: root.bar
        active: root.popupOpen
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)

        TransportButton {
          id: previousButton
          action: "previous"
          foreground: root.bar.foreground
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
        }

        TransportButton {
          id: playButton
          playing: root.playing
          foreground: root.bar.foreground
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
        }

        TransportButton {
          id: nextButton
          action: "next"
          foreground: root.bar.foreground
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      MediaSettings {
        width: parent.width
        host: root
      }

      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Commons.Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceTitle
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceDetail
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
    }
  }
}
