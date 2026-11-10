import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"
// CalendarHost: the ScreenPopup opened by the bar clock. It hosts the
// calendar panel on the monitor whose clock was clicked.
Scope {
  id: calendar

  property date now: new Date()
  property int panelWidth: 800

  readonly property var panelBar: BarApi {}
  property var panelSettings: ({})

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
      width: Math.max(320, calendar.panelWidth)
    }
    // only the bar whose clock was clicked (screen names are unique)
    showWhen: (name) => PanelRouter.calendarOpen && PanelRouter.calendarScreenName === name
    focusable: true
    focusGrab: true
    onDismissRequested: PanelRouter.closeCalendar()

    content: Component {
      CalendarPanel {
        id: panel
        bar: calendar.panelBar
        settings: calendar.panelSettings

        function adoptWidth() {
          if (implicitWidth > 200)
            calendar.panelWidth = Math.round(implicitWidth)
        }

        onImplicitWidthChanged: adoptWidth()
        Component.onCompleted: adoptWidth()

        Connections {
          target: PanelRouter
          function onCalendarOpenChanged(): void {
            if (PanelRouter.calendarOpen)
              panel.open()
            else
              panel.close()
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
