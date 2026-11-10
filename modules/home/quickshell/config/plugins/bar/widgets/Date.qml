import Quickshell
import QtQuick
import "../../../"
import "../../../services"

// Date: today's date in the bar. Clicking it opens the calendar panel.
Text {
  id: root
  required property var barScreen

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  text: "<font color='" + Colors.base03 + "'>\uf073</font>"
    + (CalendarEvents.happeningNow ? "<font color='red'><sup></sup></font>" : "")
    + " " + Qt.formatDateTime(clock.date, "dd/MM")
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
    onClicked: PanelRouter.toggleCalendar(root.barScreen ? root.barScreen.name : "")
  }
}
