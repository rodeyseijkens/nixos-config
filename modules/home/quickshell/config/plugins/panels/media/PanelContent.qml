pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Media panel: now playing, transport controls, and per-source audio output.
// Adapted from MEPPERDONAS/media-plus (MIT).
Item {
  id: root

  // ---- host contract -----------------------------------------------------
  property var bar: null
  property var settings: ({})
  property string moduleName: "media"

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- players -----------------------------------------------------------
  readonly property var players: {
    var list = Mpris.players && Mpris.players.values ? Mpris.players.values : []
    var real = []
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p) continue
      if (String(p.dbusName || "").toLowerCase().indexOf("playerctld") !== -1) continue
      real.push(p)
    }
    return real
  }

  property var pinnedPlayer: null

  readonly property var player: {
    var list = root.players
    if (list.length === 0) return null
    if (root.pinnedPlayer) {
      for (var p = 0; p < list.length; p++)
        if (list[p] === root.pinnedPlayer) return root.pinnedPlayer
    }
    for (var i = 0; i < list.length; i++)
      if (list[i].isPlaying && hasMetadata(list[i])) return list[i]
    for (var j = 0; j < list.length; j++)
      if (hasMetadata(list[j])) return list[j]
    return list[0]
  }

  readonly property bool playing: root.player ? root.player.isPlaying : false
  readonly property string title: root.player ? cleanText(root.player.trackTitle) : ""
  readonly property string artist: root.player ? cleanText(root.player.trackArtist) : ""
  readonly property string album: root.player ? cleanText(root.player.trackAlbum) : ""
  readonly property string artUrl: root.player ? String(root.player.trackArtUrl || "") : ""
  readonly property bool hasMedia: root.player !== null
    && (root.title !== "" || root.artist !== "" || root.album !== "")
  readonly property real progressRatio: {
    if (!root.player || !(root.player.length > 0)) return 0
    return Math.max(0, Math.min(1, root.player.position / root.player.length))
  }

  readonly property string sourceLabel: root.player
    ? (root.player.identity || root.player.desktopEntry || "Player") : ""

  function hasMetadata(p) {
    return !!(p && (p.trackTitle || p.trackArtist || p.trackAlbum || p.identity || p.desktopEntry))
  }

  function cleanText(value) {
    var text = String(value || "").trim()
    text = text.replace(/^file:\/\//, "")
    text = text.split("/").pop()
    return text.replace(/\.(mp3|flac|ogg|opus|wav|m4a|aac|webm)$/i, "")
  }

  function playerKey(p) {
    return p ? String(p.dbusName || p.identity || p.desktopEntry || "") : ""
  }

  function formatTime(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0))
    var minutes = Math.floor(total / 60)
    var rest = total % 60
    return minutes + ":" + (rest < 10 ? "0" : "") + rest
  }

  function runAction(action) {
    if (!root.player) return
    if (action === "playPause" && root.player.canTogglePlaying) root.player.togglePlaying()
    else if (action === "previous" && root.player.canGoPrevious) root.player.previous()
    else if (action === "next" && root.player.canGoNext) root.player.next()
    else if (action === "shuffle" && root.player.shuffleSupported) root.player.shuffle = !root.player.shuffle
    else if (action === "loop" && root.player.loopSupported)
      root.player.loopState = (Number(root.player.loopState) + 1) % 3
  }

  function selectPlayer(p) {
    root.pinnedPlayer = p
    root.openMenu = ""
  }

  // ---- audio sinks and per-source routing --------------------------------
  readonly property var nodes: Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : []
  readonly property var sinks: {
    var list = []
    for (var i = 0; i < root.nodes.length; i++) {
      var n = root.nodes[i]
      if (!n || !n.isSink || n.isStream || !n.audio) continue
      list.push(n)
    }
    return list
  }

  function sinkLabel(node) {
    return node ? String(node.description || node.nickname || node.name || "") : ""
  }

  // pactl --format=json: sink-inputs carry the app name and their sink index;
  // sinks map that index to the PipeWire node name used in move-sink-input.
  property var sinkInputs: []
  property var sinkNames: ({})
  property string openMenu: ""

  function readSinkInputs(raw) {
    try {
      var rows = JSON.parse(String(raw || "[]"))
      var list = []
      for (var i = 0; i < rows.length; i++) {
        var row = rows[i] || {}
        var props = row.properties || {}
        list.push({
          index: Number(row.index),
          sink: Number(row.sink),
          app: String(props["application.name"] || "").toLowerCase(),
          binary: String(props["application.process.binary"] || "").toLowerCase(),
          media: String(props["media.name"] || "").toLowerCase()
        })
      }
      root.sinkInputs = list
    } catch (e) {
      root.sinkInputs = []
    }
  }

  function readSinkNames(raw) {
    try {
      var rows = JSON.parse(String(raw || "[]"))
      var map = {}
      for (var i = 0; i < rows.length; i++)
        map[Number(rows[i].index)] = String(rows[i].name || "")
      root.sinkNames = map
    } catch (e) {
      root.sinkNames = ({})
    }
  }

  function refreshRouting() {
    sinksProc.running = true
    sinkInputsProc.running = true
  }

  function inputFor(p) {
    if (!p) return null
    var keys = []
    var identity = String(p.identity || "").toLowerCase()
    var desktop = String(p.desktopEntry || "").toLowerCase()
    if (identity) keys.push(identity)
    if (desktop && desktop !== identity) keys.push(desktop)
    for (var i = 0; i < root.sinkInputs.length; i++) {
      var row = root.sinkInputs[i]
      for (var k = 0; k < keys.length; k++) {
        var key = keys[k]
        if (!key) continue
        if (row.app === key || row.binary === key
            || row.app.indexOf(key) !== -1 || row.binary.indexOf(key) !== -1)
          return row
      }
    }
    return null
  }

  function currentSinkName(p) {
    var row = inputFor(p)
    return row ? String(root.sinkNames[row.sink] || "") : ""
  }

  function currentSinkLabel(p) {
    var name = currentSinkName(p)
    for (var i = 0; i < root.sinks.length; i++)
      if (String(root.sinks[i].name || "") === name) return root.sinkLabel(root.sinks[i])
    return name
  }

  function moveToSink(p, sinkName) {
    var row = inputFor(p)
    if (!row || !sinkName) return
    moveProc.command = ["pactl", "move-sink-input", String(row.index), sinkName]
    moveProc.running = true
    root.openMenu = ""
  }

  function canRoute(p) {
    return root.sinks.length > 1 && inputFor(p) !== null
  }

  function focusSource() {
    var p = root.player
    var app = p ? String(p.desktopEntry || p.identity || "") : ""
    if (!app) return
    Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:^(?i)" + app + "$"])
  }

  implicitWidth: Style.space(400)
  implicitHeight: body.implicitHeight + Style.space(28)

  PwObjectTracker { objects: root.sinks }

  Process {
    id: sinksProc
    command: ["pactl", "--format=json", "list", "sinks"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.readSinkNames(text)
    }
  }

  Process {
    id: sinkInputsProc
    command: ["pactl", "--format=json", "list", "sink-inputs"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.readSinkInputs(text)
    }
  }

  Process {
    id: moveProc
    onRunningChanged: if (!running) routingTimer.restart()
  }

  Timer {
    id: routingTimer
    interval: 400
    repeat: false
    onTriggered: root.refreshRouting()
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshRouting()
  }

  // Playback position is not pushed over D-Bus; sample it while playing.
  Timer {
    interval: 1000
    repeat: true
    running: root.playing
    onTriggered: if (root.player) root.player.positionChanged()
  }

  BorderSurface {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(1)))
  }

  Column {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.spacing.popupPadding
    spacing: Style.spacing.panelGap

    // ---- album art hero --------------------------------------------------
    Item {
      id: hero
      width: parent.width
      height: Math.round(width * 0.5)

      Item {
        id: artSource
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
          anchors.fill: parent
          color: Commons.Color.background
        }

        Image {
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          source: root.artUrl
          visible: root.artUrl !== ""
        }

        Text {
          anchors.centerIn: parent
          visible: root.artUrl === ""
          text: "\u266a"
          font.family: root.fontFamily
          font.pixelSize: Style.font.displayLarge
          color: root.foreground
          opacity: 0.25
        }

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.62) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
          }
        }
      }

      Item {
        id: artMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: "white"
        }
      }

      MultiEffect {
        anchors.fill: parent
        source: artSource
        maskEnabled: true
        maskSource: artMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }

      Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Style.space(10)
        anchors.topMargin: Style.space(10)
        anchors.rightMargin: sourceBadge.width + Style.space(20)
        spacing: Style.space(4)

        Text {
          width: parent.width
          text: root.title !== "" ? root.title : root.sourceLabel
          color: "white"
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: root.artist
          color: "#cccccc"
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: root.album
          color: "#cccccc"
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }

      // Source badge: shows which app is playing and focuses its window.
      Rectangle {
        id: sourceBadge
        property bool hovered: false
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Style.space(8)
        width: badgeRow.implicitWidth + Style.space(14)
        height: Style.space(24)
        radius: Style.space(12)
        color: sourceBadge.hovered ? Qt.rgba(0, 0, 0, 0.62) : Qt.rgba(0, 0, 0, 0.38)
        visible: root.hasMedia

        Row {
          id: badgeRow
          anchors.centerIn: parent
          spacing: Style.space(5)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.sourceLabel
            color: "white"
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
            width: Math.min(implicitWidth, Style.space(110))
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onContainsMouseChanged: sourceBadge.hovered = containsMouse
          onClicked: root.focusSource()
        }
      }

      // ---- transport ----------------------------------------------------
      Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(8)
        spacing: Style.space(4)

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(2)

          Button {
            iconText: "󰒝"
            height: Style.space(30)
            foreground: "white"
            active: root.player && root.player.shuffle === true
            enabled: root.player && root.player.shuffleSupported === true
            opacity: enabled ? (active ? 1.0 : 0.6) : 0.35
            onClicked: root.runAction("shuffle")
          }

          Button {
            iconText: "󰒮"
            height: Style.space(30)
            foreground: "white"
            enabled: root.player && root.player.canGoPrevious === true
            opacity: enabled ? 1.0 : 0.35
            onClicked: root.runAction("previous")
          }

          Button {
            iconText: root.playing ? "" : ""
            height: Style.space(34)
            foreground: "white"
            fontSize: Style.font.iconLarge
            enabled: root.player && root.player.canTogglePlaying === true
            opacity: enabled ? 1.0 : 0.35
            onClicked: root.runAction("playPause")
          }

          Button {
            iconText: "󰒭"
            height: Style.space(30)
            foreground: "white"
            enabled: root.player && root.player.canGoNext === true
            opacity: enabled ? 1.0 : 0.35
            onClicked: root.runAction("next")
          }

          Button {
            iconText: root.player && Number(root.player.loopState) > 0 ? "󰑘" : "󰑖"
            height: Style.space(30)
            foreground: "white"
            active: root.player && Number(root.player.loopState) > 0
            enabled: root.player && root.player.loopSupported === true
            opacity: enabled ? (active ? 1.0 : 0.6) : 0.35
            onClicked: root.runAction("loop")
          }
        }

        // ---- progress -----------------------------------------------------
        Column {
          width: parent.width
          visible: root.player && root.player.length > 0
          spacing: Style.space(2)

          Rectangle {
            width: parent.width
            height: Style.space(4)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.25)

            Rectangle {
              width: parent.width * root.progressRatio
              height: parent.height
              radius: parent.radius
              color: "white"
            }

            MouseArea {
              anchors.fill: parent
              enabled: root.player && root.player.positionSupported === true
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                if (!root.player || !(root.player.length > 0)) return
                root.player.position = Math.max(0, Math.min(1, mouse.x / width)) * root.player.length
              }
            }
          }

          Row {
            width: parent.width

            Text {
              id: elapsedText
              text: root.formatTime(root.player ? root.player.position : 0)
              color: "#cccccc"
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Item { width: Math.max(0, parent.width - elapsedText.implicitWidth - totalText.implicitWidth); height: 1 }

            Text {
              id: totalText
              text: root.formatTime(root.player ? root.player.length : 0)
              color: "#cccccc"
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }

    // ---- sources ---------------------------------------------------------
    PanelSeparator {
      visible: root.players.length > 1
      foreground: root.foreground
    }

    Column {
      width: parent.width
      visible: root.players.length > 1
      spacing: Style.space(4)

      Repeater {
        model: root.players

        Column {
          id: sourceRow
          required property var modelData
          readonly property var sourcePlayer: modelData
          readonly property bool selected: root.player === sourceRow.sourcePlayer
          readonly property bool sourcePlaying: sourceRow.sourcePlayer ? sourceRow.sourcePlayer.isPlaying : false

          width: parent.width
          spacing: Style.space(2)

          Rectangle {
            width: parent.width
            height: sourceInner.implicitHeight + Style.space(8)
            radius: Style.spacing.labelGap
            color: sourceRow.selected ? Style.selectedFillFor(root.foreground, Commons.Color.accent, Commons.Color.urgent) : "transparent"

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectPlayer(sourceRow.sourcePlayer)
            }

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(8)

              Text {
                text: sourceRow.sourcePlaying ? "" : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(16)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!sourceRow.sourcePlayer) return
                    root.selectPlayer(sourceRow.sourcePlayer)
                    if (sourceRow.sourcePlayer.canTogglePlaying) sourceRow.sourcePlayer.togglePlaying()
                  }
                }
              }

              Column {
                width: parent.width - Style.space(24) - (sinkButton.visible ? sinkButton.width + Style.space(8) : 0)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  text: root.cleanText(sourceRow.sourcePlayer ? sourceRow.sourcePlayer.trackTitle : "")
                    || (sourceRow.sourcePlayer ? String(sourceRow.sourcePlayer.identity || "") : "")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: text !== ""
                  text: root.cleanText(sourceRow.sourcePlayer ? sourceRow.sourcePlayer.trackArtist : "")
                  color: Qt.darker(root.foreground, 1.5)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              BorderSurface {
                id: sinkButton
                visible: root.canRoute(sourceRow.sourcePlayer)
                width: Style.space(112)
                height: Style.space(24)
                radius: Style.cornerRadius
                anchors.verticalCenter: parent.verticalCenter
                color: Style.controlFill(false, sinkHover.hovered, root.foreground, Commons.Color.accent)
                borderSpec: Border.controlSpec(sinkHover.hovered ? "hover-cursor" : "normal", root.foreground, Commons.Color.accent)

                Text {
                  anchors.left: parent.left
                  anchors.right: chevron.left
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(6)
                  anchors.rightMargin: Style.space(4)
                  text: root.currentSinkLabel(sourceRow.sourcePlayer) || "—"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                Text {
                  id: chevron
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.rightMargin: Style.space(5)
                  text: root.openMenu === root.playerKey(sourceRow.sourcePlayer) ? "\uf014" : "\uf078"
                  color: Qt.darker(root.foreground, 1.2)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                HoverHandler { id: sinkHover }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var key = root.playerKey(sourceRow.sourcePlayer)
                    root.openMenu = root.openMenu === key ? "" : key
                  }
                }
              }
            }
          }

          Column {
            width: parent.width - Style.space(24)
            anchors.left: parent.left
            anchors.leftMargin: Style.space(24)
            visible: root.openMenu === root.playerKey(sourceRow.sourcePlayer)
            spacing: Style.space(2)

            Repeater {
              model: root.sinks

              Rectangle {
                id: sinkOption
                required property var modelData
                readonly property bool isCurrent: String(modelData.name || "") === root.currentSinkName(sourceRow.sourcePlayer)

                width: parent.width
                height: Style.space(24)
                radius: Style.spacing.labelGap
                color: sinkOptionHover.hovered ? Style.hoverFillFor(root.foreground, Commons.Color.accent, Commons.Color.urgent) : "transparent"

                Text {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  text: root.sinkLabel(sinkOption.modelData)
                  color: sinkOption.isCurrent ? Commons.Color.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: sinkOption.isCurrent
                  elide: Text.ElideRight
                }

                HoverHandler { id: sinkOptionHover }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.moveToSink(sourceRow.sourcePlayer, String(sinkOption.modelData.name || ""))
                }
              }
            }
          }
        }
      }
    }

    Text {
      width: parent.width
      visible: !root.hasMedia
      horizontalAlignment: Text.AlignHCenter
      text: "No media playing"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  Component.onCompleted: root.refreshRouting()
}
