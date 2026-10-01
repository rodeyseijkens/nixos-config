import Quickshell
import QtQuick
import QtQuick.Layouts
import "../"
import "../Services"

RowLayout {
  id: root
  required property var barScreen
  spacing: 0

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Text {
    id: clockText
    text: "<font color='" + Colors.base03 + "'>\uf017</font> " + Qt.formatDateTime(clock.date, "dd/MM") + " <font color='" + Colors.base03 + "'>\uf073</font> " + Qt.formatDateTime(clock.date, "HH:mm")
    textFormat: Text.RichText
    font.bold: true
    font.family: Colors.fontFamily
    color: Colors.base05

    MouseArea {
      id: clockMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: root.opacity = 0.6
      onExited: root.opacity = 1.0
      onClicked: PanelRouter.toggleCalendar(root.barScreen ? root.barScreen.name : "")
    }
  }
}
