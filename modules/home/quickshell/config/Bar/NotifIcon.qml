import Quickshell
import QtQuick
import QtQuick.Layouts
import "../Services"
import "../"

Text {
  id: root
  required property var barScreen
  Layout.rightMargin: 5
  Layout.leftMargin: 10
  Layout.minimumWidth: 30
  property int count: NotifServer.unreadCount
  property bool dnd: Preferences.dnd
  text: {
    if (dnd && count > 0)
      return "<font color='red'><sup></sup></font> ";
    if (dnd)
      return "";
    if (count > 0)
      return "<font color='red'><sup></sup></font> ";
    return "";
  }
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
        Preferences.toggleDnd();
      else
        PanelRouter.togglePanel(root.barScreen ? root.barScreen.name : "");
    }
  }
}
