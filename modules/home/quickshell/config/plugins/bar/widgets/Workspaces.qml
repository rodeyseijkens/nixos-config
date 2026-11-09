import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../../../"

RowLayout {
  id: root
  required property var barScreen
  spacing: 0
  Layout.leftMargin: 15

  property HyprlandMonitor hlMonitor: Hyprland.monitorFor(barScreen)
  property var roman: ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

  function isOnMonitor(w: var): bool {
    return hlMonitor != null && w.monitor != null && w.monitor.id === hlMonitor.id;
  }

  property var wsOnScreen: Hyprland.workspaces.values.filter(w => isOnMonitor(w) && w.id >= 1 && w.id <= 10)
  property var idsOnScreen: wsOnScreen.map(w => w.id)

  Repeater {
    model: [1, 2, 3, 4, 5]

    Text {
      required property int modelData
      property var ws: Hyprland.workspaces.values.find(w => root.isOnMonitor(w) && w.id === modelData)
      property bool isActive: root.hlMonitor != null && root.hlMonitor.activeWorkspace != null && root.hlMonitor.activeWorkspace.id === modelData
      property bool occupied: ws != null && ws.toplevels != null && ws.toplevels.values.length > 0

      Layout.leftMargin: 5
      Layout.rightMargin: 15
      text: root.roman[modelData]
      font.bold: true
      font.family: Colors.fontFamily
      color: isActive ? Colors.base09 : (occupied || ws != null ? Colors.base0A : Colors.base07)

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (ws != null)
            ws.activate();
          else
            Hyprland.dispatch("workspace " + modelData);
        }
      }
    }
  }

  Repeater {
    model: root.wsOnScreen.filter(w => w.id < 1 || w.id > 5).sort((a, b) => a.id - b.id)

    Text {
      required property var modelData
      property bool isActive: root.hlMonitor != null && root.hlMonitor.activeWorkspace != null && root.hlMonitor.activeWorkspace.id === modelData.id

      Layout.leftMargin: 5
      Layout.rightMargin: 15
      text: root.roman[modelData.id] ?? ("" + modelData.id)
      font.bold: true
      font.family: Colors.fontFamily
      color: isActive ? Colors.base09 : Colors.base0A

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: modelData.activate()
      }
    }
  }
}
