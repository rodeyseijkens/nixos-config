import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"

RowLayout {
  id: root
  required property var barScreen
  spacing: 16

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Text {
    id: dateText
    text: "<font color='" + Colors.base03 + "'>\uf073</font> " + Qt.formatDateTime(clock.date, "dd/MM")
    textFormat: Text.RichText
    font.bold: true
    font.family: Colors.fontFamily
    font.pixelSize: 16
    color: Colors.base05

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: dateText.opacity = 0.6
      onExited: dateText.opacity = 1.0
      onClicked: PanelRouter.toggleCalendar(root.barScreen ? root.barScreen.name : "")
    }
  }

  Text {
    id: timeText
    text: "<font color='" + Colors.base03 + "'>\uf017</font> " + Qt.formatDateTime(clock.date, "HH:mm")
    textFormat: Text.RichText
    font.bold: true
    font.family: Colors.fontFamily
    font.pixelSize: 16
    color: Colors.base05

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: timeText.opacity = 0.6
      onExited: timeText.opacity = 1.0
      onClicked: OverlayPanels.toggle("elsewhen", root.barScreen ? root.barScreen.name : "")
    }
  }
}
