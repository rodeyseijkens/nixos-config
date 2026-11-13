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
      // The bar reserves its own 28px, so this is the 16px gap above it that
      // matches the popup's side padding.
      marginBottom: 16
      width: Math.max(320, calendar.panelWidth)
    }
    anchorX: PanelRouter.calendarAnchorX
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

        function adoptSettingsFromStore() {
          if (!PanelSettings.loaded) return
          var values = PanelSettings.ensure("shell-calendar", panel.defaultSettings)
          calendar.panelSettings = values
          panel.settings = values
        }

        onImplicitWidthChanged: adoptWidth()
        Component.onCompleted: {
          adoptWidth()
          adoptSettingsFromStore()
        }

        Connections {
          target: PanelRouter
          function onCalendarOpenChanged(): void {
            if (PanelRouter.calendarOpen)
              panel.open()
            else
              panel.close()
          }
        }

        Connections {
          target: PanelSettings
          function onLoadedChanged(): void {
            if (PanelSettings.loaded) panel.adoptSettingsFromStore()
          }
          function onChanged(name, values): void {
            if (name !== "shell-calendar") return
            calendar.panelSettings = values
            panel.settings = values
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
