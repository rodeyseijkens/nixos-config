import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Services"
import "../"

// Notification panel: the ScreenPopup showing notification history; opening
// it takes keyboard focus and clicking outside (or Esc) closes it.
Scope {
  id: panel

  ScreenPopup {
    id: popup
    placement: PopupPlacement {
      top: true
      right: true
      bottom: true
      marginTop: 40
      marginRight: 15
      marginBottom: 40
      width: 300
      height: 600
    }
    // only the bar whose bell was clicked (screen names are unique)
    showWhen: (name) => PanelRouter.panelOpen && PanelRouter.panelScreenName === name
    focusable: true
    focusGrab: true
    onDismissRequested: PanelRouter.closePanel()

    content: Component {
      // swaync parity: .control-center — base00, square, 2px base04 border
      Rectangle {
        id: panelBg
        anchors.fill: parent
        color: Colors.base00
        border.color: Colors.base04
        border.width: 2

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 8

          // swaync order: title, mpris, notifications, dnd
          // (no inhibitors widget: we have no inhibitor backend, and swaync
          // shows that row only when inhibitors exist — avoids a dead 2nd Clear All)
          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Text {
              text: "Notifications"
              font.bold: true
              font.pixelSize: 16
              font.family: Colors.fontFamily
              color: Colors.base04
              Layout.fillWidth: true
            }
            FlatButton {
              text: "Clear All"
              onClicked: NotifServer.dismissAll()
            }
          }

          MprisWidget {}

          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
              // cards paint their own base01; column stays transparent so
              // spacing gaps show the base00 panel behind (swaync parity).
              // NOTE: must be a definite width — `parent.width` resolves to the
              // ScrollView contentItem, which collapses to 0 (contentWidth), and
              // a 0-width card paints no background while its fixed-width
              // children (priority bar, close button) and unclipped Text still do.
              width: panelBg.width - 16
              spacing: 8

              Text {
                visible: NotifServer.entries.length === 0
                text: "No Notifications"
                font.family: Colors.fontFamily
                color: Colors.base04
                Layout.alignment: Qt.AlignHCenter
              }

              Repeater {
                model: ScriptModel {
                  values: NotifServer.entries
                }

                NotifCard {
                  required property var modelData
                  Layout.fillWidth: true
                  n: modelData
                }
              }
            }
          }

          // swaync parity: .widget-dnd 8px margins, 14px label, square switch
          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            Text {
              text: "Do Not Disturb"
              font.pixelSize: 14
              font.family: Colors.fontFamily
              color: Colors.base04
              Layout.fillWidth: true
              Layout.leftMargin: 8
            }
            FlatSwitch {
              Layout.rightMargin: 4
              checked: Preferences.dnd
              onToggled: Preferences.toggleDnd()
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: "notif"

    // no-arg form used by keybinds; targets the current/first screen
    function toggle(): void {
      PanelRouter.togglePanel();
    }
    // screen-targeted form (used by tests / explicit callers)
    function toggleOn(screen: string): void {
      PanelRouter.togglePanel(screen);
    }
    // deterministic open/close/clear for scripted callers (update-nix-screenshots)
    function open(): void {
      PanelRouter.openPanel();
    }
    function close(): void {
      PanelRouter.closePanel();
    }
    function clear(): void {
      NotifServer.dismissAll();
    }
    function dnd(): void {
      Preferences.toggleDnd();
    }
  }
}
