pragma ComponentBehavior: Bound
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"

Item {
  id: root
  required property var barScreen

  readonly property string screenName: root.barScreen ? (root.barScreen.name ?? "") : ""
  readonly property var players: Mpris.players && Mpris.players.values ? Mpris.players.values : []
  readonly property var playStates: {
    var list = root.players;
    var states = [];
    for (var i = 0; i < list.length; i++)
      states.push(list[i] ? list[i].isPlaying : false);
    return states;
  }
  readonly property var player: {
    var list = root.players;
    if (list.length === 0)
      return null;
    if (root._pinned) {
      for (var p = 0; p < list.length; p++)
        if (list[p] === root._pinned)
          return root._pinned;
    }
    for (var i = 0; i < list.length; i++)
      if (root.playStates[i] && list[i])
        return list[i];
    return list[0];
  }
  readonly property bool playing: root.player ? root.player.isPlaying : false
  readonly property string title: root.player ? (root.player.trackTitle || "") : ""
  readonly property string artist: root.player ? (root.player.trackArtist || "") : ""
  readonly property string album: root.player ? (root.player.trackAlbum || "") : ""
  readonly property string identity: root.player ? (root.player.identity || "") : ""
  readonly property string displayTitle: root.title !== "" ? root.title
    : root.artist !== "" ? root.artist
    : root.album !== "" ? root.album
    : root.identity
  readonly property string barTitle: root.title !== ""
    ? (root.artist !== "" ? root.artist + " — " + root.title : root.title)
    : root.displayTitle.replace(/\s+/g, " ")
  readonly property bool hasMetadata: root.title !== "" || root.artist !== "" || root.album !== ""
  readonly property bool active: root.player !== null && root.hasMetadata
  readonly property color activeTint: "#FE8019"
  readonly property color hoverTint: "#D79921"
  readonly property color tint: mediaMouse.containsMouse
    ? hoverTint
    : (root._open ? activeTint : Colors.base05)

  property var _pinned: null
  property bool _open: false

  Layout.leftMargin: 8
  Layout.rightMargin: 10
  Layout.maximumWidth: 180
  implicitWidth: Math.min(barText.implicitWidth, 180)
  implicitHeight: barText.implicitHeight
  visible: root.active

  Text {
    id: barText
    anchors.fill: parent
    text: root.active ? "♪ " + root.barTitle : ""
    textFormat: Text.PlainText
    elide: Text.ElideRight
    maximumLineCount: 1
    verticalAlignment: Text.AlignVCenter
    font.bold: true
    font.family: Colors.fontFamily
    color: root.tint
  }

  function selectPlayer(p) {
    root._pinned = p;
  }

  function flashOsd(icon, label) {
    var detail = root.barTitle !== "" ? label + " · " + root.barTitle : label;
    OsdBus.show({
      kind: "media",
      icon: icon,
      message: detail,
      duration: 1200
    });
  }

  function togglePlayback() {
    if (!root.player || !root.player.canTogglePlaying)
      return;
    var wasPlaying = root.player.isPlaying;
    root.player.togglePlaying();
    root.flashOsd(wasPlaying ? "⏸" : "▶", wasPlaying ? "Paused" : "Playing");
  }

  function previousTrack() {
    if (!root.player || !root.player.canGoPrevious)
      return;
    root.player.previous();
    root.flashOsd("⏮", "Previous");
  }

  function nextTrack() {
    if (!root.player || !root.player.canGoNext)
      return;
    root.player.next();
    root.flashOsd("⏭", "Next");
  }

  function openPopup() {
    if (!root.active)
      return;
    if (root._open) {
      root._open = false;
      return;
    }
    if (OverlayPanels.active !== "")
      OverlayPanels.close();
    root._open = true;
  }

  onActiveChanged: if (!root.active) root._open = false

  Connections {
    target: OverlayPanels
    function onActiveChanged(): void {
      if (OverlayPanels.active !== "")
        root._open = false;
    }
  }

  MouseArea {
    id: mediaMouse
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.openPopup()
  }

  ScreenPopup {
    placement: PopupPlacement {
      bottom: true
      marginBottom: 40
      width: 320
    }
    showWhen: name => root._open && root.active && name === root.screenName
    focusable: true
    focusGrab: true
    onDismissRequested: root._open = false

    content: Component {
      Rectangle {
        id: card
        implicitWidth: 320
        implicitHeight: body.implicitHeight + 28
        color: Colors.base01
        border.color: Colors.base04
        border.width: 1
        radius: 8

        Column {
          id: body
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          Row {
            width: parent.width
            height: 76
            spacing: 12

            Rectangle {
              width: 76
              height: 76
              radius: 4
              color: Colors.base00

              Image {
                id: albumArt
                anchors.fill: parent
                source: root.player ? (root.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: source !== "" && status === Image.Ready
              }

              Text {
                anchors.centerIn: parent
                visible: !albumArt.visible
                text: "♪"
                font.pixelSize: 28
                font.family: Colors.fontFamily
                color: Colors.base04
              }
            }

            Column {
              width: parent.width - 76 - 12
              anchors.verticalCenter: parent.verticalCenter
              spacing: 3

              Text {
                width: parent.width
                text: root.displayTitle
                elide: Text.ElideRight
                maximumLineCount: 1
                font.bold: true
                font.pixelSize: 14
                font.family: Colors.fontFamily
                color: Colors.base06
              }

              Text {
                width: parent.width
                visible: root.artist !== ""
                text: root.artist
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: 12
                font.family: Colors.fontFamily
                color: Colors.base05
              }

              Text {
                width: parent.width
                visible: root.album !== ""
                text: root.album
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: 11
                font.family: Colors.fontFamily
                color: Colors.base04
              }
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            Rectangle {
              width: 34
              height: 30
              radius: 4
              color: prevMouse.containsMouse && root.player && root.player.canGoPrevious ? Colors.base02 : "transparent"
              opacity: root.player && root.player.canGoPrevious ? 1 : 0.35

              Text {
                anchors.centerIn: parent
                text: "⏮"
                font.pixelSize: 18
                font.family: Colors.fontFamily
                color: Colors.base05
              }

              MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.previousTrack()
              }
            }

            Rectangle {
              width: 42
              height: 34
              radius: 4
              color: playMouse.containsMouse && root.player && root.player.canTogglePlaying ? Colors.base02 : Colors.base00
              opacity: root.player && root.player.canTogglePlaying ? 1 : 0.35

              Text {
                anchors.centerIn: parent
                text: root.playing ? "⏸" : "▶"
                font.pixelSize: 20
                font.family: Colors.fontFamily
                color: Colors.base06
              }

              MouseArea {
                id: playMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePlayback()
              }
            }

            Rectangle {
              width: 34
              height: 30
              radius: 4
              color: nextMouse.containsMouse && root.player && root.player.canGoNext ? Colors.base02 : "transparent"
              opacity: root.player && root.player.canGoNext ? 1 : 0.35

              Text {
                anchors.centerIn: parent
                text: "⏭"
                font.pixelSize: 18
                font.family: Colors.fontFamily
                color: Colors.base05
              }

              MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.nextTrack()
              }
            }
          }

          Column {
            width: parent.width
            spacing: 5
            visible: root.players.length > 1

            Text {
              text: "Source"
              font.pixelSize: 11
              font.family: Colors.fontFamily
              color: Colors.base04
            }

            Flow {
              width: parent.width
              spacing: 6

              Repeater {
                model: root.players

                Rectangle {
                  id: sourceChip
                  required property var modelData
                  property var sourcePlayer: modelData
                  readonly property string sourceName: sourcePlayer
                    ? (sourcePlayer.identity || sourcePlayer.desktopEntry || "Player") : ""
                  width: sourceLabel.implicitWidth + 16
                  height: 24
                  radius: 4
                  color: root.player === sourceChip.sourcePlayer ? Colors.base0B
                    : sourceMouse.containsMouse ? Colors.base02 : Colors.base00
                  border.width: 1
                  border.color: root.player === sourceChip.sourcePlayer ? Colors.base0B : Colors.base03

                  Text {
                    id: sourceLabel
                    anchors.centerIn: parent
                    text: sourceChip.sourceName
                    font.pixelSize: 11
                    font.family: Colors.fontFamily
                    color: root.player === sourceChip.sourcePlayer ? Colors.base00 : Colors.base05
                  }

                  MouseArea {
                    id: sourceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.selectPlayer(sourceChip.sourcePlayer);
                      root.flashOsd("♪", sourceChip.sourceName);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
