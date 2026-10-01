import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../Services"
import "../"

// Bar: the always-visible dock along the bottom edge of every monitor —
// deliberately not a ScreenPopup: it reserves space from windows instead of
// floating over them.
Scope {
  id: bar

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      visible: Preferences.barVisible

      anchors {
        left: true
        bottom: true
        right: true
      }
      implicitHeight: 28
      exclusiveZone: 28
      color: Colors.base01

      Rectangle {
        anchors.fill: parent
        color: Colors.base01
        border.width: 0
        Rectangle {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: 1
          color: Colors.base04
        }

        RowLayout {
          id: leftGroup
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 15
          spacing: 0

          LauncherButton {}
          Workspaces {
            barScreen: win.screen
          }
        }

        Clock {
          barScreen: win.screen
          anchors.centerIn: parent
        }

        RowLayout {
          id: rightGroup
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.rightMargin: 5
          spacing: 0

          Stats {}
          Volume {}
          Tray {}
          NotifIcon {
            barScreen: win.screen
          }
        }
      }
    }
  }

  IpcHandler {
    target: "bar"

    function toggle(): void {
      Preferences.toggleBar();
    }
  }
}
