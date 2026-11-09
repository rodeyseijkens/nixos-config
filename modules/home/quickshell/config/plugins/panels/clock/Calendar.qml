import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"

// Calendar: the ScreenPopup attached to the Bar's clock, showing a month grid.
Scope {
  id: calendar

  property date now: new Date()

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: calendar.now = new Date()
  }

  ScreenPopup {
    placement: PopupPlacement {
      bottom: true
      // bar (28) + gap (12): keep clear of the bar the clock lives on
      marginBottom: 40
      width: 340
    }
    // only the bar whose clock was clicked (screen names are unique)
    showWhen: (name) => PanelRouter.calendarOpen && PanelRouter.calendarScreenName === name
    focusable: true
    focusGrab: true
    onDismissRequested: PanelRouter.closeCalendar()

    content: Component {
      Rectangle {
        id: calBg
        anchors.fill: parent
        implicitHeight: calCol.implicitHeight + 24
        color: Colors.base00
        border.color: Colors.base04
        border.width: 2

        property int shownYear: calendar.now.getFullYear()
        property int shownMonth: calendar.now.getMonth()

        // reset to the current month on each open
        Connections {
          target: PanelRouter
          function onCalendarOpenChanged(): void {
            if (PanelRouter.calendarOpen) {
              calBg.shownYear = calendar.now.getFullYear();
              calBg.shownMonth = calendar.now.getMonth();
            }
          }
        }

        ColumnLayout {
          id: calCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          GridLayout {
            columns: 7
            rowSpacing: 2
            columnSpacing: 2
            Layout.fillWidth: true

            Repeater {
              model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
              Text {
                required property string modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.bold: true
                font.pixelSize: 12
                font.family: Colors.fontFamily
                color: Colors.base03
              }
            }

            Repeater {
              model: Lib.calendarCells(calBg.shownYear, calBg.shownMonth)
              Text {
                required property int modelData
                property bool isToday: modelData !== 0 && modelData === calendar.now.getDate() && calBg.shownMonth === calendar.now.getMonth() && calBg.shownYear === calendar.now.getFullYear()
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData === 0 ? "" : "" + modelData
                font.bold: isToday
                font.pixelSize: 14
                font.family: Colors.fontFamily
                color: isToday ? Colors.base0D : Colors.base04
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
              text: "‹"
              font.pixelSize: 18
              font.bold: true
              font.family: Colors.fontFamily
              color: Colors.base04
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: parent.opacity = 0.6
                onExited: parent.opacity = 1.0
                onClicked: {
                  if (calBg.shownMonth === 0) {
                    calBg.shownMonth = 11;
                    calBg.shownYear -= 1;
                  } else {
                    calBg.shownMonth -= 1;
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: Qt.locale().monthName(calBg.shownMonth, Locale.LongFormat) + " " + calBg.shownYear
              font.bold: true
              font.pixelSize: 16
              font.family: Colors.fontFamily
              color: Colors.base04
            }

            Text {
              text: "›"
              font.pixelSize: 18
              font.bold: true
              font.family: Colors.fontFamily
              color: Colors.base04
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: parent.opacity = 0.6
                onExited: parent.opacity = 1.0
                onClicked: {
                  if (calBg.shownMonth === 11) {
                    calBg.shownMonth = 0;
                    calBg.shownYear += 1;
                  } else {
                    calBg.shownMonth += 1;
                  }
                }
              }
            }

            Text {
              text: "today"
              font.pixelSize: 12
              font.family: Colors.fontFamily
              color: Colors.base0B
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: parent.opacity = 0.6
                onExited: parent.opacity = 1.0
                onClicked: {
                  calBg.shownYear = calendar.now.getFullYear();
                  calBg.shownMonth = calendar.now.getMonth();
                }
              }
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: "calendar"

    // no-arg form used by keybinds; targets the current/first screen
    function toggle(): void {
      PanelRouter.toggleCalendar();
    }
    // screen-targeted form (used by tests / explicit callers)
    function toggleOn(screen: string): void {
      PanelRouter.toggleCalendar(screen);
    }
  }
}
