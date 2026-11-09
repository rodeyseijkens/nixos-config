import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"

Text {
  id: root
  required property var barScreen
  Layout.rightMargin: 10
  text: "<font color='" + Colors.base0B + "'>" + Audio.icon + "</font> " + Audio.percent + "%"
  textFormat: Text.RichText
  font.bold: true
  font.family: Colors.fontFamily
  color: Colors.base05

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        Audio.toggleMute();
      else
        OverlayPanels.toggle("audio", root.barScreen ? root.barScreen.name : "");
    }
    onWheel: wheel => {
      if (wheel.angleDelta.y > 0)
        Audio.step(2);
      else if (wheel.angleDelta.y < 0)
        Audio.step(-2);
    }
  }
}
