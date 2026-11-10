import Quickshell
import QtQuick
import "../../../"
import "../../../services"

// Clock: the bar's time of day. Clicking it opens the world clock panel.
Text {
  id: root
  required property var barScreen

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

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
    onEntered: root.opacity = 0.6
    onExited: root.opacity = 1.0
    onClicked: OverlayPanels.toggle("elsewhen", root.barScreen ? root.barScreen.name : "")
  }
}
