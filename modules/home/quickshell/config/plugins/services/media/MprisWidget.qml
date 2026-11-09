import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../../../"

// swaync parity: .widget-mpris-player — base01 card, 1px base01 border,
// 50px album art, bold 14px title / regular 14px subtitle, play toggle.
ColumnLayout {
  id: root
  Layout.fillWidth: true
  Layout.leftMargin: 5
  Layout.rightMargin: 5
  spacing: 0
  visible: Mpris.players.values.length > 0

  Repeater {
    model: Mpris.players

    Rectangle {
      required property var modelData
      property var player: modelData
      Layout.fillWidth: true
      Layout.preferredHeight: 82
      Layout.topMargin: 10
      Layout.bottomMargin: 10
      Layout.leftMargin: 10
      Layout.rightMargin: 10
      color: Colors.base01
      border.color: Colors.base01
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Image {
          Layout.preferredWidth: 50
          Layout.preferredHeight: 50
          fillMode: Image.PreserveAspectCrop
          source: player.trackArtUrl
          visible: player.trackArtUrl !== ""
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            Layout.fillWidth: true
            text: player.trackTitle !== "" ? player.trackTitle : player.identity
            font.bold: true
            font.pixelSize: 14
            font.family: Colors.fontFamily
            color: Colors.base04
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            text: player.trackArtist !== "" ? player.trackArtist : player.trackAlbum
            font.pixelSize: 14
            font.family: Colors.fontFamily
            color: Colors.base04
            elide: Text.ElideRight
          }
        }

        Rectangle {
          id: playBtn
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          Layout.alignment: Qt.AlignVCenter
          color: playMouse.containsMouse ? Colors.base00 : "transparent"
          Text {
            anchors.centerIn: parent
            text: player.isPlaying ? "⏸" : "▶"
            font.pixelSize: 20
            font.family: Colors.fontFamily
            color: Colors.base04
          }
          MouseArea {
            id: playMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: player.togglePlaying()
          }
        }
      }
    }
  }
}
