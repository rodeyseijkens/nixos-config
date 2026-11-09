import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../"

Text {
  id: root
  Layout.leftMargin: 0
  Layout.rightMargin: 0
  text: " "
  font.bold: true
  font.pixelSize: 20
  font.family: Colors.fontFamily
  color: Colors.base07

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        Quickshell.execDetached(["walker-menu", "wallpapers"]);
      else
        Quickshell.execDetached(["walker"]);
    }
  }
}
